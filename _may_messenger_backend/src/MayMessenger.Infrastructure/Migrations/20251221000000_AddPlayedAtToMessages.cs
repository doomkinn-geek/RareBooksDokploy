using Microsoft.EntityFrameworkCore.Migrations;
using System;

#nullable disable

namespace MayMessenger.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPlayedAtToMessages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "PlayedAt",
                table: "Messages",
                type: "timestamp without time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Messages_PlayedAt",
                table: "Messages",
                column: "PlayedAt",
                filter: "\"PlayedAt\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Messages_PlayedAt",
                table: "Messages");

            migrationBuilder.DropColumn(
                name: "PlayedAt",
                table: "Messages");
        }
    }
}

