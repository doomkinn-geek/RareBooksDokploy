using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RareBooksService.Data.Migrations
{
    /// <inheritdoc />
    public partial class LessValuableLot : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ImageArchiveUrl",
                table: "BooksInfo",
                type: "text",
                nullable: true,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "IsImagesCompressed",
                table: "BooksInfo",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ImageArchiveUrl",
                table: "BooksInfo");

            migrationBuilder.DropColumn(
                name: "IsImagesCompressed",
                table: "BooksInfo");
        }
    }
}
