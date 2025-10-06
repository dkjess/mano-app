-- Fix profile completion trigger to work with user creation trigger
-- The issue is that when handle_new_user() inserts into people,
-- the profile completion trigger fires but can't find the function

BEGIN;

-- Drop existing trigger
DROP TRIGGER IF EXISTS people_profile_completion_trigger ON people;

-- Recreate trigger function with explicit schema references
CREATE OR REPLACE FUNCTION update_profile_completion()
RETURNS TRIGGER AS $$
BEGIN
  -- Use explicit schema reference and handle missing function gracefully
  BEGIN
    NEW.profile_completion_score := public.calculate_profile_completion_score(NEW);
  EXCEPTION WHEN undefined_function THEN
    -- If function doesn't exist yet, set to default
    NEW.profile_completion_score := 0;
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Recreate trigger
CREATE TRIGGER people_profile_completion_trigger
  BEFORE INSERT OR UPDATE ON people
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_completion();

COMMIT;
