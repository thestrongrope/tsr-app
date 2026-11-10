using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Platform.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddGeo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:CollationDefinition:public.geo_ci_ai", "und-u-ks-level1,und-u-ks-level1,icu,False")
                .Annotation("Npgsql:PostgresExtension:citext", ",,")
                .OldAnnotation("Npgsql:PostgresExtension:citext", ",,");

            migrationBuilder.CreateTable(
                name: "geo_cities",
                schema: "platform",
                columns: table => new
                {
                    geoname_id = table.Column<int>(type: "integer", nullable: false),
                    country_code = table.Column<string>(type: "citext", maxLength: 2, nullable: false),
                    name = table.Column<string>(type: "text", maxLength: 200, nullable: false, collation: "geo_ci_ai"),
                    state = table.Column<string>(type: "citext", maxLength: 150, nullable: true),
                    population = table.Column<int>(type: "integer", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_geo_cities", x => x.geoname_id);
                    table.CheckConstraint("ck_geo_cities_country_code_length", "char_length(\"country_code\") <= 2");
                    table.CheckConstraint("ck_geo_cities_name_length", "char_length(\"name\") <= 200");
                    table.CheckConstraint("ck_geo_cities_state_length", "char_length(\"state\") <= 150");
                });

            migrationBuilder.CreateTable(
                name: "geo_countries",
                schema: "platform",
                columns: table => new
                {
                    code = table.Column<string>(type: "citext", maxLength: 2, nullable: false),
                    name = table.Column<string>(type: "text", maxLength: 100, nullable: false, collation: "geo_ci_ai"),
                    has_postal_codes = table.Column<bool>(type: "boolean", nullable: false),
                    postal_code_regex = table.Column<string>(type: "citext", maxLength: 255, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_geo_countries", x => x.code);
                    table.CheckConstraint("ck_geo_countries_code_length", "char_length(\"code\") <= 2");
                    table.CheckConstraint("ck_geo_countries_name_length", "char_length(\"name\") <= 100");
                    table.CheckConstraint("ck_geo_countries_postal_code_regex_length", "char_length(\"postal_code_regex\") <= 255");
                });

            migrationBuilder.CreateTable(
                name: "geo_postal_codes",
                schema: "platform",
                columns: table => new
                {
                    country_code = table.Column<string>(type: "citext", maxLength: 2, nullable: false),
                    postal_code = table.Column<string>(type: "text", maxLength: 20, nullable: false, collation: "geo_ci_ai"),
                    city = table.Column<string>(type: "citext", maxLength: 255, nullable: true),
                    state = table.Column<string>(type: "citext", maxLength: 150, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_geo_postal_codes", x => new { x.country_code, x.postal_code });
                    table.CheckConstraint("ck_geo_postal_codes_city_length", "char_length(\"city\") <= 255");
                    table.CheckConstraint("ck_geo_postal_codes_country_code_length", "char_length(\"country_code\") <= 2");
                    table.CheckConstraint("ck_geo_postal_codes_postal_code_length", "char_length(\"postal_code\") <= 20");
                    table.CheckConstraint("ck_geo_postal_codes_state_length", "char_length(\"state\") <= 150");
                });

            migrationBuilder.CreateIndex(
                name: "idx_geo_cities_country_name",
                schema: "platform",
                table: "geo_cities",
                columns: new[] { "country_code", "name" });

            migrationBuilder.CreateIndex(
                name: "idx_geo_countries_name",
                schema: "platform",
                table: "geo_countries",
                column: "name");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "geo_cities",
                schema: "platform");

            migrationBuilder.DropTable(
                name: "geo_countries",
                schema: "platform");

            migrationBuilder.DropTable(
                name: "geo_postal_codes",
                schema: "platform");

            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:citext", ",,")
                .OldAnnotation("Npgsql:CollationDefinition:public.geo_ci_ai", "und-u-ks-level1,und-u-ks-level1,icu,False")
                .OldAnnotation("Npgsql:PostgresExtension:citext", ",,");
        }
    }
}
