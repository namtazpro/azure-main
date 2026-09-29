// Agentic BAM - Core Interceptor Middleware
// Plugs into Microsoft Agent Framework's middleware pipeline.
// Intercepts agent turn completions and writes milestones to the activity store.

using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Agents.Builder;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace AgenticBam.Runtime;

/// <summary>
/// BAM Interceptor Middleware for Microsoft Agent Framework.
/// 
/// This middleware sits in the agent pipeline and:
/// 1. Observes agent turn completions (on_turn_complete events)
/// 2. Matches the agent + event to a tracking profile binding
/// 3. Evaluates the binding condition against agent output
/// 4. Extracts data items from agent output using configured mappings
/// 5. Mints or resolves the correlation token
/// 6. Writes the milestone to the BAM activity store
///
/// Agents are completely unaware of this middleware — it is non-invasive.
/// </summary>
public class BamInterceptorMiddleware
{
    private readonly ITrackingProfileLoader _profileLoader;
    private readonly ICorrelationTokenService _tokenService;
    private readonly IActivityStore _activityStore;
    private readonly ILogger<BamInterceptorMiddleware> _logger;
    private readonly BamOptions _options;

    public BamInterceptorMiddleware(
        ITrackingProfileLoader profileLoader,
        ICorrelationTokenService tokenService,
        IActivityStore activityStore,
        IOptions<BamOptions> options,
        ILogger<BamInterceptorMiddleware> logger)
    {
        _profileLoader = profileLoader;
        _tokenService = tokenService;
        _activityStore = activityStore;
        _options = options.Value;
        _logger = logger;
    }

    /// <summary>
    /// Called by the agent framework after an agent completes a turn.
    /// This is the main interception point — equivalent to BizTalk's
    /// orchestration shape interceptor.
    /// </summary>
    public async Task OnAgentTurnCompleteAsync(AgentTurnContext context)
    {
        var agentName = context.AgentName;
        var agentOutput = context.Output;

        // Find all tracking profile bindings that match this agent
        var bindings = _profileLoader.GetBindingsForAgent(agentName);
        if (!bindings.Any())
        {
            _logger.LogTrace("No BAM bindings for agent '{Agent}', skipping", agentName);
            return;
        }

        foreach (var binding in bindings)
        {
            try
            {
                await ProcessBindingAsync(binding, context);
            }
            catch (Exception ex)
            {
                // BAM should never break the business process — log and continue
                _logger.LogWarning(ex,
                    "BAM milestone write failed for agent '{Agent}', milestone '{Milestone}'. " +
                    "Business process continues unaffected.",
                    agentName, binding.Milestone);
            }
        }
    }

    private async Task ProcessBindingAsync(TrackingBinding binding, AgentTurnContext context)
    {
        // Step 1: Evaluate condition — should this milestone fire?
        if (!EvaluateCondition(binding.Condition, context))
        {
            _logger.LogTrace("Condition not met for binding {Agent}→{Milestone}",
                binding.AgentName, binding.Milestone);
            return;
        }

        // Step 2: Resolve or mint the correlation token
        CorrelationToken token;
        if (binding.Correlation.Mint)
        {
            // First milestone — mint a new token
            var division = ExtractValue(binding.Correlation.DivisionSource, context);
            var objectId = ExtractValue(binding.Correlation.ObjectIdSource, context);
            var objectType = _profileLoader.GetActivityObjectType(binding.ActivityName);

            token = _tokenService.Mint(division, objectType, objectId);
            _logger.LogInformation(
                "BAM: Minted correlation token '{Token}' at milestone '{Milestone}'",
                token.Value, binding.Milestone);
        }
        else
        {
            // Subsequent milestone — look up existing token
            var lookupValue = ExtractValue(binding.Correlation.LookupBy, context);
            token = await _activityStore.LookupTokenAsync(
                binding.ActivityName, binding.Correlation.LookupBy, lookupValue);

            if (token == null)
            {
                _logger.LogWarning(
                    "BAM: Could not find correlation token for {Activity} " +
                    "where {Field}='{Value}'. Milestone '{Milestone}' skipped.",
                    binding.ActivityName, binding.Correlation.LookupBy,
                    lookupValue, binding.Milestone);
                return;
            }
        }

        // Step 3: Extract data items from agent output
        var dataItems = new Dictionary<string, object>();
        foreach (var mapping in binding.DataMappings)
        {
            var value = ExtractValue(mapping.Value, context);
            if (value != null)
            {
                dataItems[mapping.Key] = value;
            }
        }

        // Step 4: Write milestone to activity store
        var milestoneRecord = new MilestoneRecord
        {
            CorrelationToken = token,
            ActivityName = binding.ActivityName,
            MilestoneName = binding.Milestone,
            Timestamp = DateTime.UtcNow,
            DataItems = dataItems,
            AgentName = binding.AgentName,  // Stored for audit trail, not shown to business users
            Status = DetermineStatus(binding, context)
        };

        await _activityStore.WriteMilestoneAsync(milestoneRecord);

        _logger.LogInformation(
            "BAM: Milestone '{Milestone}' recorded for {Token}",
            binding.Milestone, token.Value);

        // Step 5: Propagate token in context for downstream agents
        if (_options.EnableContextPropagation)
        {
            context.SetMetadata("bam_correlation_token", token.Value);
        }

        // Step 6: Check if this is a terminal milestone → archive
        if (binding.IsTerminal)
        {
            await _activityStore.ArchiveActivityAsync(token);
            _logger.LogInformation("BAM: Activity {Token} archived (terminal milestone reached)", token.Value);
        }
    }

