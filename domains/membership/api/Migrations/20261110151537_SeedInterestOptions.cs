using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Membership.Api.Migrations
{
    /// <inheritdoc />
    public partial class SeedInterestOptions : Migration
    {
        // The registration form's interest list as PHP holds it today: 19 rows with PHP's ids, names, order and active flags
        // (DB/2025_12_08_create_interest_options.sql seeded 12; DB/2025_12_09_update_interest_options.sql and later edits made
        // it these 19). The ids are the ones a client sends as interestIds, so they are kept. The sequence then continues after the last.
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                insert into membership.interest_options (id, name, sort_order, is_active) overriding system value values
                  (1, 'Class Coordination', 3, true),
                  (2, 'Creating Images & Videos', 6, true),
                  (3, 'Debates', 3, false),
                  (4, 'Devops / Infra', 4, false),
                  (5, 'HR', 8, true),
                  (6, 'Organizing Programs', 9, true),
                  (7, 'Other', 99, true),
                  (8, 'Research (syllabus/articles/scripts/translation)', 10, true),
                  (9, 'Social Media Marketing', 11, true),
                  (10, 'AI / Tech', 13, true),
                  (11, 'Teaching', 1, true),
                  (12, 'Writing (articles / scripts)', 11, false),
                  (13, 'Children Activities', 2, true),
                  (14, 'New Class Formation', 4, true),
                  (15, 'Administration', 5, true),
                  (16, 'Finance & Accounts', 7, true),
                  (17, 'PR', 12, true),
                  (18, 'Out of Mumbai', 14, true),
                  (19, 'Legal', 15, true);
                select setval(pg_get_serial_sequence('membership.interest_options', 'id'), (select max(id) from membership.interest_options));
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("delete from membership.interest_options where id between 1 and 19");
        }
    }
}
