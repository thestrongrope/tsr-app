using Microsoft.EntityFrameworkCore;

namespace Tsr.Db.Tests;

/// <summary>An Entity Framework context built by hand, as the API host no longer registers one at run time; for the tests of the bridge to a caller's Entity Framework transaction.</summary>
internal static class EfContexts
{
    public static T Create<T>() where T : DbContext
    {
        var builder = new DbContextOptionsBuilder<T>().UseNpgsql(TestDatabase.AppConnection);
        return (T)Activator.CreateInstance(typeof(T), builder.Options)!;
    }
}
