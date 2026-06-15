using ConstructionCompliance.Agent.Models;

namespace ConstructionCompliance.Agent.Routing;

/// <summary>
/// Resolves user intent from request content.
/// </summary>
public interface IIntentResolver
{
    /// <summary>
    /// Resolves the most likely intent from the request.
    /// </summary>
    /// <param name="request">The user request.</param>
    /// <returns>The resolved intent.</returns>
    IntentType Resolve(AgentRequest request);
}