    /// <summary>
    /// Evaluates a condition expression against agent context.
    /// Supports simple dot-path equality checks.
    /// </summary>
    private bool EvaluateCondition(string? condition, AgentTurnContext context)
    {
        if (string.IsNullOrEmpty(condition))
            return true; // No condition = always fire

        // Simple expression evaluator for conditions like:
        // "output.status == 'parsed'"
        // "output.validation_result != null"
        var parts = condition.Split(" == ", 2);
        if (parts.Length == 2)
        {
            var actualValue = ExtractValue(parts[0].Trim(), context);
            var expectedValue = parts[1].Trim().Trim('\'', '"');
            return string.Equals(actualValue?.ToString(), expectedValue, StringComparison.OrdinalIgnoreCase);
        }

        parts = condition.Split(" != ", 2);
        if (parts.Length == 2)
        {
            var actualValue = ExtractValue(parts[0].Trim(), context);
            var expectedValue = parts[1].Trim().Trim('\'', '"');
            if (expectedValue == "null")
                return actualValue != null;
            return !string.Equals(actualValue?.ToString(), expectedValue, StringComparison.OrdinalIgnoreCase);
        }

        _logger.LogWarning("BAM: Unsupported condition expression: '{Condition}'", condition);
        return false;
    }

    /// <summary>
    /// Extracts a value from agent context using a dot-path expression.
    /// Supports paths like "output.order_id", "input.customer_name", "context.metadata.key"
    /// </summary>
    private object? ExtractValue(string? path, AgentTurnContext context)
    {
        if (string.IsNullOrEmpty(path))
            return null;

        var segments = path.Split('.');
        if (segments.Length < 2)
            return null;

        // Resolve root: output, input, or context
        JsonNode? root = segments[0] switch
        {
            "output" => context.OutputJson,
            "input" => context.InputJson,
            "context" => context.MetadataJson,
            _ => null
        };

        if (root == null)
            return null;

        // Navigate the JSON path
        JsonNode? current = root;
        for (int i = 1; i < segments.Length && current != null; i++)
        {
            current = current[segments[i]];
        }

        return current switch
        {
            JsonValue jv => jv.GetValue<object>(),
            _ => current?.ToString()
        };
    }

    private MilestoneStatus DetermineStatus(TrackingBinding binding, AgentTurnContext context)
    {
        if (binding.OnFailure != null)
        {
            if (EvaluateCondition(binding.OnFailure.Condition, context))
                return MilestoneStatus.Failed;
        }
        return MilestoneStatus.Completed;
    }
}

/// <summary>
/// Represents the agent turn context passed by Microsoft Agent Framework.
/// This is the data available to the interceptor when an agent completes.
/// </summary>
public class AgentTurnContext
{
    public required string AgentName { get; init; }
    public required JsonNode? OutputJson { get; init; }
    public required JsonNode? InputJson { get; init; }
    public required JsonNode? MetadataJson { get; init; }
    public object? Output { get; init; }

    private readonly Dictionary<string, string> _metadata = new();

    public void SetMetadata(string key, string value)
    {
        _metadata[key] = value;
    }

    public string? GetMetadata(string key)
    {
        return _metadata.TryGetValue(key, out var value) ? value : null;
    }
}
