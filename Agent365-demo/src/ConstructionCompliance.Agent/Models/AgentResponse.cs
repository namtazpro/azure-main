namespace ConstructionCompliance.Agent.Models;

/// <summary>
/// Represents the normalized response returned by the compliance agent.
/// </summary>
public sealed class AgentResponse
{
    /// <summary>
    /// Gets or sets the resolved intent identifier.
    /// </summary>
    public required string Intent { get; set; }

    /// <summary>
    /// Gets or sets the regulation references used for analysis.
    /// </summary>
    public List<ApplicableRegulation> ApplicableRegulations { get; set; } = [];

    /// <summary>
    /// Gets or sets the extracted constraints.
    /// </summary>
    public List<ConstraintItem> Constraints { get; set; } = [];

    /// <summary>
    /// Gets or sets the risk findings generated for design checks.
    /// </summary>
    public List<RiskFinding> RiskFindings { get; set; } = [];

    /// <summary>
    /// Gets or sets the citation list for traceability.
    /// </summary>
    public List<Citation> Citations { get; set; } = [];

    /// <summary>
    /// Gets or sets the coverage status for the requested jurisdiction.
    /// </summary>
    public required string CoverageStatus { get; set; }

    /// <summary>
    /// Gets or sets the confidence label for this response.
    /// </summary>
    public required string Confidence { get; set; }

    /// <summary>
    /// Gets or sets missing fields that block completion.
    /// </summary>
    public List<string> ClarificationRequests { get; set; } = [];

    /// <summary>
    /// Gets or sets additional notes describing assumptions.
    /// </summary>
    public List<string> Assumptions { get; set; } = [];

    /// <summary>
    /// Gets or sets the compliance disclaimer.
    /// </summary>
    public required string Disclaimer { get; set; }
}

/// <summary>
/// Represents one regulation source used for analysis.
/// </summary>
/// <param name="Authority">The issuing authority.</param>
/// <param name="CodeName">The code family or standard name.</param>
/// <param name="Edition">The edition applied.</param>
/// <param name="AmendmentDate">The amendment date applied.</param>
public sealed record ApplicableRegulation(string Authority, string CodeName, string Edition, string AmendmentDate);

/// <summary>
/// Represents a normalized compliance constraint.
/// </summary>
/// <param name="Category">The category of the constraint.</param>
/// <param name="Rule">The rule statement.</param>
/// <param name="Threshold">The threshold value.</param>
/// <param name="Unit">The threshold unit.</param>
/// <param name="CitationKey">The citation key associated with the rule.</param>
public sealed record ConstraintItem(string Category, string Rule, string Threshold, string Unit, string CitationKey);

/// <summary>
/// Represents one risk finding from a design evaluation.
/// </summary>
/// <param name="Severity">Risk severity.</param>
/// <param name="Title">Short finding title.</param>
/// <param name="Impact">Design impact statement.</param>
public sealed record RiskFinding(string Severity, string Title, string Impact);

/// <summary>
/// Represents a source citation.
/// </summary>
/// <param name="Key">Citation key.</param>
/// <param name="Reference">Clause reference.</param>
/// <param name="SourceUri">Source URI.</param>
public sealed record Citation(string Key, string Reference, string SourceUri);
