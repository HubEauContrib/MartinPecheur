const { withAppBuildGradle } = require("expo/config-plugins");

/**
 * Signature des builds `release` — plugin de configuration Expo.
 *
 * 🚨 **Le gabarit d'Expo signe la release avec le keystore de debug.** Le
 * `android/app/build.gradle` généré par `prebuild` contient littéralement
 * `signingConfig signingConfigs.debug` dans le bloc `release`, sous son propre
 * avertissement « Caution! In production, you need to generate your own
 * keystore file. » Ce keystore-là est celui d'Android : alias
 * `androiddebugkey`, mot de passe `android`, connu de tout le monde.
 *
 * Publier un APK signé ainsi coûte deux fois :
 *
 * - n'importe qui peut produire un APK signé de la même clé, qui s'installera
 *   par-dessus celui des testeurs ;
 * - le jour où une vraie clé est utilisée, la signature ne correspond plus et
 *   **aucune mise à jour ne s'installe** — il faut désinstaller, donc perdre
 *   les données locales.
 *
 * `android/` étant régénéré à chaque `prebuild` (et git-ignoré), le correctif
 * ne peut pas vivre dans le fichier généré : il vit ici.
 *
 * La clé arrive par **propriétés Gradle**, jamais en dur :
 *
 * ```bash
 * ./gradlew assembleRelease \
 *   -PMARTINPECHEUR_STORE_FILE=release.keystore \
 *   -PMARTINPECHEUR_STORE_PASSWORD=… \
 *   -PMARTINPECHEUR_KEY_ALIAS=… \
 *   -PMARTINPECHEUR_KEY_PASSWORD=…
 * ```
 *
 * Sans ces propriétés, le comportement d'origine est conservé — un build local
 * reste possible sans keystore. C'est la CI qui **interdit de publier** un APK
 * signé en debug, en vérifiant le certificat de l'APK produit.
 */

const CONFIG_RELEASE = `        release {
            storeFile file(findProperty('MARTINPECHEUR_STORE_FILE') ?: 'debug.keystore')
            storePassword findProperty('MARTINPECHEUR_STORE_PASSWORD') ?: 'android'
            keyAlias findProperty('MARTINPECHEUR_KEY_ALIAS') ?: 'androiddebugkey'
            keyPassword findProperty('MARTINPECHEUR_KEY_PASSWORD') ?: 'android'
        }
`;

const SIGNING_CONDITIONNEL =
  "signingConfig hasProperty('MARTINPECHEUR_STORE_FILE') " +
  "? signingConfigs.release : signingConfigs.debug";

const ANCRE_DEBUG = "signingConfig signingConfigs.debug";

/**
 * Réécrit `android/app/build.gradle` — **fonction pure**, donc testable sans
 * lancer de build natif.
 *
 * ⚠️ **Chaque ancre manquante lève.** Un plugin qui ne trouve pas son point
 * d'insertion et se contente de rendre l'entrée inchangée réintroduirait
 * silencieusement la signature de debug, ce qui est précisément le défaut qu'il
 * existe pour fermer. Si un futur gabarit Expo change, `prebuild` doit échouer
 * bruyamment.
 */
function patchAppBuildGradle(contents) {
  if (contents.includes("MARTINPECHEUR_STORE_FILE")) return contents;

  const ancreConfigs = contents.indexOf("signingConfigs {");
  if (ancreConfigs === -1) {
    throw new Error("withReleaseSigning : bloc `signingConfigs {` introuvable dans build.gradle.");
  }
  const finLigneConfigs = contents.indexOf("\n", ancreConfigs) + 1;

  const avecConfig =
    contents.slice(0, finLigneConfigs) + CONFIG_RELEASE + contents.slice(finLigneConfigs);

  // `signingConfig signingConfigs.debug` apparaît deux fois : dans le buildType
  // `debug`, qu'on laisse tel quel, et dans `release`. On ne cherche donc qu'à
  // partir du `release {` qui suit `buildTypes {`.
  const ancreBuildTypes = avecConfig.indexOf("buildTypes {");
  if (ancreBuildTypes === -1) {
    throw new Error("withReleaseSigning : bloc `buildTypes {` introuvable dans build.gradle.");
  }
  const ancreRelease = avecConfig.indexOf("release {", ancreBuildTypes);
  if (ancreRelease === -1) {
    throw new Error("withReleaseSigning : buildType `release` introuvable dans build.gradle.");
  }
  const ancreSignature = avecConfig.indexOf(ANCRE_DEBUG, ancreRelease);
  if (ancreSignature === -1) {
    throw new Error(
      "withReleaseSigning : le buildType `release` ne référence plus " +
        "`signingConfigs.debug` — vérifier le gabarit Expo avant de publier.",
    );
  }

  return (
    avecConfig.slice(0, ancreSignature) +
    SIGNING_CONDITIONNEL +
    avecConfig.slice(ancreSignature + ANCRE_DEBUG.length)
  );
}

const withReleaseSigning = (config) =>
  withAppBuildGradle(config, (gradleConfig) => {
    gradleConfig.modResults.contents = patchAppBuildGradle(gradleConfig.modResults.contents);
    return gradleConfig;
  });

module.exports = withReleaseSigning;
module.exports.patchAppBuildGradle = patchAppBuildGradle;
