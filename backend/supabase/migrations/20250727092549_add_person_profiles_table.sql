-- Create person_profiles table for Phase 1a: Foundation
-- This table stores user-editable profile content for each person
-- Starting simple with just content field, will add more in later phases

CREATE TABLE IF NOT EXISTS person_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id uuid REFERENCES people(id) ON DELETE CASCADE,
  content text NOT NULL DEFAULT '',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(person_id)
);

-- Create index for fast lookups by person_id
CREATE INDEX idx_person_profiles_person_id ON person_profiles(person_id);

-- Add RLS policies
ALTER TABLE person_profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own person profiles
CREATE POLICY "Users can view their own person profiles" ON person_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM people 
      WHERE people.id = person_profiles.person_id 
      AND people.user_id = auth.uid()
    )
  );

-- Policy: Users can insert profiles for their own people
CREATE POLICY "Users can insert profiles for their own people" ON person_profiles
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM people 
      WHERE people.id = person_profiles.person_id 
      AND people.user_id = auth.uid()
    )
  );

-- Policy: Users can update profiles for their own people
CREATE POLICY "Users can update profiles for their own people" ON person_profiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM people 
      WHERE people.id = person_profiles.person_id 
      AND people.user_id = auth.uid()
    )
  );

-- Policy: Users can delete profiles for their own people
CREATE POLICY "Users can delete profiles for their own people" ON person_profiles
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM people 
      WHERE people.id = person_profiles.person_id 
      AND people.user_id = auth.uid()
    )
  );

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_person_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function before updates
CREATE TRIGGER update_person_profiles_updated_at_trigger
  BEFORE UPDATE ON person_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_person_profiles_updated_at();