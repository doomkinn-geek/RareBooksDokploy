using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace RareBooksService.Data.Migrations.UsersDb
{
    /// <inheritdoc />
    public partial class RemoveRegularBaseBookTablesFromUsersDb : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_UserCollectionBookMatches_RegularBaseBook_MatchedBookId",
                table: "UserCollectionBookMatches");

            migrationBuilder.DropForeignKey(
                name: "FK_UserCollectionBooks_RegularBaseBook_ReferenceBookId",
                table: "UserCollectionBooks");

            migrationBuilder.DropTable(
                name: "RegularBaseBook");

            migrationBuilder.DropTable(
                name: "RegularBaseCategory");

            migrationBuilder.DropIndex(
                name: "IX_UserCollectionBooks_ReferenceBookId",
                table: "UserCollectionBooks");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
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
                    CategoryId = table.Column<int>(type: "integer", nullable: false),
                    BeginDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    BidsCount = table.Column<int>(type: "integer", nullable: false),
                    City = table.Column<string>(type: "text", nullable: false),
                    Description = table.Column<string>(type: "text", nullable: false),
                    EndDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    FinalPrice = table.Column<double>(type: "double precision", nullable: true),
                    ImageArchiveUrl = table.Column<string>(type: "text", nullable: true),
                    ImageUrls = table.Column<List<string>>(type: "text[]", nullable: false),
                    IsImagesCompressed = table.Column<bool>(type: "boolean", nullable: false),
                    IsLessValuable = table.Column<bool>(type: "boolean", nullable: false),
                    IsMonitored = table.Column<bool>(type: "boolean", nullable: false),
                    NormalizedDescription = table.Column<string>(type: "text", nullable: false),
                    NormalizedTitle = table.Column<string>(type: "text", nullable: false),
                    PicsCount = table.Column<int>(type: "integer", nullable: false),
                    PicsRatio = table.Column<float[]>(type: "real[]", nullable: false),
                    Price = table.Column<double>(type: "double precision", nullable: false),
                    SellerName = table.Column<string>(type: "text", nullable: false),
                    SoldQuantity = table.Column<int>(type: "integer", nullable: false),
                    StartPrice = table.Column<int>(type: "integer", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    Tags = table.Column<List<string>>(type: "text[]", nullable: false),
                    ThumbnailUrls = table.Column<List<string>>(type: "text[]", nullable: false),
                    Title = table.Column<string>(type: "text", nullable: false),
                    Type = table.Column<string>(type: "text", nullable: false),
                    YearPublished = table.Column<int>(type: "integer", nullable: true)
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

            migrationBuilder.CreateIndex(
                name: "IX_UserCollectionBooks_ReferenceBookId",
                table: "UserCollectionBooks",
                column: "ReferenceBookId");

            migrationBuilder.CreateIndex(
                name: "IX_RegularBaseBook_CategoryId",
                table: "RegularBaseBook",
                column: "CategoryId");

            migrationBuilder.AddForeignKey(
                name: "FK_UserCollectionBookMatches_RegularBaseBook_MatchedBookId",
                table: "UserCollectionBookMatches",
                column: "MatchedBookId",
                principalTable: "RegularBaseBook",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserCollectionBooks_RegularBaseBook_ReferenceBookId",
                table: "UserCollectionBooks",
                column: "ReferenceBookId",
                principalTable: "RegularBaseBook",
                principalColumn: "Id");
        }
    }
}
