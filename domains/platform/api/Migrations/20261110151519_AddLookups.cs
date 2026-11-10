using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Platform.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddLookups : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "lookups",
                schema: "platform",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    type = table.Column<string>(type: "citext", maxLength: 50, nullable: false),
                    code = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    label = table.Column<string>(type: "citext", maxLength: 255, nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_lookups", x => x.id);
                    table.CheckConstraint("ck_lookups_code_length", "char_length(\"code\") <= 100");
                    table.CheckConstraint("ck_lookups_label_length", "char_length(\"label\") <= 255");
                    table.CheckConstraint("ck_lookups_type_length", "char_length(\"type\") <= 50");
                });

            migrationBuilder.CreateIndex(
                name: "idx_type_active_sort",
                schema: "platform",
                table: "lookups",
                columns: new[] { "type", "is_active", "sort_order" });

            migrationBuilder.CreateIndex(
                name: "uniq_type_code",
                schema: "platform",
                table: "lookups",
                columns: new[] { "type", "code" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "lookups",
                schema: "platform");
        }
    }
}
