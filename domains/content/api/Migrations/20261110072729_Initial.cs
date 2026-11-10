using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Content.Api.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "content");

            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:citext", ",,");

            migrationBuilder.CreateTable(
                name: "articles",
                schema: "content",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    slug = table.Column<string>(type: "citext", maxLength: 120, nullable: false),
                    title = table.Column<string>(type: "citext", maxLength: 200, nullable: false),
                    body = table.Column<string>(type: "citext", nullable: false),
                    published_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_articles", x => x.id);
                    table.CheckConstraint("ck_articles_slug_length", "char_length(\"slug\") <= 120");
                    table.CheckConstraint("ck_articles_title_length", "char_length(\"title\") <= 200");
                });

            migrationBuilder.CreateIndex(
                name: "idx_articles_published",
                schema: "content",
                table: "articles",
                column: "published_at");

            migrationBuilder.CreateIndex(
                name: "uq_articles_slug",
                schema: "content",
                table: "articles",
                column: "slug",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "articles",
                schema: "content");
        }
    }
}
