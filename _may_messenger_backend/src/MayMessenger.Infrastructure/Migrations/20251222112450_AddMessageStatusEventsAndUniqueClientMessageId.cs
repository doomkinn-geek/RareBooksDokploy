using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MayMessenger.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddMessageStatusEventsAndUniqueClientMessageId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Messages_ClientMessageId",
                table: "Messages");

            migrationBuilder.CreateTable(
                name: "MessageStatusEvents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    MessageId = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    Source = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Timestamp = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MessageStatusEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MessageStatusEvents_Messages_MessageId",
                        column: x => x.MessageId,
                        principalTable: "Messages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MessageStatusEvents_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Messages_ClientMessageId",
                table: "Messages",
                column: "ClientMessageId",
                unique: true,
                filter: "\"ClientMessageId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_MessageStatusEvents_MessageId_Timestamp",
                table: "MessageStatusEvents",
                columns: new[] { "MessageId", "Timestamp" });

            migrationBuilder.CreateIndex(
                name: "IX_MessageStatusEvents_UserId_Timestamp",
                table: "MessageStatusEvents",
                columns: new[] { "UserId", "Timestamp" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MessageStatusEvents");

            migrationBuilder.DropIndex(
                name: "IX_Messages_ClientMessageId",
                table: "Messages");

            migrationBuilder.CreateIndex(
                name: "IX_Messages_ClientMessageId",
                table: "Messages",
                column: "ClientMessageId");
        }
    }
}
