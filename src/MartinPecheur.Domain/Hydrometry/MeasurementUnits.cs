namespace MartinPecheur.Domain.Hydrometry;

/// <summary>
/// Conversion des unités renvoyées par Hub'Eau vers les unités affichées.
/// </summary>
/// <remarks>
/// <para>
/// L'API hydrométrie renvoie les débits en <b>litres par seconde</b> et les hauteurs
/// en <b>millimètres</b> — contrairement à ce qu'un lecteur pressé supposerait.
/// Vérifié le 2026-07-30 sur la station <c>K447001001</c> : <c>resultat_obs = 53000.0</c>
/// correspond à 53 m³/s, cohérent avec un étiage de Loire moyenne.
/// </para>
/// <para>
/// Afficher la valeur brute serait faux d'un facteur 1000. Ce n'est pas une imprécision :
/// c'est une information sur laquelle un irrigant ou un kayakiste peut fonder une décision.
/// Voir <c>BR-002</c> et la contrainte <c>C-02</c>.
/// </para>
/// <para>
/// La conversion a lieu <b>une seule fois</b>, dans la couche de mapping. Une double
/// conversion est aussi fausse qu'une absence de conversion.
/// </para>
/// </remarks>
public static class MeasurementUnits
{
    private const double LitresPerCubicMetre = 1000d;
    private const double MillimetresPerMetre = 1000d;

    /// <summary>Convertit un débit de litres par seconde en mètres cubes par seconde.</summary>
    /// <param name="litresPerSecond">Valeur brute d'API, ou <c>null</c> si la station n'a rien transmis.</param>
    /// <returns>Le débit en m³/s, ou <c>null</c>. L'absence n'est jamais convertie en zéro (<c>BR-007</c>).</returns>
    public static double? ToCubicMetresPerSecond(double? litresPerSecond)
        => litresPerSecond / LitresPerCubicMetre;

    /// <summary>Convertit une hauteur d'eau de millimètres en mètres.</summary>
    /// <param name="millimetres">Valeur brute d'API, ou <c>null</c> si la station n'a rien transmis.</param>
    /// <returns>La hauteur en mètres, ou <c>null</c>.</returns>
    public static double? ToMetres(double? millimetres)
        => millimetres / MillimetresPerMetre;
}
