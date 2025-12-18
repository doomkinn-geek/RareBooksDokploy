using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MayMessenger.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPerformanceIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Index for getting messages by chat, ordered by creation time (most common query)
            migrationBuilder.CreateIndex(
                name: "IX_Messages_ChatId_CreatedAt",
                table: "Messages",
                columns: new[] { "ChatId", "CreatedAt" },
                descending: new[] { false, true });

            // Index for finding messages by sender
            migrationBuilder.CreateIndex(
                name: "IX_Messages_SenderId",
                table: "Messages",
                column: "SenderId");

            // Index for delivery receipts lookup (message + user combination)
            migrationBuilder.CreateIndex(
                name: "IX_DeliveryReceipts_MessageId_UserId",
                table: "DeliveryReceipts",
                columns: new[] { "MessageId", "UserId" });

            // Partial index for active FCM tokens only (saves space and improves lookups)
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS IX_FcmTokens_UserId_IsActive 
                ON ""FcmTokens""(""UserId"", ""IsActive"") 
                WHERE ""IsActive"" = true;
            ");

            // Index for FCM token cleanup (finding old tokens)
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS IX_FcmTokens_LastUsedAt 
                ON ""FcmTokens""(""LastUsedAt"") 
                WHERE ""IsActive"" = true;
            ");

            // Index for chat participants lookup by user
            migrationBuilder.CreateIndex(
                name: "IX_ChatParticipants_UserId",
                table: "ChatParticipants",
                column: "UserId");

            // Index for chat participants by chat
            migrationBuilder.CreateIndex(
                name: "IX_ChatParticipants_ChatId",
                table: "ChatParticipants",
                column: "ChatId");

            // Index for contacts by user
            migrationBuilder.CreateIndex(
                name: "IX_Contacts_UserId",
                table: "Contacts",
                column: "UserId");

            // Partial index for active invite links lookup
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS IX_InviteLinks_Code 
                ON ""InviteLinks""(""Code"") 
                WHERE ""IsActive"" = true;
            ");

            // Index for invite links by creator
            migrationBuilder.CreateIndex(
                name: "IX_InviteLinks_CreatedById",
                table: "InviteLinks",
                column: "CreatedById");

            // Analyze tables to update statistics after adding indexes
            migrationBuilder.Sql(@"
                ANALYZE ""Messages"";
                ANALYZE ""DeliveryReceipts"";
                ANALYZE ""FcmTokens"";
                ANALYZE ""ChatParticipants"";
                ANALYZE ""Contacts"";
                ANALYZE ""InviteLinks"";
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Drop all created indexes
            migrationBuilder.DropIndex(
                name: "IX_Messages_ChatId_CreatedAt",
                table: "Messages");

            migrationBuilder.DropIndex(
                name: "IX_Messages_SenderId",
                table: "Messages");

            migrationBuilder.DropIndex(
                name: "IX_DeliveryReceipts_MessageId_UserId",
                table: "DeliveryReceipts");

            migrationBuilder.Sql(@"DROP INDEX IF EXISTS IX_FcmTokens_UserId_IsActive;");
            migrationBuilder.Sql(@"DROP INDEX IF EXISTS IX_FcmTokens_LastUsedAt;");

            migrationBuilder.DropIndex(
                name: "IX_ChatParticipants_UserId",
                table: "ChatParticipants");

            migrationBuilder.DropIndex(
                name: "IX_ChatParticipants_ChatId",
                table: "ChatParticipants");

            migrationBuilder.DropIndex(
                name: "IX_Contacts_UserId",
                table: "Contacts");

            migrationBuilder.Sql(@"DROP INDEX IF EXISTS IX_InviteLinks_Code;");

            migrationBuilder.DropIndex(
                name: "IX_InviteLinks_CreatedById",
                table: "InviteLinks");
        }
    }
}

