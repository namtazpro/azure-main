// Agentic BAM Runtime - Interceptor Middleware for Microsoft Agent Framework
// This middleware intercepts agent lifecycle events and writes milestones
// to the BAM activity store, based on tracking profile configuration.
// Agents are completely unaware of this middleware.

using System.Text.Json;
using Microsoft.Agents.Builder;
using Microsoft.Agents.Builder.App;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace AgenticBam.Runtime;

/// <summary>
/// Registers Agentic BAM services and middleware into the agent host.
/// </summary>
public static class BamServiceRegistration
{
    /// <summary>
    /// Adds Agentic BAM activity monitoring to the agent host.
    /// Call this in Program.cs — agents remain unaware of BAM.
    /// </summary>
    public static IServiceCollection AddAgenticBam(
        this IServiceCollection services,
        Action<BamOptions> configureOptions)
    {
        services.Configure(configureOptions);
        services.AddSingleton<IActivityDefinitionLoader, YamlActivityDefinitionLoader>();
        services.AddSingleton<ITrackingProfileLoader, YamlTrackingProfileLoader>();
        services.AddSingleton<ICorrelationTokenService, CorrelationTokenService>();
        services.AddSingleton<IActivityStore, SqlActivityStore>();
        services.AddSingleton<BamInterceptorMiddleware>();
        return services;
    }
}

/// <summary>
/// Configuration options for Agentic BAM.
/// </summary>
public class BamOptions
{
    /// <summary>Path to directory containing .activity.yaml files.</summary>
    public string DefinitionsPath { get; set; } = "./definitions";

    /// <summary>Path to directory containing .profile.yaml files.</summary>
    public string TrackingProfilesPath { get; set; } = "./tracking-profiles";

    /// <summary>Connection string for the BAM activity store.</summary>
    public string ActivityStoreConnectionString { get; set; } = string.Empty;

    /// <summary>Whether to propagate correlation tokens in agent context metadata.</summary>
    public bool EnableContextPropagation { get; set; } = true;
}
