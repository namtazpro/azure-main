// Agentic BAM - Activity Store Interface and SQL Implementation
// Manages persistence of activity instances (active + completed)

namespace AgenticBam.Runtime;

/// <summary>
/// Abstraction over the BAM activity store.
/// Mirrors BizTalk BAM's Primary Import database pattern:
/// - Active table: real-time queryable instances in progress
/// - Completed table: archived instances for historical analysis
/// </summary>
public interface IActivityStore
{
    /// <summary>Writes a milestone to the active activity instance.</summary>
    Task WriteMilestoneAsync(MilestoneRecord record);

    /// <summary>Looks up an existing correlation token by a data item value.</summary>
    Task<CorrelationToken?> LookupTokenAsync(string activityName, string fieldPath, string fieldValue);

    /// <summary>Moves a completed activity from Active to Completed table.</summary>
    Task ArchiveActivityAsync(CorrelationToken token);

    /// <summary>Queries active instances for a given activity.</summary>
    Task<IReadOnlyList<ActivityInstance>> QueryActiveAsync(string activityName, ActivityQuery query);

    /// <summary>Gets a single activity instance by correlation token.</summary>
    Task<ActivityInstance?> GetByTokenAsync(string correlationToken);
}

public record MilestoneRecord
{
    public required CorrelationToken CorrelationToken { get; init; }
    public required string ActivityName { get; init; }
    public required string MilestoneName { get; init; }
    public required DateTime Timestamp { get; init; }
    public required Dictionary<string, object> DataItems { get; init; }
    public required string AgentName { get; init; }
    public MilestoneStatus Status { get; init; } = MilestoneStatus.Completed;
}

public enum MilestoneStatus
{
    Completed,
    Failed,
    Skipped
}

/// <summary>
/// Represents a single activity instance as stored in the BAM tables.
/// One row per business object (e.g., one row per Sales Order).
/// Milestone columns hold timestamps; data item columns hold business data.
/// </summary>
public class ActivityInstance
{
    public required string CorrelationToken { get; init; }
    public required string ActivityName { get; init; }
    public required Dictionary<string, DateTime?> Milestones { get; init; }
    public required Dictionary<string, object?> DataItems { get; init; }
    public required DateTime CreatedAt { get; init; }
    public required DateTime LastModifiedAt { get; init; }
    public string? CurrentMilestone { get; init; }
    public ActivityStatus Status { get; init; }
}

public enum ActivityStatus
{
    Active,
    Completed,
    Failed,
    Stalled
}

public class ActivityQuery
{
    public string? Region { get; set; }
    public string? CurrentMilestone { get; set; }
    public DateTime? CreatedAfter { get; set; }
    public DateTime? CreatedBefore { get; set; }
    public ActivityStatus? Status { get; set; }
    public int MaxResults { get; set; } = 100;
}

/// <summary>
/// SQL Server implementation of the BAM activity store.
/// Creates and manages the bam_{Activity}_Active and bam_{Activity}_Completed tables.
/// </summary>
public class SqlActivityStore : IActivityStore
{
    private readonly string _connectionString;
    private readonly ILogger<SqlActivityStore> _logger;

    public SqlActivityStore(IOptions<BamOptions> options, ILogger<SqlActivityStore> logger)
    {
        _connectionString = options.Value.ActivityStoreConnectionString;
        _logger = logger;
    }

