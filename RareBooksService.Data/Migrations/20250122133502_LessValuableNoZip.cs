using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RareBooksService.Data.Migrations
{
    /// <inheritdoc />
    public partial class LessValuableNoZip : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsLessValuable",
                table: "BooksInfo",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsLessValuable",
                table: "BooksInfo");
        }
    }
}
