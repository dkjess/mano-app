-- Fix topics table to cascade delete when user is deleted
-- This ensures that when a user account is deleted, their topics are also removed

ALTER TABLE topics
DROP CONSTRAINT IF EXISTS topics_created_by_fkey;

ALTER TABLE topics
ADD CONSTRAINT topics_created_by_fkey
FOREIGN KEY (created_by)
REFERENCES auth.users(id)
ON DELETE CASCADE;
