using Tsr.Platform.Api.Domain;
using NUnit.Framework;

namespace Tsr.Platform.Api.Tests.Domain;

public sealed class AccessLogTests
{
    [TestCase("=1+1", "'=1+1")]
    [TestCase("  +cmd", "'  +cmd")]
    [TestCase("-5", "'-5")]
    [TestCase("@sum", "'@sum")]
    [TestCase("/admin/page", "/admin/page")]
    [TestCase("", "")]
    [TestCase(null, "")]
    public void Formula_like_values_get_a_leading_apostrophe(string? value, string expected) =>
        Assert.That(AccessLog.SpreadsheetSafe(value), Is.EqualTo(expected));

    [TestCase(null, "")]
    [TestCase(0, "Member")]
    [TestCase(1, "Admin")]
    [TestCase(7, "Finance")]
    [TestCase(2, "Role 2")]
    public void Role_names_are_PHPs(int? roleId, string expected) => Assert.That(AccessLog.RoleName(roleId), Is.EqualTo(expected));
}
