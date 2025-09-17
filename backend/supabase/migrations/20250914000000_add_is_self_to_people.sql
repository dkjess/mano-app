-- Add is_self column to people table to identify the user's self-person
ALTER TABLE people ADD COLUMN is_self boolean DEFAULT false NOT NULL;

-- Add a unique constraint to ensure only one self-person per user
CREATE UNIQUE INDEX unique_self_person_per_user ON people (user_id) WHERE is_self = true;

-- Add a comment to document this field
COMMENT ON COLUMN people.is_self IS 'Identifies the person record that represents the user themselves for self-reflection conversations';