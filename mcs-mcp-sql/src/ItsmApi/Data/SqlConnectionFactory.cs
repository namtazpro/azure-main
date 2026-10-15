using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace ItsmApi.Data;

public interface ISqlConnectionFactory
{
    Task<SqlConnection> OpenAsync(CancellationToken ct);
}

public sealed class SqlConnectionFactory(IConfiguration configuration) : ISqlConnectionFactory
{
    private readonly string _connectionString = configuration["SqlConnectionString"]
        ?? throw new InvalidOperationException("SqlConnectionString app setting is missing.");

    public async Task<SqlConnection> OpenAsync(CancellationToken ct)
    {
        var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(ct);
        return connection;
    }
}
