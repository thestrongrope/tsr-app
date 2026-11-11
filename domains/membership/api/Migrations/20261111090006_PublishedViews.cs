using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Membership.Api.Migrations
{
    // The views this domain publishes to the others (domains/CLAUDE.md rule 2): a view is a contract; change one with its readers.
    /// <inheritdoc />
    [DbContext(typeof(MembershipContext))]
    [Migration("20261111090006_PublishedViews")]
    public sealed class PublishedViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view membership.v_members as
                select u.token, u.id as user_id, p.name, p.mobile, p.gender, p.city, p.state, p.country, p.zip
                from identity.v_users u
                left join membership.member_profiles p on p.user_id = u.id;
                """);
            migrationBuilder.Sql(
                """
                create view membership.v_registrations as
                select id, token, for_classid, class_level, class_number, preferred_location, status, created_at
                from membership.class_registrations;
                """);
            migrationBuilder.Sql(
                """
                create view membership.v_guardian_links as
                select id, parent_token, child_token, status
                from membership.user_guardians;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view membership.v_guardian_links;");
            migrationBuilder.Sql("drop view membership.v_registrations;");
            migrationBuilder.Sql("drop view membership.v_members;");
        }
    }
}
