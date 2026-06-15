namespace ConstructionCompliance.Agent.Routing;

/// <summary>
/// Defines the supported user intents for v1.
/// </summary>
public enum IntentType
{
    /// <summary>
    /// The request asks for applicable constraints.
    /// </summary>
    IdentifyConstraints,

    /// <summary>
    /// The request asks to compare jurisdictions.
    /// </summary>
    CompareJurisdictions,

    /// <summary>
    /// The request asks for pre-permit risk analysis.
    /// </summary>
    PrePermitRiskCheck,

    /// <summary>
    /// The request asks for clause interpretation.
    /// </summary>
    ExplainClause
}
