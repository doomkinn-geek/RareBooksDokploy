using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MayMessenger.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddContactsAndPhoneNumberHash : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PhoneNumberHash",
                table: "Users",
                type: "character varying(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateTable(
                name: "Contacts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PhoneNumberHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    DisplayName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    SyncedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Contacts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Contacts_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_PhoneNumberHash",
                table: "Users",
                column: "PhoneNumberHash");

            migrationBuilder.CreateIndex(
                name: "IX_Contacts_PhoneNumberHash",
                table: "Contacts",
                column: "PhoneNumberHash");

            migrationBuilder.CreateIndex(
                name: "IX_Contacts_UserId_PhoneNumberHash",
                table: "Contacts",
                columns: new[] { "UserId", "PhoneNumberHash" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Contacts");

            migrationBuilder.DropIndex(
                name: "IX_Users_PhoneNumberHash",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "PhoneNumberHash",
                table: "Users");
        }
    }
}
