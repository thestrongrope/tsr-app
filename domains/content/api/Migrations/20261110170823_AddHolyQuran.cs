using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Content.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddHolyQuran : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "holy_quran",
                schema: "content",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    surah = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    arabic = table.Column<string>(type: "citext", maxLength: 255, nullable: true),
                    verses = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_holy_quran", x => x.id);
                    table.CheckConstraint("ck_holy_quran_arabic_length", "char_length(\"arabic\") <= 255");
                    table.CheckConstraint("ck_holy_quran_surah_length", "char_length(\"surah\") <= 100");
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "holy_quran",
                schema: "content");
        }
    }
}
