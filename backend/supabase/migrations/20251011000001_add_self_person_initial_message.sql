-- Add initial welcome message when self-person is created
-- This extends the handle_new_user trigger to create a welcome message

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  user_display_name TEXT;
  new_person_id UUID;
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
    VALUES (NEW.id, user_display_name, 'self', true)
    RETURNING id INTO new_person_id;

    -- Create initial welcome message for self-person
    INSERT INTO public.messages (
      user_id,
      person_id,
      content,
      is_user,
      created_at
    )
    VALUES (
      NEW.id,
      new_person_id,
      'Welcome! I''m here to help you reflect on your work, grow as a manager, and think through the challenges you''re facing. What''s on your mind right now?',
      false,
      NOW()
    );

    RETURN NEW;
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail user creation
    RAISE WARNING 'Failed to create user profile or self-person for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
  END;
END;
$$;

COMMENT ON FUNCTION handle_new_user IS 'User creation trigger with self-person and initial message';
