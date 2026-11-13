using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Content.Api.Migrations
{
    /// <inheritdoc />
    public partial class LibraryReads : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "categories",
                schema: "content",
                columns: table => new
                {
                    slug = table.Column<string>(type: "text", maxLength: 255, nullable: false),
                    title = table.Column<string>(type: "citext", maxLength: 255, nullable: false),
                    description = table.Column<string>(type: "citext", nullable: true),
                    sort_order = table.Column<int>(type: "integer", nullable: false),
                    parent_slug = table.Column<string>(type: "text", maxLength: 255, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_categories", x => x.slug);
                    table.CheckConstraint("ck_categories_parent_slug_length", "char_length(\"parent_slug\") <= 255");
                    table.CheckConstraint("ck_categories_slug_length", "char_length(\"slug\") <= 255");
                    table.CheckConstraint("ck_categories_title_length", "char_length(\"title\") <= 255");
                });

            migrationBuilder.CreateTable(
                name: "publications",
                schema: "content",
                columns: table => new
                {
                    position = table.Column<int>(type: "integer", nullable: false),
                    title = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    summary = table.Column<string>(type: "citext", nullable: true),
                    type = table.Column<string>(type: "citext", maxLength: 50, nullable: true),
                    size = table.Column<string>(type: "citext", maxLength: 50, nullable: true),
                    updated = table.Column<string>(type: "citext", maxLength: 50, nullable: true),
                    language = table.Column<string>(type: "citext", maxLength: 50, nullable: true),
                    file = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    read_online_url = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    download_only = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_publications", x => x.position);
                    table.CheckConstraint("ck_publications_file_length", "char_length(\"file\") <= 500");
                    table.CheckConstraint("ck_publications_language_length", "char_length(\"language\") <= 50");
                    table.CheckConstraint("ck_publications_read_online_url_length", "char_length(\"read_online_url\") <= 500");
                    table.CheckConstraint("ck_publications_size_length", "char_length(\"size\") <= 50");
                    table.CheckConstraint("ck_publications_title_length", "char_length(\"title\") <= 500");
                    table.CheckConstraint("ck_publications_type_length", "char_length(\"type\") <= 50");
                    table.CheckConstraint("ck_publications_updated_length", "char_length(\"updated\") <= 50");
                });

            migrationBuilder.CreateTable(
                name: "published_articles",
                schema: "content",
                columns: table => new
                {
                    slug = table.Column<string>(type: "text", nullable: false),
                    slug_decoded = table.Column<string>(type: "text", nullable: false),
                    legacy_id = table.Column<int>(type: "integer", nullable: true),
                    title = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    excerpt = table.Column<string>(type: "citext", nullable: true),
                    body_markdown = table.Column<string>(type: "citext", nullable: false),
                    body_html = table.Column<string>(type: "citext", nullable: false),
                    published_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    published_date_text = table.Column<string>(type: "citext", maxLength: 40, nullable: false),
                    modified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_date_text = table.Column<string>(type: "citext", maxLength: 40, nullable: true),
                    author = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    language = table.Column<string>(type: "citext", maxLength: 10, nullable: false),
                    reading_minutes = table.Column<int>(type: "integer", nullable: false),
                    categories = table.Column<string[]>(type: "text[]", nullable: false),
                    tags = table.Column<string[]>(type: "text[]", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_published_articles", x => x.slug);
                    table.CheckConstraint("ck_published_articles_author_length", "char_length(\"author\") <= 100");
                    table.CheckConstraint("ck_published_articles_language_length", "char_length(\"language\") <= 10");
                    table.CheckConstraint("ck_published_articles_modified_date_text_length", "char_length(\"modified_date_text\") <= 40");
                    table.CheckConstraint("ck_published_articles_published_date_text_length", "char_length(\"published_date_text\") <= 40");
                    table.CheckConstraint("ck_published_articles_title_length", "char_length(\"title\") <= 500");
                });

            migrationBuilder.CreateTable(
                name: "refresh_state",
                schema: "content",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false),
                    content_hash = table.Column<string>(type: "citext", maxLength: 64, nullable: false),
                    article_count = table.Column<int>(type: "integer", nullable: false),
                    refreshed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    last_failure_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    last_failure_cause = table.Column<string>(type: "citext", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_refresh_state", x => x.id);
                    table.CheckConstraint("ck_refresh_state_content_hash_length", "char_length(\"content_hash\") <= 64");
                    table.CheckConstraint("ck_refresh_state_last_failure_cause_length", "char_length(\"last_failure_cause\") <= 200");
                });

            migrationBuilder.CreateIndex(
                name: "idx_published_articles_categories",
                schema: "content",
                table: "published_articles",
                column: "categories")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "idx_published_articles_published_at",
                schema: "content",
                table: "published_articles",
                column: "published_at");

            migrationBuilder.CreateIndex(
                name: "idx_published_articles_tags",
                schema: "content",
                table: "published_articles",
                column: "tags")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "uq_published_articles_slug_decoded",
                schema: "content",
                table: "published_articles",
                column: "slug_decoded",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "categories",
                schema: "content");

            migrationBuilder.DropTable(
                name: "publications",
                schema: "content");

            migrationBuilder.DropTable(
                name: "published_articles",
                schema: "content");

            migrationBuilder.DropTable(
                name: "refresh_state",
                schema: "content");
        }
    }
}
