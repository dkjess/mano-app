-- Create conversations table
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    title TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Add indexes for performance
CREATE INDEX conversations_person_id_idx ON conversations(person_id);
CREATE INDEX conversations_person_active_idx ON conversations(person_id, is_active);
CREATE INDEX conversations_created_at_idx ON conversations(created_at);

-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own conversations" ON conversations
    FOR SELECT USING (person_id IN (
        SELECT id FROM people WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can create conversations for their people" ON conversations
    FOR INSERT WITH CHECK (person_id IN (
        SELECT id FROM people WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can update their own conversations" ON conversations
    FOR UPDATE USING (person_id IN (
        SELECT id FROM people WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can delete their own conversations" ON conversations
    FOR DELETE USING (person_id IN (
        SELECT id FROM people WHERE user_id = auth.uid()
    ));

-- Add trigger to update updated_at
CREATE OR REPLACE FUNCTION update_conversations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER conversations_updated_at_trigger
    BEFORE UPDATE ON conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_conversations_updated_at();