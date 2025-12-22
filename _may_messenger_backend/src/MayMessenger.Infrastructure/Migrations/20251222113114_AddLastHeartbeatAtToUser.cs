using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MayMessenger.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddLastHeartbeatAtToUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "LastHeartbeatAt",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "LastHeartbeatAt",
                table: "Users");
        }
    }
}
