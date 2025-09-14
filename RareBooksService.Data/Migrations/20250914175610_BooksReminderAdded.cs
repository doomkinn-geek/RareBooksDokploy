using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RareBooksService.Data.Migrations
{
    /// <inheritdoc />
    public partial class BooksReminderAdded : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Books_NormalizedTitle",
                table: "BooksInfo",
                column: "NormalizedTitle");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Books_NormalizedTitle",
                table: "BooksInfo");
        }
    }
}
