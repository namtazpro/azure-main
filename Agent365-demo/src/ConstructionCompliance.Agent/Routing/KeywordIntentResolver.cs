using ConstructionCompliance.Agent.Models;

namespace ConstructionCompliance.Agent.Routing;

/// <summary>
/// Provides simple keyword-based intent routing for the v1 sample.
/// </summary>
public sealed class KeywordIntentResolver : IIntentResolver
{
    /// <inheritdoc/>
    public IntentType Resolve(AgentRequest request)
    {
        var query = request.Query.ToLowerInvariant();

        if (query.Contains("compare", StringComparison.Ordinal) || query.Contains("versus", StringComparison.Ordinal) || query.Contains("vs", StringComparison.Ordinal))
        {
            return IntentType.CompareJurisdictions;
        }

        if (query.Contains("risk", StringComparison.Ordinal) || query.Contains("red flag", StringComparison.Ordinal) || query.Contains("pre-permit", StringComparison.Ordinal) || request.DesignParameters.Count > 0)
        {
            return IntentType.PrePermitRiskCheck;
        }

        if (query.Contains("explain", StringComparison.Ordinal) || query.Contains("interpret", StringComparison.Ordinal) || query.Contains("clause", StringComparison.Ordinal))
        {
            return IntentType.ExplainClause;
        }

        return IntentType.IdentifyConstraints;
    }
}
