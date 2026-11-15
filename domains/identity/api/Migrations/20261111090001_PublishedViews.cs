using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Identity.Api.Migrations
{
    // The views this domain publishes to the others (domains/CLAUDE.md rule 2): a view is a contract; change one with its readers.
    /// <inheritdoc />
    [DbContext(typeof(IdentityContext))]
    [Migration("20261111090001_PublishedViews")]
    public sealed class PublishedViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view identity.v_users as
                select id, token, email, createdon as created_on,
                       (firebase_uid is not null and firebase_uid <> '') as has_firebase_link
                from identity.users;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view identity.v_users;");
        }
    }
}
