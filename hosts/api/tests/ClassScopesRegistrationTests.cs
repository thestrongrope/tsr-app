using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Access.Api;

namespace Tsr.Host.Api.Tests;

/// <summary>access defaults to "no classes"; the full host must have classes' implementation replace it, or every class permission is silently denied.</summary>
public sealed class ClassScopesRegistrationTests
{
    [Test]
    public void The_full_host_resolves_the_classes_implementation_of_the_class_scopes_port()
    {
        using var host = new ApiHost();
        using var scope = host.Services.CreateScope();

        var scopes = scope.ServiceProvider.GetRequiredService<IClassScopes>();

        Assert.That(scopes.GetType().FullName, Is.EqualTo("Tsr.Classes.Api.ClassScopes"));
    }
}
