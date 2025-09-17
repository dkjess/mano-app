-- Update user creation trigger to also create a self-person
BEGIN;

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Recreate function to include self-person creation
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_display_name TEXT;
BEGIN
  BEGIN
    -- Create user profile
    INSERT INTO public.user_profiles (user_id, onboarding_completed, onboarding_step, debug_mode)
    VALUES (NEW.id, false, 'welcome', false);
    
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

-- Recreate trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT INSERT ON public.user_profiles TO authenticated;
GRANT INSERT ON public.people TO authenticated;

COMMIT;