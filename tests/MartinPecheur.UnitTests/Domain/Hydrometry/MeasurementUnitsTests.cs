using MartinPecheur.Domain.Hydrometry;

namespace MartinPecheur.UnitTests.Domain.Hydrometry;

/// <summary>
/// BR-002 — le débit est affiché en m³/s, la hauteur en mètres.
/// Hub'Eau renvoie des litres par seconde et des millimètres (C-02).
/// Afficher la valeur brute serait faux d'un facteur 1000.
/// </summary>
public class MeasurementUnitsTests
{
    // Valeurs relevées en production le 2026-07-30, station K447001001 (la Loire à Blois).
    [Theory]
    [InlineData(53000.0, 53.0)]        // observations_tr, 2026-07-21 — étiage de Loire moyenne
    [InlineData(350571.0, 350.571)]    // obs_elab QmnJ, 2024-07-01
    [InlineData(0.0, 0.0)]
    public void ToCubicMetresPerSecond_converts_litres_per_second(double raw, double expected)
    {
        MeasurementUnits.ToCubicMetresPerSecond(raw).Should().Be(expected);
    }

    [Theory]
    [InlineData(1250.0, 1.25)]
    [InlineData(0.0, 0.0)]
    public void ToMetres_converts_millimetres(double raw, double expected)
    {
        MeasurementUnits.ToMetres(raw).Should().Be(expected);
    }

    [Fact]
    public void ToCubicMetresPerSecond_propagates_absence()
    {
        // BR-007 : une valeur absente n'est pas zéro. Un débit nul et un débit
        // non transmis sont deux informations différentes.
        MeasurementUnits.ToCubicMetresPerSecond(null).Should().BeNull();
    }

    [Fact]
    public void ToMetres_propagates_absence()
    {
        MeasurementUnits.ToMetres(null).Should().BeNull();
    }

    [Fact]
    public void Conversion_is_not_applied_twice()
    {
        // Garde-fou : une double conversion est aussi fausse qu'une absence de conversion.
        var once = MeasurementUnits.ToCubicMetresPerSecond(53000.0);
        once.Should().Be(53.0);
        MeasurementUnits.ToCubicMetresPerSecond(once).Should().NotBe(53.0);
    }
}
