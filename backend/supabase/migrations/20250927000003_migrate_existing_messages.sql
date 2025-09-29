-- Migration script to create conversations for existing messages
-- This creates one conversation per person for all existing messages

DO $$
DECLARE
    person_record RECORD;
    conversation_uuid UUID;
    message_count INTEGER;
BEGIN
    -- For each person that has messages, create a conversation
    FOR person_record IN
        SELECT DISTINCT p.id, p.name
        FROM people p
        INNER JOIN messages m ON m.person_id = p.id::text
        WHERE p.id IS NOT NULL
    LOOP
        -- Count messages for this person to help with title generation
        SELECT COUNT(*) INTO message_count
        FROM messages
        WHERE person_id = person_record.id::text;

        -- Create a conversation for this person
        INSERT INTO conversations (person_id, title, is_active, created_at, updated_at)
        VALUES (
            person_record.id,
            'Conversation with ' || person_record.name,  -- Temporary title
            true,
            (SELECT MIN(created_at) FROM messages WHERE person_id = person_record.id::text),
            (SELECT MAX(created_at) FROM messages WHERE person_id = person_record.id::text)
        )
        RETURNING id INTO conversation_uuid;

        -- Update all messages for this person to reference the new conversation
        UPDATE messages
        SET conversation_id = conversation_uuid
        WHERE person_id = person_record.id::text;

        RAISE NOTICE 'Created conversation % for person % with % messages',
                     conversation_uuid, person_record.name, message_count;
    END LOOP;

    -- Handle any orphaned messages (messages without person_id)
    -- These shouldn't exist, but let's be safe
    UPDATE messages
    SET conversation_id = NULL
    WHERE person_id IS NULL;

END $$;