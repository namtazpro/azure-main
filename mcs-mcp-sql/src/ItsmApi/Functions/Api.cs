using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace ItsmApi.Functions;

internal static class Api
{
    public const string SecurityScheme = "function_key";

    public static async Task<IActionResult> RunAsync(Func<Task<IActionResult>> action)
    {
        try
        {
            return await action();
        }
        catch (SqlException ex) when (ex.Number == 50001)
        {
            return new NotFoundObjectResult(new ErrorResponse { Error = ex.Message });
        }
        catch (SqlException ex) when (ex.Number == 50002)
        {
            return new BadRequestObjectResult(new ErrorResponse { Error = ex.Message });
        }
    }

    public static string? Str(this IQueryCollection q, string key) =>
        q.TryGetValue(key, out var v) && !string.IsNullOrWhiteSpace(v) ? v.ToString().Trim() : null;

    public static int? Int(this IQueryCollection q, string key) =>
        int.TryParse(q.Str(key), out var v) ? v : null;

    public static DateTime? Date(this IQueryCollection q, string key) =>
        DateTime.TryParse(q.Str(key), System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.AdjustToUniversal | System.Globalization.DateTimeStyles.AssumeUniversal, out var v) ? v : null;

    public static bool Bool(this IQueryCollection q, string key) =>
        bool.TryParse(q.Str(key), out var v) && v;
}
