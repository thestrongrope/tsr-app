using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Tsr.Membership.Api.Domain;
using Tsr.Membership.Api.Features.MeChildren;
using Tsr.Membership.Api.Features.MemberParentLinkCreate;
using Tsr.Membership.Api.Features.MemberParentLinks;
using Tsr.Membership.Api.Features.MemberParentLinkCancel;
using Tsr.Membership.Api.Features.MemberParentCandidate;
using Tsr.Membership.Api.Features.MemberParentsAdd;
using Tsr.Membership.Api.Features.RegistrationReject;
using Tsr.Membership.Api.Features.ReportRegistrations;
using Tsr.Membership.Api.Features.ReportRegistrationsAllocatedDownload;
using Tsr.Membership.Api.Features.ReportRegistrationsDownload;
using Tsr.Membership.Api.Features.StudentCard;
using Tsr.Membership.Api.Features.AdminDonors;
using Tsr.Membership.Api.Features.AdminDonorsDownload;
using Tsr.Membership.Api.Features.SubscriberCard;
using Tsr.Membership.Api.Features.ChildrenLinkAccept;
using Tsr.Membership.Api.Features.ChildrenLinkInspect;
using Tsr.Membership.Api.Features.ChildrenLinkRevoke;
using Tsr.Membership.Api.Features.ChildrenLinks;
using Tsr.Membership.Api.Features.ParentRevoke;
using Tsr.Membership.Api.Features.ParentsList;
using Tsr.Membership.Api.Features.ProfileGet;
using Tsr.Membership.Api.Features.ProfileUpdate;
using Tsr.Membership.Api.Features.RegistrationGet;
using Tsr.Membership.Api.Features.RegistrationSave;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api;

/// <summary>
/// membership: members' profiles, registrations, interests and guardians. Public interface of the module:
/// <see cref="MemberNames"/> and the port <see cref="IClassEnrolments"/> that <c>classes</c> will supply. The HTTP operations are the slices under features/.
/// </summary>
public static class MembershipModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7).</summary>
    public static readonly IReadOnlyList<string> Dependencies = ["access", "identity", "platform"];

    /// <summary>
    /// Registers membership. Its sink replaces identity's no-op one, so it must be registered after identity (the last
    /// registration wins); the default <see cref="IClassEnrolments"/> answers "not enrolled" and steps aside for the real one.
    /// </summary>
    public static IServiceCollection AddMembership(this IServiceCollection services)
    {
        services.AddDomainContext<MembershipContext>(MembershipContext.SchemaName);
        services.AddScoped<Tsr.Identity.Api.IProfileSink, ProfileSink>();
        services.TryAddScoped<IClassEnrolments, NoEnrolments>();
        services.AddScoped(provider => new MemberNames(provider.GetRequiredService<MembershipContext>()));
        services.TryAddSingleton<MemberRateLimit>();
        services.AddScoped<RegistrationGetHandler>();
        services.AddScoped<RegistrationSaveHandler>();
        services.AddScoped<LinkLister>();
        services.AddScoped<PlaceCheck>();
        services.AddScoped<GenderLock>();
        services.AddScoped<ProfileGetHandler>();
        services.AddScoped<ProfileUpdateHandler>();
        services.AddScoped<ChildrenLinksHandler>();
        services.AddScoped<ChildrenLinkInspectHandler>();
        services.AddScoped<ChildrenLinkAcceptHandler>();
        services.AddScoped<ChildrenLinkRevokeHandler>();
        services.AddScoped<ParentsListHandler>();
        services.AddScoped<ParentRevokeHandler>();
        return services;
    }

    public static IEndpointRouteBuilder MapMembership(this IEndpointRouteBuilder routes)
    {
        routes.MapProfileGet();
        routes.MapProfileUpdate();
        routes.MapRegistrationGet();
        routes.MapRegistrationSave();
        routes.MapChildrenLinks();
        routes.MapChildrenLinkInspect();
        routes.MapChildrenLinkAccept();
        routes.MapChildrenLinkRevoke();
        routes.MapParentsList();
        routes.MapParentRevoke();
        routes.MapMeChildren();
        routes.MapMemberParentLinkCreate();
        routes.MapMemberParentLinks();
        routes.MapMemberParentLinkCancel();
        routes.MapMemberParentCandidate();
        routes.MapMemberParentsAdd();
        routes.MapRegistrationReject();
        routes.MapReportRegistrations();
        routes.MapReportRegistrationsDownload();
        routes.MapReportRegistrationsAllocatedDownload();
        routes.MapStudentCard();
        routes.MapAdminDonors();
        routes.MapAdminDonorsDownload();
        routes.MapSubscriberCard();
        return routes;
    }
}
