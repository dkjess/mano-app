-- Fix: Handle NULL conversation_id in message trigger
-- The trigger was trying to update conversations table even when conversation_id is NULL
-- This caused "relation conversations does not exist" errors in production

CREATE OR REPLACE FUNCTION update_conversation_on_message()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update conversation if conversation_id is not NULL
    IF NEW.conversation_id IS NOT NULL THEN
        UPDATE conversations
        SET updated_at = TIMEZONE('utc'::text, NOW())
        WHERE id = NEW.conversation_id;
    END IF;

    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add comment explaining the fix
COMMENT ON FUNCTION update_conversation_on_message() IS 'Updates conversation timestamp when messages are added. Handles NULL conversation_id for legacy messages.';
