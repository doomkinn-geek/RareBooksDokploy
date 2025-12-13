-- Migration script to update audio file paths from /uploads/audio/ to /audio/
-- This fixes 404 errors for audio messages created before the path refactoring

-- Show affected messages
SELECT 
    "Id",
    "ChatId",
    "FilePath",
    "CreatedAt"
FROM "Messages"
WHERE "FilePath" LIKE '/uploads/audio/%';

-- Update the paths
UPDATE "Messages"
SET "FilePath" = REPLACE("FilePath", '/uploads/audio/', '/audio/')
WHERE "FilePath" LIKE '/uploads/audio/%';

-- Verify the update
SELECT 
    "Id",
    "ChatId",
    "FilePath",
    "CreatedAt"
FROM "Messages"
WHERE "FilePath" LIKE '/audio/%'
ORDER BY "CreatedAt" DESC;

