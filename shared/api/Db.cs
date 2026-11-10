using MySqlConnector;

namespace Tsr.Shared.Api;

/// <summary>
/// Opens connections to the one MariaDB. Infrastructure at an external boundary: every query a
/// slice runs goes through a connection from here, with parameters (prepared statements only).
/// </summary>
public sealed class Db
{
    private const int TimeoutSeconds = 5;

    private readonly string _connectionString;

    public Db(string connectionString)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(connectionString);
        var builder = new MySqlConnectionStringBuilder(connectionString)
        {
            ConnectionTimeout = TimeoutSeconds,
            DefaultCommandTimeout = TimeoutSeconds,
        };
        _connectionString = builder.ConnectionString;
    }

    public async Task<MySqlConnection> OpenAsync(CancellationToken ct)
    {
        var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync(ct);
        return connection;
    }
}
