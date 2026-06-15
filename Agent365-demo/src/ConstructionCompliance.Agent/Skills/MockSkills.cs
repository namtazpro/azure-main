using ConstructionCompliance.Agent.Models;
using ConstructionCompliance.Agent.Routing;

namespace ConstructionCompliance.Agent.Skills;

/// <summary>
/// Sample jurisdiction resolver with a limited supported list for v1.
/// </summary>
public sealed class MockJurisdictionResolverSkill : IJurisdictionResolverSkill
{
    private static readonly HashSet<string> SupportedCountries =
    [
        "canada",
        "spain",
        "germany",
        "united arab emirates",
        "singapore",
        "united kingdom",
        "japan"
    ];

    /// <inheritdoc/>
    public Task<JurisdictionResolution> ResolveAsync(AgentRequest request, CancellationToken cancellationToken)
    {
        var normalized = request.Country.Trim().ToLowerInvariant();
        var isSupported = SupportedCountries.Contains(normalized);
        var status = isSupported ? "supported" : "unsupported";
        return Task.FromResult(new JurisdictionResolution(normalized, isSupported, status));
    }
}

/// <summary>
/// Sample regulation retrieval skill with synthetic references.
/// </summary>
public sealed class MockRegulationRetrievalSkill : IRegulationRetrievalSkill
{
    /// <inheritdoc/>
    public Task<IReadOnlyList<ApplicableRegulation>> RetrieveAsync(JurisdictionResolution resolution, IntentType intent, CancellationToken cancellationToken)
    {
        IReadOnlyList<ApplicableRegulation> regulations =
        [
            new ApplicableRegulation("Municipal Building Authority", "Local Building Code", "2024 Edition", "2025-04-01"),
            new ApplicableRegulation("National Standards Body", "Fire and Life Safety", "2023 Edition", "2024-09-30"),
            new ApplicableRegulation("Energy Ministry", "Building Energy Performance", "2022 Edition", "2025-01-15")
        ];

        return Task.FromResult(regulations);
    }
}

/// <summary>
/// Sample constraint extraction skill with category-driven outputs.
/// </summary>
public sealed class MockConstraintEngineSkill : IConstraintEngineSkill
{
    /// <inheritdoc/>
    public Task<IReadOnlyList<ConstraintItem>> ExtractAsync(AgentRequest request, IReadOnlyList<ApplicableRegulation> regulations, CancellationToken cancellationToken)
    {
        IReadOnlyList<ConstraintItem> constraints =
        [
            new ConstraintItem("fire_safety", "Minimum protected egress width", "1.5", "m", "CIT-001"),
            new ConstraintItem("accessibility", "Maximum ramp slope", "1:12", "ratio", "CIT-002"),
            new ConstraintItem("energy", "Maximum facade U-value", "0.35", "W/m2K", "CIT-003")
        ];

        return Task.FromResult(constraints);
    }
}

/// <summary>
/// Sample design checker skill for pre-permit risk checks.
/// </summary>
public sealed class MockDesignCheckerSkill : IDesignCheckerSkill
{
    /// <inheritdoc/>
    public Task<IReadOnlyList<RiskFinding>> EvaluateAsync(AgentRequest request, IReadOnlyList<ConstraintItem> constraints, CancellationToken cancellationToken)
    {
        var findings = new List<RiskFinding>();

        if (request.DesignParameters.TryGetValue("floors", out var floorsValue) && int.TryParse(floorsValue, out var floors) && floors > 12)
        {
            findings.Add(new RiskFinding("high", "High-rise egress complexity", "Building exceeds 12 floors and may require additional egress strategy review."));
        }

        if (request.DesignParameters.TryGetValue("heightMeters", out var heightValue) && double.TryParse(heightValue, out var heightMeters) && heightMeters > 45)
        {
            findings.Add(new RiskFinding("high", "Facade and fire access risk", "Height above 45 m may trigger stricter facade and fire access constraints."));
        }

        if (findings.Count == 0)
        {
            findings.Add(new RiskFinding("medium", "Insufficient design detail", "Provide stair core count, fire separation strategy, and accessibility details for a stronger pre-permit check."));
        }

        return Task.FromResult((IReadOnlyList<RiskFinding>)findings);
    }
}

/// <summary>
/// Citation auditing skill that enforces traceability completeness.
/// </summary>
public sealed class StrictCitationAuditSkill : ICitationAuditSkill
{
    /// <inheritdoc/>
    public AgentResponse Audit(AgentResponse response)
    {
        var citationKeys = response.Citations.Select(c => c.Key).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var missingCitation = response.Constraints.Any(constraint => !citationKeys.Contains(constraint.CitationKey));

        if (missingCitation)
        {
            response.Confidence = "low";
            response.Assumptions.Add("One or more constraints did not map to a citation key and should be reviewed before relying on this response.");
        }

        return response;
    }
}
