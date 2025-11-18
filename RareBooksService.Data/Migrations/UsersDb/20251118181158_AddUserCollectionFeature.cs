using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace RareBooksService.Data.Migrations.UsersDb
{
    /// <inheritdoc />
    public partial class AddUserCollectionFeature : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "HasCollectionAccess",
                table: "SubscriptionPlans",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "RegularBaseCategory",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    CategoryId = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RegularBaseCategory", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "RegularBaseBook",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Title = table.Column<string>(type: "text", nullable: false),
                    NormalizedTitle = table.Column<string>(type: "text", nullable: false),
                    Description = table.Column<string>(type: "text", nullable: false),
                    NormalizedDescription = table.Column<string>(type: "text", nullable: false),
                    BeginDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    EndDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ImageUrls = table.Column<List<string>>(type: "text[]", nullable: false),
                    ThumbnailUrls = table.Column<List<string>>(type: "text[]", nullable: false),
                    Price = table.Column<double>(type: "double precision", nullable: false),
                    City = table.Column<string>(type: "text", nullable: false),
                    IsMonitored = table.Column<bool>(type: "boolean", nullable: false),
                    FinalPrice = table.Column<double>(type: "double precision", nullable: true),
                    YearPublished = table.Column<int>(type: "integer", nullable: true),
                    Tags = table.Column<List<string>>(type: "text[]", nullable: false),
                    CategoryId = table.Column<int>(type: "integer", nullable: false),
                    PicsRatio = table.Column<float[]>(type: "real[]", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    StartPrice = table.Column<int>(type: "integer", nullable: false),
                    Type = table.Column<string>(type: "text", nullable: false),
                    SoldQuantity = table.Column<int>(type: "integer", nullable: false),
                    BidsCount = table.Column<int>(type: "integer", nullable: false),
                    SellerName = table.Column<string>(type: "text", nullable: false),
                    PicsCount = table.Column<int>(type: "integer", nullable: false),
                    IsImagesCompressed = table.Column<bool>(type: "boolean", nullable: false),
                    ImageArchiveUrl = table.Column<string>(type: "text", nullable: true),
                    IsLessValuable = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RegularBaseBook", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RegularBaseBook_RegularBaseCategory_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "RegularBaseCategory",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserCollectionBooks",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserId = table.Column<string>(type: "text", nullable: false),
                    Title = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    Author = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    YearPublished = table.Column<int>(type: "integer", nullable: true),
                    Description = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    Notes = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    EstimatedPrice = table.Column<decimal>(type: "numeric(18,2)", nullable: true),
                    IsManuallyPriced = table.Column<bool>(type: "boolean", nullable: false),
                    ReferenceBookId = table.Column<int>(type: "integer", nullable: true),
                    AddedDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserCollectionBooks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserCollectionBooks_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserCollectionBooks_RegularBaseBook_ReferenceBookId",
                        column: x => x.ReferenceBookId,
                        principalTable: "RegularBaseBook",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "UserCollectionBookImages",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserCollectionBookId = table.Column<int>(type: "integer", nullable: false),
                    FileName = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    FilePath = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    UploadedDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IsMainImage = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserCollectionBookImages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserCollectionBookImages_UserCollectionBooks_UserCollection~",
                        column: x => x.UserCollectionBookId,
                        principalTable: "UserCollectionBooks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserCollectionBookMatches",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserCollectionBookId = table.Column<int>(type: "integer", nullable: false),
                    MatchedBookId = table.Column<int>(type: "integer", nullable: false),
                    MatchScore = table.Column<double>(type: "double precision", nullable: false),
                    FoundDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IsSelected = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserCollectionBookMatches", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserCollectionBookMatches_RegularBaseBook_MatchedBookId",
                        column: x => x.MatchedBookId,
                        principalTable: "RegularBaseBook",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserCollectionBookMatches_UserCollectionBooks_UserCollectio~",
                        column: x => x.UserCollectionBookId,
                        principalTable: "UserCollectionBooks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RegularBaseBook_CategoryId",
                table: "RegularBaseBook",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_UserCollectionBookImages_UserCollectionBookId",
                table: "UserCollectionBookImages",
                column: "UserCollectionBookId");

            migrationBuilder.CreateIndex(
                name: "IX_UserCollectionBookMatches_MatchedBookId",
                table: "UserCollectionBookMatches",
                column: "MatchedBookId");

            migrationBuilder.CreateIndex(
                name: "IX_UserCollectionBookMatches_UserCollectionBookId",
                table: "UserCollectionBookMatches",
                column: "UserCollectionBookId");

            migrationBuilder.CreateIndex(
                name: "IX_UserCollectionBookMatches_UserCollectionBookId_MatchedBookId",
                table: "UserCollectionBookMatches",
                columns: new[] { "UserCollectionBookId", "MatchedBookId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserCollectionBooks_AddedDate",
                table: "UserCollectionBooks",
                column: "AddedDate");

            migrationBuilder.CreateIndex(
                name: "IX_UserCollectionBooks_ReferenceBookId",
                table: "UserCollectionBooks",
                column: "ReferenceBookId");

            migrationBuilder.CreateIndex(
                name: "IX_UserCollectionBooks_UserId",
                table: "UserCollectionBooks",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserCollectionBookImages");

            migrationBuilder.DropTable(
                name: "UserCollectionBookMatches");

            migrationBuilder.DropTable(
                name: "UserCollectionBooks");

            migrationBuilder.DropTable(
                name: "RegularBaseBook");

            migrationBuilder.DropTable(
                name: "RegularBaseCategory");

            migrationBuilder.DropColumn(
                name: "HasCollectionAccess",
                table: "SubscriptionPlans");
        }
    }
}
