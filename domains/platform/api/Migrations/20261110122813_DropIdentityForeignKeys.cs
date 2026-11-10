using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Platform.Api.Migrations
{
    /// <inheritdoc />
    public partial class DropIdentityForeignKeys : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // A domain never references another domain's tables (domains/CLAUDE.md rule 3). feedback.user_id and
            // handled_by stay plain integers; erasure of a member's feedback is identity's account-deletion event, not a
            // foreign key. Hand-written SQL: the model did not change, so EF generates nothing.
            migrationBuilder.Sql("alter table platform.feedback drop constraint if exists fk_feedback_user");
            migrationBuilder.Sql("alter table platform.feedback drop constraint if exists fk_feedback_handled_by");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Restores what the first migration made. Fails if a feedback row now points at a user that no longer exists.
            migrationBuilder.Sql(
                "alter table platform.feedback add constraint fk_feedback_user foreign key (user_id) references identity.users (id) on delete set null");
            migrationBuilder.Sql(
                "alter table platform.feedback add constraint fk_feedback_handled_by foreign key (handled_by) references identity.users (id) on delete set null");
        }
    }
}