    public async Task WriteMilestoneAsync(MilestoneRecord record)
    {
        var tableName = $"bam_{record.ActivityName}_Active";
        var token = record.CorrelationToken.Value;

        // Upsert pattern: insert if first milestone, update if subsequent
        // This creates a single row per activity instance with milestone timestamps as columns
        //
        // Example SQL generated:
        // INSERT INTO bam_SalesOrder_Active (CorrelationToken, OrderID, CustomerName, ..., Received)
        // VALUES ('EMEA-SO-4821-20260714T140103Z', '4821', 'Contoso', ..., '2026-07-14T14:01:03Z')
        // ON CONFLICT (CorrelationToken) DO UPDATE SET
        //   Validated = '2026-07-14T14:01:05Z',
        //   LineItemCount = 12,
        //   LastModifiedAt = GETUTCDATE()

        var milestoneColumn = record.MilestoneName;
        var dataColumns = record.DataItems;

        // Build the upsert command
        var setClauses = new List<string>
        {
            $"[{milestoneColumn}] = @milestoneTimestamp",
            $"[{milestoneColumn}_Status] = @milestoneStatus",
            "[LastModifiedAt] = @now",
            "[CurrentMilestone] = @milestoneName"
        };

        foreach (var (key, value) in dataColumns)
        {
            setClauses.Add($"[{key}] = @data_{key}");
        }

        _logger.LogDebug(
            "BAM Store: Writing milestone '{Milestone}' for token '{Token}' to {Table}",
            record.MilestoneName, token, tableName);

        // In production, this executes the parameterized SQL against the activity store.
        // Omitting ADO.NET boilerplate for clarity — the pattern is standard upsert.
        await ExecuteUpsertAsync(tableName, token, record);
    }

    public async Task<CorrelationToken?> LookupTokenAsync(
        string activityName, string fieldPath, string fieldValue)
    {
        // fieldPath comes as "input.order_id" — we need the column name
        // The column is the data item name that maps to this source field
        // For lookup, we search by the business key (e.g., OrderID column)
        var tableName = $"bam_{activityName}_Active";
        var columnName = ResolveColumnFromPath(fieldPath);

        _logger.LogDebug(
            "BAM Store: Looking up token in {Table} where {Column} = '{Value}'",
            tableName, columnName, fieldValue);

        // SELECT CorrelationToken FROM bam_SalesOrder_Active WHERE OrderID = '4821'
        var tokenString = await QueryScalarAsync(tableName, columnName, fieldValue);

        if (tokenString == null)
            return null;

        return new CorrelationTokenService().Parse(tokenString);
    }

    public async Task ArchiveActivityAsync(CorrelationToken token)
    {
        // Move from Active to Completed table (same as BizTalk BAM DTS packages)
        _logger.LogInformation("BAM Store: Archiving activity {Token} to Completed", token.Value);

        // INSERT INTO bam_{Activity}_Completed SELECT * FROM bam_{Activity}_Active WHERE CorrelationToken = @token
        // DELETE FROM bam_{Activity}_Active WHERE CorrelationToken = @token
        await Task.CompletedTask; // Placeholder for actual SQL execution
    }

    public async Task<IReadOnlyList<ActivityInstance>> QueryActiveAsync(
        string activityName, ActivityQuery query)
    {
        var tableName = $"bam_{activityName}_Active";
        // Build WHERE clause from query parameters
        // Returns activity instances matching the filter
        await Task.CompletedTask;
        return Array.Empty<ActivityInstance>();
    }

    public async Task<ActivityInstance?> GetByTokenAsync(string correlationToken)
    {
        // Search both Active and Completed tables
        await Task.CompletedTask;
        return null;
    }

    private string ResolveColumnFromPath(string fieldPath)
    {
        // "input.order_id" → "OrderID" (mapped via tracking profile data_mappings)
        // This is a simplified lookup — in production, this consults the profile metadata
        var field = fieldPath.Split('.').Last();
        return field switch
        {
            "order_id" => "OrderID",
            "customer_id" => "CustomerID",
            "customer_name" => "CustomerName",
            _ => field
        };
    }

    private Task ExecuteUpsertAsync(string tableName, string token, MilestoneRecord record)
    {
        // ADO.NET execution — omitted for prototype clarity
        return Task.CompletedTask;
    }

    private Task<string?> QueryScalarAsync(string tableName, string columnName, string value)
    {
        // ADO.NET execution — omitted for prototype clarity
        return Task.FromResult<string?>(null);
    }
}

// Required for compilation
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
