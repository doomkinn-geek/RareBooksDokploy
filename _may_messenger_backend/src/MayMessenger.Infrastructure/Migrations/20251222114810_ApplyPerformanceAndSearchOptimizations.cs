using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MayMessenger.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class ApplyPerformanceAndSearchOptimizations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Add full-text search support for Messages.Content
            // Using PostgreSQL GIN index with Russian language support
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS ""IX_Messages_Content_FullText"" 
                ON ""Messages"" 
                USING GIN (to_tsvector('russian', COALESCE(""Content"", '')));
            ");
            
            // Add index on UpdatedAt for incremental sync queries
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS ""IX_Messages_UpdatedAt"" 
                ON ""Messages"" (""UpdatedAt"") 
                WHERE ""UpdatedAt"" IS NOT NULL;
            ");
            
            // Composite index for efficient chat message queries with pagination
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS ""IX_Messages_ChatId_CreatedAt_Desc"" 
                ON ""Messages"" (""ChatId"", ""CreatedAt"" DESC);
            ");
            
            // Index for status event queries
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS ""IX_MessageStatusEvents_MessageId_Timestamp"" 
                ON ""MessageStatusEvents"" (""MessageId"", ""Timestamp"");
            ");
            
            // Index for user presence queries
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS ""IX_Users_IsOnline_LastHeartbeatAt"" 
                ON ""Users"" (""IsOnline"", ""LastHeartbeatAt"") 
                WHERE ""IsOnline"" = true;
            ");
            
            // Add trigger for automatic UpdatedAt timestamp
            migrationBuilder.Sql(@"
                CREATE OR REPLACE FUNCTION update_updated_at_column()
                RETURNS TRIGGER AS $$
                BEGIN
                    NEW.""UpdatedAt"" = NOW();
                    RETURN NEW;
                END;
                $$ language 'plpgsql';
            ");
            
            migrationBuilder.Sql(@"
                DROP TRIGGER IF EXISTS update_messages_updated_at ON ""Messages"";
            ");
            
            migrationBuilder.Sql(@"
                CREATE TRIGGER update_messages_updated_at 
                BEFORE UPDATE ON ""Messages""
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            ");
            
            // Add comments for documentation
            migrationBuilder.Sql(@"
                COMMENT ON INDEX ""IX_Messages_Content_FullText"" IS 'Full-text search index for message content with Russian language support';
            ");
            
            migrationBuilder.Sql(@"
                COMMENT ON INDEX ""IX_Messages_UpdatedAt"" IS 'Index for incremental sync queries';
            ");
            
            migrationBuilder.Sql(@"
                COMMENT ON INDEX ""IX_Users_IsOnline_LastHeartbeatAt"" IS 'Index for presence monitoring queries';
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Remove trigger
            migrationBuilder.Sql(@"DROP TRIGGER IF EXISTS update_messages_updated_at ON ""Messages"";");
            migrationBuilder.Sql(@"DROP FUNCTION IF EXISTS update_updated_at_column();");
            
            // Remove indexes
            migrationBuilder.Sql(@"DROP INDEX IF EXISTS ""IX_Messages_Content_FullText"";");
            migrationBuilder.Sql(@"DROP INDEX IF EXISTS ""IX_Messages_UpdatedAt"";");
            migrationBuilder.Sql(@"DROP INDEX IF EXISTS ""IX_Messages_ChatId_CreatedAt_Desc"";");
            migrationBuilder.Sql(@"DROP INDEX IF EXISTS ""IX_MessageStatusEvents_MessageId_Timestamp"";");
            migrationBuilder.Sql(@"DROP INDEX IF EXISTS ""IX_Users_IsOnline_LastHeartbeatAt"";");
        }
    }
}
