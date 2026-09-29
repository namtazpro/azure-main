// Agentic BAM - Tracking Profile and Activity Definition Loaders
// Reads YAML configuration files and provides lookup for the interceptor

namespace AgenticBam.Runtime;

/// <summary>
/// Loads and indexes tracking profile bindings from YAML files.
/// Provides fast lookup by agent name for the interceptor middleware.
/// </summary>
public interface ITrackingProfileLoader
{
    /// <summary>Gets all bindings configured for a specific agent.</summary>
    IReadOnlyList<TrackingBinding> GetBindingsForAgent(string agentName);

    /// <summary>Gets the object type code for an activity (e.g., "SO" for SalesOrder).</summary>
    string GetActivityObjectType(string activityName);
}

/// <summary>
/// Loads activity definitions from YAML files.
/// </summary>
public interface IActivityDefinitionLoader
{
    /// <summary>Gets the full activity definition by name.</summary>
    ActivityDefinition? GetDefinition(string activityName);

    /// <summary>Gets all loaded activity definitions.</summary>
    IReadOnlyList<ActivityDefinition> GetAll();
}

/// <summary>
/// A single binding from a tracking profile — maps one agent event to one milestone.
/// </summary>
public class TrackingBinding
{
    public required string ActivityName { get; init; }
    public required string AgentName { get; init; }
    public string? AgentType { get; init; }
    public string? AgentId { get; init; }
    public required string Event { get; init; }
    public string? Condition { get; init; }
    public required string Milestone { get; init; }
    public required CorrelationConfig Correlation { get; init; }
    public Dictionary<string, string> DataMappings { get; init; } = new();
    public FailureConfig? OnFailure { get; init; }
    public bool IsTerminal { get; init; }
}

public class CorrelationConfig
{
    /// <summary>If true, a new token is minted at this binding.</summary>
    public bool Mint { get; init; }

    /// <summary>Source path for division (only when Mint=true).</summary>
    public string? DivisionSource { get; init; }

    /// <summary>Source path for object ID (only when Mint=true).</summary>
    public string? ObjectIdSource { get; init; }

    /// <summary>Field path to look up existing token (when Mint=false).</summary>
    public string? LookupBy { get; init; }

    /// <summary>Scope for lookup: "active" or "all".</summary>
    public string LookupScope { get; init; } = "active";
}

public class FailureConfig
{
    public required string Condition { get; init; }
    public Dictionary<string, string> DataMappings { get; init; } = new();
}

/// <summary>
/// Parsed activity definition from YAML.
/// </summary>
public class ActivityDefinition
{
    public required string Name { get; init; }
    public required string Version { get; init; }
    public string? Description { get; init; }
    public string? Owner { get; init; }
    public required string ObjectType { get; init; }
    public required List<MilestoneDefinition> Milestones { get; init; }
    public List<DataItemDefinition> DataItems { get; init; } = new();
    public List<ViewDefinition> Views { get; init; } = new();
}

public class MilestoneDefinition
{
    public required string Name { get; init; }
    public string? Description { get; init; }
    public bool Terminal { get; init; }
    public SlaDefinition? Sla { get; init; }
}

public class SlaDefinition
{
    public TimeSpan? MaxDurationFromPrevious { get; init; }
    public TimeSpan? MaxDurationFromStart { get; init; }
}

public class DataItemDefinition
{
    public required string Name { get; init; }
    public required string Type { get; init; }
    public string? CapturedAt { get; init; }
    public string? Description { get; init; }
}

public class ViewDefinition
{
    public required string Name { get; init; }
    public string? Description { get; init; }
    public required List<string> VisibleMilestones { get; init; }
    public required List<string> VisibleData { get; init; }
}

/// <summary>
/// YAML-based implementation of ITrackingProfileLoader.
/// Reads .profile.yaml files and indexes bindings by agent name.
/// </summary>
public class YamlTrackingProfileLoader : ITrackingProfileLoader
{
    private readonly Dictionary<string, List<TrackingBinding>> _bindingsByAgent = new();
    private readonly Dictionary<string, string> _objectTypes = new();

    public YamlTrackingProfileLoader(IOptions<BamOptions> options)
    {
        LoadProfiles(options.Value.TrackingProfilesPath);
    }

    public IReadOnlyList<TrackingBinding> GetBindingsForAgent(string agentName)
    {
        return _bindingsByAgent.TryGetValue(agentName, out var bindings)
            ? bindings.AsReadOnly()
            : Array.Empty<TrackingBinding>();
    }

    public string GetActivityObjectType(string activityName)
    {
        return _objectTypes.TryGetValue(activityName, out var type)
            ? type
            : throw new InvalidOperationException($"No object type configured for activity '{activityName}'");
    }

    private void LoadProfiles(string path)
    {
        // In production: deserialize YAML files using YamlDotNet
        // Index all bindings by agent name for O(1) lookup during interception
        // This runs once at startup
    }
}

/// <summary>
/// YAML-based implementation of IActivityDefinitionLoader.
/// </summary>
public class YamlActivityDefinitionLoader : IActivityDefinitionLoader
{
    private readonly Dictionary<string, ActivityDefinition> _definitions = new();

    public YamlActivityDefinitionLoader(IOptions<BamOptions> options)
    {
        LoadDefinitions(options.Value.DefinitionsPath);
    }

    public ActivityDefinition? GetDefinition(string activityName)
    {
        return _definitions.TryGetValue(activityName, out var def) ? def : null;
    }

    public IReadOnlyList<ActivityDefinition> GetAll()
    {
        return _definitions.Values.ToList().AsReadOnly();
    }

    private void LoadDefinitions(string path)
    {
        // In production: deserialize YAML files using YamlDotNet
    }
}

// Required for compilation
using Microsoft.Extensions.Options;
