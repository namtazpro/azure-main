// Agentic BAM - Correlation Token Service
// Implements the composite token format: {Division}-{ObjectType}-{ObjectID}-{Timestamp}

namespace AgenticBam.Runtime;

/// <summary>
/// Manages creation and parsing of BAM correlation tokens.
/// Format: {Division}-{ObjectType}-{ObjectID}-{TimestampUTC}
/// Example: EMEA-SO-4821-20260714T140103Z
/// </summary>
public interface ICorrelationTokenService
{
    /// <summary>Mints a new correlation token from extracted components.</summary>
    CorrelationToken Mint(string division, string objectType, string objectId);

    /// <summary>Parses an existing token string back into components.</summary>
    CorrelationToken Parse(string tokenString);

    /// <summary>Validates a token string format.</summary>
    bool IsValid(string tokenString);
}

/// <summary>
/// Represents a parsed correlation token with its constituent parts.
/// </summary>
public record CorrelationToken
{
    public required string Division { get; init; }
    public required string ObjectType { get; init; }
    public required string ObjectId { get; init; }
    public required DateTime Timestamp { get; init; }

    /// <summary>Full token string: {Division}-{ObjectType}-{ObjectID}-{Timestamp}</summary>
    public string Value => $"{Division}-{ObjectType}-{ObjectId}-{Timestamp:yyyyMMdd'T'HHmmss'Z'}";

    public override string ToString() => Value;
}

public class CorrelationTokenService : ICorrelationTokenService
{
    private const string TimestampFormat = "yyyyMMdd'T'HHmmss'Z'";

    public CorrelationToken Mint(string division, string objectType, string objectId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(division);
        ArgumentException.ThrowIfNullOrWhiteSpace(objectType);
        ArgumentException.ThrowIfNullOrWhiteSpace(objectId);

        // Normalize: uppercase division and object type
        var normalizedDivision = division.ToUpperInvariant();
        var normalizedObjectType = objectType.ToUpperInvariant();

        // Validate format constraints
        if (normalizedDivision.Length < 2 || normalizedDivision.Length > 6)
            throw new ArgumentException("Division must be 2-6 characters", nameof(division));

        if (normalizedObjectType.Length < 2 || normalizedObjectType.Length > 4)
            throw new ArgumentException("ObjectType must be 2-4 characters", nameof(objectType));

        return new CorrelationToken
        {
            Division = normalizedDivision,
            ObjectType = normalizedObjectType,
            ObjectId = objectId,
            Timestamp = DateTime.UtcNow
        };
    }

    public CorrelationToken Parse(string tokenString)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(tokenString);

        // Format: EMEA-SO-4821-20260714T140103Z
        // Split from the right since ObjectId might contain hyphens in future
        var parts = tokenString.Split('-');
        if (parts.Length < 4)
            throw new FormatException($"Invalid correlation token format: '{tokenString}'. Expected {{Division}}-{{ObjectType}}-{{ObjectId}}-{{Timestamp}}");

        var division = parts[0];
        var objectType = parts[1];
        // ObjectId is everything between objectType and timestamp
        // Timestamp is always the last part (format: 20260714T140103Z)
        var timestampPart = parts[^1];
        var objectId = string.Join("-", parts[2..^1]);

        if (!DateTime.TryParseExact(timestampPart, TimestampFormat,
            System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.AssumeUniversal, out var timestamp))
        {
            throw new FormatException($"Invalid timestamp in correlation token: '{timestampPart}'");
        }

        return new CorrelationToken
        {
            Division = division,
            ObjectType = objectType,
            ObjectId = objectId,
            Timestamp = timestamp.ToUniversalTime()
        };
    }

    public bool IsValid(string tokenString)
    {
        try
        {
            Parse(tokenString);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
