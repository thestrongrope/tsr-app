namespace Tsr.Shared.Api;

/// <summary>The one PostgreSQL connection string (TSR_DB), registered once by the host.</summary>
public sealed record DbSettings(string ConnectionString);
