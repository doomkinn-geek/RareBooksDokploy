-- Add full-text search support for Messages.Content
-- Using PostgreSQL GIN index with Russian language support

-- Create GIN index for full-text search on Content field
-- Using Russian language configuration for proper word stemming
CREATE INDEX IF NOT EXISTS "IX_Messages_Content_FullText" 
ON "Messages" 
USING GIN (to_tsvector('russian', COALESCE("Content", '')));

-- Add index on UpdatedAt for incremental sync queries
CREATE INDEX IF NOT EXISTS "IX_Messages_UpdatedAt" 
ON "Messages" ("UpdatedAt") 
WHERE "UpdatedAt" IS NOT NULL;

-- Composite index for efficient chat message queries with pagination
CREATE INDEX IF NOT EXISTS "IX_Messages_ChatId_CreatedAt_Desc" 
ON "Messages" ("ChatId", "CreatedAt" DESC);

-- Index for status event queries
CREATE INDEX IF NOT EXISTS "IX_MessageStatusEvents_MessageId_Timestamp" 
ON "MessageStatusEvents" ("MessageId", "Timestamp");

-- Index for user presence queries
CREATE INDEX IF NOT EXISTS "IX_Users_IsOnline_LastHeartbeatAt" 
ON "Users" ("IsOnline", "LastHeartbeatAt") 
WHERE "IsOnline" = true;

-- Add trigger for automatic UpdatedAt timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW."UpdatedAt" = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_messages_updated_at ON "Messages";
CREATE TRIGGER update_messages_updated_at 
BEFORE UPDATE ON "Messages"
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON INDEX "IX_Messages_Content_FullText" IS 'Full-text search index for message content with Russian language support';
COMMENT ON INDEX "IX_Messages_UpdatedAt" IS 'Index for incremental sync queries';
COMMENT ON INDEX "IX_Users_IsOnline_LastHeartbeatAt" IS 'Index for presence monitoring queries';

