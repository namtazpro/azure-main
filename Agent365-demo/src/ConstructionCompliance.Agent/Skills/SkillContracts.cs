using ConstructionCompliance.Agent.Models;
using ConstructionCompliance.Agent.Routing;

namespace ConstructionCompliance.Agent.Skills;

/// <summary>
/// Resolves jurisdiction support and metadata.
/// </summary>
public interface IJurisdictionResolverSkill
{
    /// <summary>
    /// Resolves jurisdiction metadata for the request.
    /// </summary>
    /// <param name="request">The user request.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The jurisdiction resolution result.</returns>
    Task<JurisdictionResolution> ResolveAsync(AgentRequest request, CancellationToken cancellationToken);
}

/// <summary>
/// Retrieves regulation references for a jurisdiction.
/// </summary>
public interface IRegulationRetrievalSkill
{
    /// <summary>
    /// Retrieves applicable regulations.
    /// </summary>
    /// <param name="resolution">Resolved jurisdiction metadata.</param>
    /// <param name="intent">The resolved intent.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The regulation list.</returns>
    Task<IReadOnlyList<ApplicableRegulation>> RetrieveAsync(JurisdictionResolution resolution, IntentType intent, CancellationToken cancellationToken);
}

/// <summary>
/// Extracts normalized constraints from regulation sources.
/// </summary>
public interface IConstraintEngineSkill
{
    /// <summary>
    /// Builds normalized constraints.
    /// </summary>
    /// <param name="request">The user request.</param>
    /// <param name="regulations">The applicable regulations.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The normalized constraints.</returns>
    Task<IReadOnlyList<ConstraintItem>> ExtractAsync(AgentRequest request, IReadOnlyList<ApplicableRegulation> regulations, CancellationToken cancellationToken);
}

/// <summary>
/// Evaluates design parameters against extracted constraints.
/// </summary>
public interface IDesignCheckerSkill
{
    /// <summary>
    /// Evaluates potential compliance risks.
    /// </summary>
    /// <param name="request">The user request.</param>
    /// <param name="constraints">Normalized constraints.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Risk findings.</returns>
    Task<IReadOnlyList<RiskFinding>> EvaluateAsync(AgentRequest request, IReadOnlyList<ConstraintItem> constraints, CancellationToken cancellationToken);
}

/// <summary>
/// Validates response citation completeness.
/// </summary>
public interface ICitationAuditSkill
{
    /// <summary>
    /// Applies citation checks and updates confidence if needed.
    /// </summary>
    /// <param name="response">The response under review.</param>
    /// <returns>The finalized response.</returns>
    AgentResponse Audit(AgentResponse response);
}

/// <summary>
/// Represents the jurisdiction resolution output.
/// </summary>
/// <param name="NormalizedJurisdiction">Normalized jurisdiction identifier.</param>
/// <param name="IsSupported">True when jurisdiction is in coverage.</param>
/// <param name="CoverageStatus">Coverage status value.</param>
public sealed record JurisdictionResolution(string NormalizedJurisdiction, bool IsSupported, string CoverageStatus);
