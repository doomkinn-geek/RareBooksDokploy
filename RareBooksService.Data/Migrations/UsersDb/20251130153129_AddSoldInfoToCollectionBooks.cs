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
            // Безопасное обновление PurchasePrice на numeric(18,2)
            migrationBuilder.Sql(@"
                DO $$ 
                BEGIN
                    -- Изменяем тип PurchasePrice если нужно
                    IF EXISTS (
                        SELECT 1 
                        FROM information_schema.columns 
                        WHERE table_name = 'UserCollectionBooks' 
                        AND column_name = 'PurchasePrice'
                        AND (numeric_precision IS NULL OR numeric_precision != 18 OR numeric_scale != 2)
                    ) THEN
                        ALTER TABLE ""UserCollectionBooks"" 
                        ALTER COLUMN ""PurchasePrice"" TYPE numeric(18,2);
                    END IF;
                END $$;
            ");

            // Добавляем IsSold если не существует
            migrationBuilder.Sql(@"
                DO $$ 
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1 
                        FROM information_schema.columns 
                        WHERE table_name = 'UserCollectionBooks' 
                        AND column_name = 'IsSold'
                    ) THEN
                        ALTER TABLE ""UserCollectionBooks"" 
                        ADD COLUMN ""IsSold"" boolean NOT NULL DEFAULT false;
                    END IF;
                END $$;
            ");

            // Добавляем SoldDate если не существует
            migrationBuilder.Sql(@"
                DO $$ 
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1 
                        FROM information_schema.columns 
                        WHERE table_name = 'UserCollectionBooks' 
                        AND column_name = 'SoldDate'
                    ) THEN
                        ALTER TABLE ""UserCollectionBooks"" 
                        ADD COLUMN ""SoldDate"" timestamp with time zone NULL;
                    END IF;
                END $$;
            ");

            // Добавляем SoldPrice если не существует
            migrationBuilder.Sql(@"
                DO $$ 
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1 
                        FROM information_schema.columns 
                        WHERE table_name = 'UserCollectionBooks' 
                        AND column_name = 'SoldPrice'
                    ) THEN
                        ALTER TABLE ""UserCollectionBooks"" 
                        ADD COLUMN ""SoldPrice"" numeric(18,2) NULL;
                    ELSE
                        -- Обновляем тип если колонка существует но тип неправильный
                        IF EXISTS (
                            SELECT 1 
                            FROM information_schema.columns 
                            WHERE table_name = 'UserCollectionBooks' 
                            AND column_name = 'SoldPrice'
                            AND (numeric_precision IS NULL OR numeric_precision != 18 OR numeric_scale != 2)
                        ) THEN
                            ALTER TABLE ""UserCollectionBooks"" 
                            ALTER COLUMN ""SoldPrice"" TYPE numeric(18,2);
                        END IF;
                    END IF;
                END $$;
            ");
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
