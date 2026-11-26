using System.Data;
using System.Data.Common;
using System.Reflection;
using Microsoft.EntityFrameworkCore;
using NUnit.Framework;

namespace Tsr.Shared.Api.Tests;

public sealed class DbTxTests
{
    // Issue 98: the only public way to a joined DbTx is EfTransaction.Join, which checks the owner's transaction is still the open one.
    [Test]
    public void DbTx_has_no_public_static_method_returning_a_DbTx()
    {
        var found = typeof(DbTx)
            .GetMethods(BindingFlags.Public | BindingFlags.Static | BindingFlags.DeclaredOnly)
            .Where(method => method.ReturnType == typeof(DbTx))
            .Select(method => method.Name);

        Assert.That(found, Is.Empty);
    }

    [Test]
    public void The_bridge_refuses_a_context_that_is_not_on_Npgsql_with_a_clear_message()
    {
        using var context = new OtherProviderContext();
        using var transaction = context.Database.BeginTransaction();

        var error = Assert.Throws<InvalidOperationException>(() => EfTransaction.Join(context));

        Assert.That(error!.Message, Does.Contain("Npgsql"));
    }

    private sealed class OtherProviderContext : DbContext
    {
        protected override void OnConfiguring(DbContextOptionsBuilder options) => options.UseNpgsql(new FakeConnection());
    }

    private sealed class FakeConnection : DbConnection
    {
        private ConnectionState _state = ConnectionState.Closed;

        [System.Diagnostics.CodeAnalysis.AllowNull]
        public override string ConnectionString { get; set; } = string.Empty;

        public override string Database => "fake";

        public override string DataSource => "fake";

        public override string ServerVersion => "1";

        public override ConnectionState State => _state;

        public override void ChangeDatabase(string databaseName) => throw new NotSupportedException();

        public override void Close() => _state = ConnectionState.Closed;

        public override void Open() => _state = ConnectionState.Open;

        protected override DbTransaction BeginDbTransaction(IsolationLevel isolationLevel) => new FakeTransaction(this, isolationLevel);

        protected override DbCommand CreateDbCommand() => throw new NotSupportedException();
    }

    private sealed class FakeTransaction(DbConnection connection, IsolationLevel level) : DbTransaction
    {
        public override IsolationLevel IsolationLevel => level;

        protected override DbConnection? DbConnection => connection;

        public override void Commit()
        {
        }

        public override void Rollback()
        {
        }
    }
}
