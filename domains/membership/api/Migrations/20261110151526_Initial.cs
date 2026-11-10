using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Membership.Api.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "membership");

            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:citext", ",,");

            migrationBuilder.CreateTable(
                name: "class_registrations",
                schema: "membership",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    token = table.Column<int>(type: "integer", nullable: true),
                    for_classid = table.Column<int>(type: "integer", nullable: true),
                    residence_location = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    work_location = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    preferred_location = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    class_level = table.Column<string>(type: "citext", maxLength: 20, nullable: true),
                    class_number = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    birth_year = table.Column<int>(type: "integer", nullable: true),
                    profession = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    islamic_study_years = table.Column<int>(type: "integer", nullable: true),
                    interests = table.Column<string>(type: "citext", maxLength: 400, nullable: true),
                    other_interests = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    education = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    field_of_study = table.Column<string>(type: "jsonb", nullable: true),
                    field_of_study_other = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    professional_courses = table.Column<string>(type: "jsonb", nullable: true),
                    professional_courses_other = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    occupation_type = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    field_of_work = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    years_experience = table.Column<string>(type: "citext", maxLength: 50, nullable: true),
                    role_level = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    linkedin_url = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 20, nullable: false, defaultValue: "Pending"),
                    status_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    status_reason = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    modified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_registrations", x => x.id);
                    table.CheckConstraint("ck_class_registrations_class_level", "class_level in ('IKP', 'IJP', 'IBP', 'Primary', 'Secondary', 'Advance')");
                    table.CheckConstraint("ck_class_registrations_class_level_length", "char_length(\"class_level\") <= 20");
                    table.CheckConstraint("ck_class_registrations_class_number_length", "char_length(\"class_number\") <= 100");
                    table.CheckConstraint("ck_class_registrations_education_length", "char_length(\"education\") <= 100");
                    table.CheckConstraint("ck_class_registrations_field_of_study_other_length", "char_length(\"field_of_study_other\") <= 200");
                    table.CheckConstraint("ck_class_registrations_field_of_work_length", "char_length(\"field_of_work\") <= 100");
                    table.CheckConstraint("ck_class_registrations_interests", "string_to_array(lower(interests::text), ',') <@ array['teaching', 'creating audio-video content', 'organizing programs', 'research', 'writing (articles / scripts)', 'debates', 'social media marketing', 'software development', 'devops / infra', 'coordination / administration', 'hr', 'other']");
                    table.CheckConstraint("ck_class_registrations_interests_length", "char_length(\"interests\") <= 400");
                    table.CheckConstraint("ck_class_registrations_linkedin_url_length", "char_length(\"linkedin_url\") <= 500");
                    table.CheckConstraint("ck_class_registrations_occupation_type_length", "char_length(\"occupation_type\") <= 100");
                    table.CheckConstraint("ck_class_registrations_other_interests_length", "char_length(\"other_interests\") <= 500");
                    table.CheckConstraint("ck_class_registrations_preferred_location_length", "char_length(\"preferred_location\") <= 1000");
                    table.CheckConstraint("ck_class_registrations_profession_length", "char_length(\"profession\") <= 500");
                    table.CheckConstraint("ck_class_registrations_professional_courses_other_length", "char_length(\"professional_courses_other\") <= 200");
                    table.CheckConstraint("ck_class_registrations_residence_location_length", "char_length(\"residence_location\") <= 300");
                    table.CheckConstraint("ck_class_registrations_role_level_length", "char_length(\"role_level\") <= 100");
                    table.CheckConstraint("ck_class_registrations_status", "status in ('Pending', 'Accepted', 'Rejected')");
                    table.CheckConstraint("ck_class_registrations_status_length", "char_length(\"status\") <= 20");
                    table.CheckConstraint("ck_class_registrations_status_reason_length", "char_length(\"status_reason\") <= 500");
                    table.CheckConstraint("ck_class_registrations_work_location_length", "char_length(\"work_location\") <= 300");
                    table.CheckConstraint("ck_class_registrations_years_experience_length", "char_length(\"years_experience\") <= 50");
                });

            migrationBuilder.CreateTable(
                name: "class_registrations_languages",
                schema: "membership",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    token = table.Column<int>(type: "integer", nullable: true),
                    language = table.Column<string>(type: "citext", maxLength: 20, nullable: true),
                    skill = table.Column<string>(type: "citext", maxLength: 20, nullable: true),
                    proficiency = table.Column<string>(type: "citext", maxLength: 20, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_registrations_languages", x => x.id);
                    table.CheckConstraint("ck_class_registrations_languages_language", "language in ('English', 'Hindi', 'Urdu', 'Gujarati', 'Arabic', 'Persian')");
                    table.CheckConstraint("ck_class_registrations_languages_language_length", "char_length(\"language\") <= 20");
                    table.CheckConstraint("ck_class_registrations_languages_proficiency", "proficiency in ('Don''t Know', 'Beginner', 'Learning', 'Fluent')");
                    table.CheckConstraint("ck_class_registrations_languages_proficiency_length", "char_length(\"proficiency\") <= 20");
                    table.CheckConstraint("ck_class_registrations_languages_skill", "skill in ('Read', 'Write', 'Speak', 'Understand')");
                    table.CheckConstraint("ck_class_registrations_languages_skill_length", "char_length(\"skill\") <= 20");
                });

            migrationBuilder.CreateTable(
                name: "interest_options",
                schema: "membership",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_interest_options", x => x.id);
                    table.CheckConstraint("ck_interest_options_name_length", "char_length(\"name\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "member_profiles",
                schema: "membership",
                columns: table => new
                {
                    user_id = table.Column<int>(type: "integer", nullable: false),
                    name = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    first_name = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    last_name = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    picture = table.Column<string>(type: "citext", maxLength: 2000, nullable: true),
                    gender = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    age_range = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    mobile = table.Column<string>(type: "citext", maxLength: 100, nullable: false, defaultValue: ""),
                    country = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    state = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    city = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    zip = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    language = table.Column<int>(type: "integer", nullable: true, defaultValue: 0),
                    sendupdates = table.Column<string>(type: "citext", maxLength: 1, nullable: false, defaultValue: "N"),
                    unsubscribe = table.Column<string>(type: "citext", maxLength: 1, nullable: false, defaultValue: "N")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_member_profiles", x => x.user_id);
                    table.CheckConstraint("ck_member_profiles_age_range_length", "char_length(\"age_range\") <= 200");
                    table.CheckConstraint("ck_member_profiles_city_length", "char_length(\"city\") <= 200");
                    table.CheckConstraint("ck_member_profiles_country_length", "char_length(\"country\") <= 200");
                    table.CheckConstraint("ck_member_profiles_first_name_length", "char_length(\"first_name\") <= 200");
                    table.CheckConstraint("ck_member_profiles_gender_length", "char_length(\"gender\") <= 200");
                    table.CheckConstraint("ck_member_profiles_last_name_length", "char_length(\"last_name\") <= 200");
                    table.CheckConstraint("ck_member_profiles_mobile_length", "char_length(\"mobile\") <= 100");
                    table.CheckConstraint("ck_member_profiles_name_length", "char_length(\"name\") <= 200");
                    table.CheckConstraint("ck_member_profiles_picture_length", "char_length(\"picture\") <= 2000");
                    table.CheckConstraint("ck_member_profiles_sendupdates_length", "char_length(\"sendupdates\") <= 1");
                    table.CheckConstraint("ck_member_profiles_state_length", "char_length(\"state\") <= 200");
                    table.CheckConstraint("ck_member_profiles_unsubscribe_length", "char_length(\"unsubscribe\") <= 1");
                    table.CheckConstraint("ck_member_profiles_zip_length", "char_length(\"zip\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "user_guardians",
                schema: "membership",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    parent_token = table.Column<int>(type: "integer", nullable: true),
                    child_token = table.Column<int>(type: "integer", nullable: false),
                    relationship = table.Column<string>(type: "citext", maxLength: 20, nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 20, nullable: false, defaultValue: "invited"),
                    source = table.Column<string>(type: "citext", maxLength: 20, nullable: false),
                    code = table.Column<string>(type: "citext", maxLength: 32, nullable: true),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<int>(type: "integer", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    activated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    revoked_by = table.Column<int>(type: "integer", nullable: true),
                    revoked_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_guardians", x => x.id);
                    table.CheckConstraint("ck_user_guardians_code_length", "char_length(\"code\") <= 32");
                    table.CheckConstraint("ck_user_guardians_relationship", "relationship in ('father', 'mother', 'guardian')");
                    table.CheckConstraint("ck_user_guardians_relationship_length", "char_length(\"relationship\") <= 20");
                    table.CheckConstraint("ck_user_guardians_source", "source in ('link', 'token_entry')");
                    table.CheckConstraint("ck_user_guardians_source_length", "char_length(\"source\") <= 20");
                    table.CheckConstraint("ck_user_guardians_status", "status in ('invited', 'active', 'revoked')");
                    table.CheckConstraint("ck_user_guardians_status_length", "char_length(\"status\") <= 20");
                });

            migrationBuilder.CreateTable(
                name: "student_interests",
                schema: "membership",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    token = table.Column<int>(type: "integer", nullable: false),
                    interest_id = table.Column<int>(type: "integer", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_student_interests", x => x.id);
                    table.ForeignKey(
                        name: "FK_student_interests_interest_options_interest_id",
                        column: x => x.interest_id,
                        principalSchema: "membership",
                        principalTable: "interest_options",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "idx_class_registrations_token",
                schema: "membership",
                table: "class_registrations",
                column: "token");

            migrationBuilder.CreateIndex(
                name: "idx_class_registrations_languages_token",
                schema: "membership",
                table: "class_registrations_languages",
                column: "token");

            migrationBuilder.CreateIndex(
                name: "uq_interest_options_name",
                schema: "membership",
                table: "interest_options",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_student_interests_token",
                schema: "membership",
                table: "student_interests",
                column: "token");

            migrationBuilder.CreateIndex(
                name: "IX_student_interests_interest_id",
                schema: "membership",
                table: "student_interests",
                column: "interest_id");

            migrationBuilder.CreateIndex(
                name: "uq_student_interests_token_interest",
                schema: "membership",
                table: "student_interests",
                columns: new[] { "token", "interest_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_child_token",
                schema: "membership",
                table: "user_guardians",
                column: "child_token");

            migrationBuilder.CreateIndex(
                name: "idx_code",
                schema: "membership",
                table: "user_guardians",
                column: "code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_parent_token",
                schema: "membership",
                table: "user_guardians",
                column: "parent_token");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "class_registrations",
                schema: "membership");

            migrationBuilder.DropTable(
                name: "class_registrations_languages",
                schema: "membership");

            migrationBuilder.DropTable(
                name: "member_profiles",
                schema: "membership");

            migrationBuilder.DropTable(
                name: "student_interests",
                schema: "membership");

            migrationBuilder.DropTable(
                name: "user_guardians",
                schema: "membership");

            migrationBuilder.DropTable(
                name: "interest_options",
                schema: "membership");
        }
    }
}
