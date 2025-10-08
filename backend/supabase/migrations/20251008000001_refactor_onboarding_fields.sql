-- Refactor onboarding to support new personality profiling
-- Migration: 20251004000001_refactor_onboarding_fields.sql

BEGIN;

-- Add new onboarding fields to user_profiles
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS experience_level TEXT,
ADD COLUMN IF NOT EXISTS communication_style TEXT,
ADD COLUMN IF NOT EXISTS tone_preference TEXT;

-- Fix onboarding_step type inconsistency (should be INTEGER, not TEXT)
-- First, update any existing TEXT values to their INTEGER equivalents
UPDATE user_profiles
SET onboarding_step = 0
WHERE onboarding_step::text = 'welcome' OR onboarding_step IS NULL;

-- Ensure onboarding_step is INTEGER type
ALTER TABLE user_profiles
ALTER COLUMN onboarding_step TYPE INTEGER USING COALESCE(onboarding_step::INTEGER, 0);

-- Set default value for onboarding_step
ALTER TABLE user_profiles
ALTER COLUMN onboarding_step SET DEFAULT 0;

-- Add comments for new fields
COMMENT ON COLUMN user_profiles.experience_level IS 'Management experience: new, experienced, or veteran';
COMMENT ON COLUMN user_profiles.communication_style IS 'How user processes challenges: think_aloud, write_it_out, action_oriented, explore_options';
COMMENT ON COLUMN user_profiles.tone_preference IS 'Preferred tone for Mano: direct, warm, conversational, analytical, challenging';

-- Update handle_new_user function to use INTEGER for onboarding_step
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_display_name TEXT;
BEGIN
  BEGIN
    -- Create user profile with proper INTEGER onboarding_step
    INSERT INTO public.user_profiles (
      user_id,
      onboarding_completed,
      onboarding_step,
      debug_mode,
      preferred_name
    )
    VALUES (
      NEW.id,
      false,
      0, -- INTEGER instead of TEXT
      false,
      COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name',
        NULL
      )
    );

    -- Extract display name from user metadata or email
    user_display_name := COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name',
      split_part(NEW.email, '@', 1)
    );

    -- Create self-person for this user
    INSERT INTO public.people (user_id, name, relationship_type, is_self)
    VALUES (NEW.id, user_display_name, 'self', true);

    RETURN NEW;
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail user creation
    RAISE WARNING 'Failed to create user profile or self-person for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger to use updated function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

COMMIT;
