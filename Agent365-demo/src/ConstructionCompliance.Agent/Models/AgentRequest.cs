namespace ConstructionCompliance.Agent.Models;

/// <summary>
/// Represents the user request contract for compliance analysis.
/// </summary>
public sealed class AgentRequest
{
    /// <summary>
    /// Gets or sets the country where the project is located.
    /// </summary>
    public required string Country { get; set; }

    /// <summary>
    /// Gets or sets the optional state or province.
    /// </summary>
    public string? StateOrProvince { get; set; }

    /// <summary>
    /// Gets or sets the optional city or municipality.
    /// </summary>
    public string? CityOrMunicipality { get; set; }

    /// <summary>
    /// Gets or sets the building type for the project.
    /// </summary>
    public required string BuildingType { get; set; }

    /// <summary>
    /// Gets or sets the occupancy class for the project.
    /// </summary>
    public required string OccupancyClass { get; set; }

    /// <summary>
    /// Gets or sets the design stage, for example concept or schematic.
    /// </summary>
    public required string DesignStage { get; set; }

    /// <summary>
    /// Gets or sets the free-form user query.
    /// </summary>
    public required string Query { get; set; }

    /// <summary>
    /// Gets or sets optional design parameters used for pre-permit risk checks.
    /// </summary>
    public Dictionary<string, string> DesignParameters { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
