using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RareBooksService.Data.Migrations.UsersDb
{
    /// <inheritdoc />
    public partial class AddSoldInfoToCollectionBooks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<decimal>(
                name: "PurchasePrice",
                table: "UserCollectionBooks",
                type: "numeric(18,2)",
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric",
                oldNullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsSold",
                table: "UserCollectionBooks",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "SoldDate",
                table: "UserCollectionBooks",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "SoldPrice",
                table: "UserCollectionBooks",
                type: "numeric(18,2)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsSold",
                table: "UserCollectionBooks");

            migrationBuilder.DropColumn(
                name: "SoldDate",
                table: "UserCollectionBooks");

            migrationBuilder.DropColumn(
                name: "SoldPrice",
                table: "UserCollectionBooks");

            migrationBuilder.AlterColumn<decimal>(
                name: "PurchasePrice",
                table: "UserCollectionBooks",
                type: "numeric",
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)",
                oldNullable: true);
        }
    }
}
