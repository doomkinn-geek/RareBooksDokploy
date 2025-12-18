-- Performance Optimization: Add Critical Database Indexes
-- Date: 2024-12-18
-- Description: Adds indexes to improve query performance for common operations

-- Index for getting messages by chat, ordered by creation time (most common query)
CREATE INDEX IF NOT EXISTS IX_Messages_ChatId_CreatedAt 
ON "Messages"("ChatId", "CreatedAt" DESC);

-- Index for finding messages by sender
CREATE INDEX IF NOT EXISTS IX_Messages_SenderId 
ON "Messages"("SenderId");

-- Index for delivery receipts lookup (message + user combination)
CREATE INDEX IF NOT EXISTS IX_DeliveryReceipts_MessageId_UserId 
ON "DeliveryReceipts"("MessageId", "UserId");

-- Partial index for active FCM tokens only (saves space and improves lookups)
CREATE INDEX IF NOT EXISTS IX_FcmTokens_UserId_IsActive 
ON "FcmTokens"("UserId", "IsActive") 
WHERE "IsActive" = true;

-- Index for FCM token cleanup (finding old tokens)
CREATE INDEX IF NOT EXISTS IX_FcmTokens_LastUsedAt 
ON "FcmTokens"("LastUsedAt") 
WHERE "IsActive" = true;

-- Index for chat participants lookup
CREATE INDEX IF NOT EXISTS IX_ChatParticipants_UserId 
ON "ChatParticipants"("UserId");

-- Index for chat participants by chat
CREATE INDEX IF NOT EXISTS IX_ChatParticipants_ChatId 
ON "ChatParticipants"("ChatId");

-- Index for contacts by user
CREATE INDEX IF NOT EXISTS IX_Contacts_UserId 
ON "Contacts"("UserId");

-- Index for invite links lookup
CREATE INDEX IF NOT EXISTS IX_InviteLinks_Code 
ON "InviteLinks"("Code") 
WHERE "IsActive" = true;

-- Index for invite links by creator
CREATE INDEX IF NOT EXISTS IX_InviteLinks_CreatedById 
ON "InviteLinks"("CreatedById");

-- Analyze tables to update statistics after adding indexes
ANALYZE "Messages";
ANALYZE "DeliveryReceipts";
ANALYZE "FcmTokens";
ANALYZE "ChatParticipants";
ANALYZE "Contacts";
ANALYZE "InviteLinks";

-- Display index information
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

