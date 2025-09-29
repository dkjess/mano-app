-- Add conversation_id to messages table
ALTER TABLE messages
ADD COLUMN conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE;

-- Add index for performance
CREATE INDEX messages_conversation_id_idx ON messages(conversation_id);

-- Create a trigger function to update conversation.updated_at when messages are added
CREATE OR REPLACE FUNCTION update_conversation_on_message()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the conversation's updated_at timestamp
    UPDATE conversations
    SET updated_at = TIMEZONE('utc'::text, NOW())
    WHERE id = NEW.conversation_id;

    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to update conversation timestamp on new messages
CREATE TRIGGER messages_update_conversation_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_on_message();