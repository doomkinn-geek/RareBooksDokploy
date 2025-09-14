using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace RareBooksService.Data.Migrations.UsersDb
{
    /// <inheritdoc />
    public partial class TelegramIdToUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_UserFavoriteBooks_UserId",
                table: "UserFavoriteBooks");

            migrationBuilder.AddColumn<string>(
                name: "TelegramId",
                table: "AspNetUsers",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TelegramUsername",
                table: "AspNetUsers",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "UserNotificationPreferences",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserId = table.Column<string>(type: "text", nullable: false),
                    IsEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    Keywords = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    CategoryIds = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    MinPrice = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    MaxPrice = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    MinYear = table.Column<int>(type: "integer", nullable: false),
                    MaxYear = table.Column<int>(type: "integer", nullable: false),
                    Cities = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    NotificationFrequencyMinutes = table.Column<int>(type: "integer", nullable: false),
                    DeliveryMethod = table.Column<int>(type: "integer", nullable: false),
                    LastNotificationSent = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserNotificationPreferences", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserNotificationPreferences_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "BookNotifications",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserId = table.Column<string>(type: "text", nullable: false),
                    BookId = table.Column<int>(type: "integer", nullable: false),
                    BookTitle = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    BookDescription = table.Column<string>(type: "character varying(5000)", maxLength: 5000, nullable: false),
                    BookPrice = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    BookFinalPrice = table.Column<decimal>(type: "numeric(18,2)", nullable: true),
                    BookCity = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    BookBeginDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    BookEndDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    BookStatus = table.Column<int>(type: "integer", nullable: false),
                    DeliveryMethod = table.Column<int>(type: "integer", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    Subject = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Content = table.Column<string>(type: "character varying(10000)", maxLength: 10000, nullable: false),
                    RecipientAddress = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    SentAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DeliveredAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ReadAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ErrorMessage = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    AttemptsCount = table.Column<int>(type: "integer", nullable: false),
                    NextAttemptAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    MatchedKeywords = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    UserNotificationPreferenceId = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BookNotifications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BookNotifications_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_BookNotifications_UserNotificationPreferences_UserNotificat~",
                        column: x => x.UserNotificationPreferenceId,
                        principalTable: "UserNotificationPreferences",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BookNotifications_BookId",
                table: "BookNotifications",
                column: "BookId");

            migrationBuilder.CreateIndex(
                name: "IX_BookNotifications_CreatedAt",
                table: "BookNotifications",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_BookNotifications_Status",
                table: "BookNotifications",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_BookNotifications_UserId",
                table: "BookNotifications",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_BookNotifications_UserNotificationPreferenceId",
                table: "BookNotifications",
                column: "UserNotificationPreferenceId");

            migrationBuilder.CreateIndex(
                name: "IX_UserNotificationPreferences_IsEnabled",
                table: "UserNotificationPreferences",
                column: "IsEnabled");

            migrationBuilder.CreateIndex(
                name: "IX_UserNotificationPreferences_UserId",
                table: "UserNotificationPreferences",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BookNotifications");

            migrationBuilder.DropTable(
                name: "UserNotificationPreferences");

            migrationBuilder.DropColumn(
                name: "TelegramId",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "TelegramUsername",
                table: "AspNetUsers");

            migrationBuilder.CreateIndex(
                name: "IX_UserFavoriteBooks_UserId",
                table: "UserFavoriteBooks",
                column: "UserId");
        }
    }
}
