namespace ConstructionCompliance.Agent.Adapters;

/// <summary>
/// Provides a sample Agent365 registration payload produced by this runtime.
/// </summary>
public interface IAgent365RegistrationProvider
{
    /// <summary>
    /// Gets the registration payload advertised to Agent365.
    /// </summary>
    /// <returns>Registration metadata.</returns>
    object GetRegistrationPayload();
}

/// <summary>
/// Supplies registration metadata aligned with the sample manifest.
/// </summary>
public sealed class Agent365RegistrationProvider : IAgent365RegistrationProvider
{
    /// <inheritdoc/>
    public object GetRegistrationPayload()
    {
        return new
        {
            agentId = "construction-compliance-intelligence-agent",
            displayName = "Construction Compliance Intelligence Agent",
            sdk = "agent365-sdk",
            runtime = "microsoft-agent-framework",
            version = "0.1.0",
            endpoints = new
            {
                health = "/health",
                invoke = "/api/agent/invoke"
            },
            capabilities = new[]
            {
                "jurisdiction-resolution",
                "regulation-retrieval",
                "constraint-extraction",
                "design-risk-screening",
                "cross-country-comparison"
            }
        };
    }
}
