-- Create action_items table for managing tasks associated with people
CREATE TABLE action_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  is_hidden BOOLEAN NOT NULL DEFAULT false,
  position_in_profile TEXT, -- Store editor position context for syncing
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE,
  hidden_at TIMESTAMP WITH TIME ZONE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Add indexes for efficient querying
CREATE INDEX idx_action_items_person_id ON action_items(person_id);
CREATE INDEX idx_action_items_created_by ON action_items(created_by);
CREATE INDEX idx_action_items_completed ON action_items(is_completed, is_hidden);
CREATE INDEX idx_action_items_created_at ON action_items(created_at DESC);

-- Add RLS (Row Level Security) policy
ALTER TABLE action_items ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own action items
CREATE POLICY "Users can view their own action items"
  ON action_items FOR SELECT
  USING (created_by = auth.uid());

-- Policy: Users can create action items
CREATE POLICY "Users can create action items"
  ON action_items FOR INSERT
  WITH CHECK (created_by = auth.uid());

-- Policy: Users can update their own action items
CREATE POLICY "Users can update their own action items"
  ON action_items FOR UPDATE
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Policy: Users can delete their own action items
CREATE POLICY "Users can delete their own action items"
  ON action_items FOR DELETE
  USING (created_by = auth.uid());