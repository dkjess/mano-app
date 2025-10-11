-- Fix: Add search_path to all functions to prevent search path hijacking attacks
-- https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable

-- 1. update_conversations_updated_at
CREATE OR REPLACE FUNCTION update_conversations_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$;

-- 2. match_conversation_embeddings (with topic_filter - latest version)
CREATE OR REPLACE FUNCTION match_conversation_embeddings(
  query_embedding vector(1536),
  match_user_id uuid,
  match_threshold float DEFAULT 0.78,
  match_count int DEFAULT 10,
  person_filter text DEFAULT NULL,
  topic_filter text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  content text,
  person_id text,
  message_type text,
  created_at timestamp with time zone,
  similarity float,
  metadata jsonb
)
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    conversation_embeddings.id,
    conversation_embeddings.content,
    conversation_embeddings.person_id,
    conversation_embeddings.message_type,
    conversation_embeddings.created_at,
    1 - (conversation_embeddings.embedding <=> query_embedding) AS similarity,
    conversation_embeddings.metadata
  FROM conversation_embeddings
  WHERE conversation_embeddings.user_id = match_user_id
    AND (person_filter IS NULL OR conversation_embeddings.person_id = person_filter)
    AND (topic_filter IS NULL OR conversation_embeddings.topic_id::text = topic_filter)
    AND 1 - (conversation_embeddings.embedding <=> query_embedding) > match_threshold
  ORDER BY conversation_embeddings.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 3. match_conversation_summaries
CREATE OR REPLACE FUNCTION match_conversation_summaries(
  query_embedding vector(1536),
  match_user_id uuid,
  match_threshold float DEFAULT 0.75,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  id uuid,
  summary_content text,
  person_id text,
  summary_type text,
  time_range_start timestamp with time zone,
  time_range_end timestamp with time zone,
  similarity float,
  metadata jsonb
)
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    conversation_summary_embeddings.id,
    conversation_summary_embeddings.summary_content,
    conversation_summary_embeddings.person_id,
    conversation_summary_embeddings.summary_type,
    conversation_summary_embeddings.time_range_start,
    conversation_summary_embeddings.time_range_end,
    1 - (conversation_summary_embeddings.embedding <=> query_embedding) AS similarity,
    conversation_summary_embeddings.metadata
  FROM conversation_summary_embeddings
  WHERE conversation_summary_embeddings.user_id = match_user_id
    AND 1 - (conversation_summary_embeddings.embedding <=> query_embedding) > match_threshold
  ORDER BY conversation_summary_embeddings.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 4. update_updated_at_column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 5. update_conversation_on_message
CREATE OR REPLACE FUNCTION update_conversation_on_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    -- Update the conversation's updated_at timestamp
    UPDATE conversations
    SET updated_at = TIMEZONE('utc'::text, NOW())
    WHERE id = NEW.conversation_id;

    RETURN NEW;
END;
$$;

-- 6. calculate_profile_completion_score
CREATE OR REPLACE FUNCTION calculate_profile_completion_score(person_record people)
RETURNS INTEGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  total_possible INTEGER := 100;
  current_score INTEGER := 0;
BEGIN
  -- Role (20 points)
  IF person_record.role IS NOT NULL AND trim(person_record.role) != '' THEN
    current_score := current_score + 20;
  END IF;

  -- Notes (15 points)
  IF person_record.notes IS NOT NULL AND trim(person_record.notes) != '' THEN
    current_score := current_score + 15;
  END IF;

  -- Team (10 points)
  IF person_record.team IS NOT NULL AND trim(person_record.team) != '' THEN
    current_score := current_score + 10;
  END IF;

  -- Communication style (10 points)
  IF person_record.communication_style IS NOT NULL AND trim(person_record.communication_style) != '' THEN
    current_score := current_score + 10;
  END IF;

  -- Goals (10 points)
  IF person_record.goals IS NOT NULL AND trim(person_record.goals) != '' THEN
    current_score := current_score + 10;
  END IF;

  -- Strengths (10 points)
  IF person_record.strengths IS NOT NULL AND trim(person_record.strengths) != '' THEN
    current_score := current_score + 10;
  END IF;

  -- Challenges (10 points)
  IF person_record.challenges IS NOT NULL AND trim(person_record.challenges) != '' THEN
    current_score := current_score + 10;
  END IF;

  -- Emoji (5 points)
  IF person_record.emoji IS NOT NULL AND trim(person_record.emoji) != '' THEN
    current_score := current_score + 5;
  END IF;

  -- Location (5 points)
  IF person_record.location IS NOT NULL AND trim(person_record.location) != '' THEN
    current_score := current_score + 5;
  END IF;

  -- Start date (5 points)
  IF person_record.start_date IS NOT NULL THEN
    current_score := current_score + 5;
  END IF;

  RETURN current_score;
END;
$$;

-- 7. update_profile_completion_score
CREATE OR REPLACE FUNCTION update_profile_completion_score()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.profile_completion_score := calculate_profile_completion_score(NEW);
  RETURN NEW;
END;
$$;

-- 8. validate_message_ownership (latest version with topic support)
CREATE OR REPLACE FUNCTION validate_message_ownership(p_person_id text, p_topic_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- For person-specific messages, verify ownership
  IF p_person_id IS NOT NULL AND p_topic_id IS NULL THEN
    RETURN EXISTS (
      SELECT 1 FROM people
      WHERE people.id::text = p_person_id
      AND people.user_id = p_user_id
    );
  END IF;

  -- For topic messages, verify ownership
  IF p_topic_id IS NOT NULL AND p_person_id IS NULL THEN
    RETURN EXISTS (
      SELECT 1 FROM topics
      WHERE topics.id = p_topic_id
      AND topics.created_by = p_user_id
    );
  END IF;

  -- Invalid state: both or neither are set
  RETURN FALSE;
END;
$$;

-- 9. update_message_file_count
CREATE OR REPLACE FUNCTION update_message_file_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE messages
    SET file_count = file_count + 1
    WHERE id = NEW.message_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE messages
    SET file_count = file_count - 1
    WHERE id = OLD.message_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

-- 10. cleanup_orphaned_files
CREATE OR REPLACE FUNCTION cleanup_orphaned_files()
RETURNS INTEGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM message_files
  WHERE message_id NOT IN (SELECT id FROM messages);

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

-- 11. match_file_content_embeddings
CREATE OR REPLACE FUNCTION match_file_content_embeddings(
  query_embedding vector(1536),
  match_user_id uuid,
  match_threshold float DEFAULT 0.78,
  match_count int DEFAULT 10,
  file_filter uuid DEFAULT NULL,
  person_filter uuid DEFAULT NULL,
  topic_filter uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  content text,
  person_id uuid,
  topic_id uuid,
  message_id uuid,
  file_id uuid,
  message_type text,
  created_at timestamptz,
  similarity float,
  metadata jsonb,
  content_type text,
  chunk_index int
)
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    conversation_embeddings.id,
    conversation_embeddings.content,
    conversation_embeddings.person_id,
    conversation_embeddings.topic_id,
    conversation_embeddings.message_id,
    conversation_embeddings.file_id,
    conversation_embeddings.message_type,
    conversation_embeddings.created_at,
    (conversation_embeddings.embedding <#> query_embedding) * -1 AS similarity,
    conversation_embeddings.metadata,
    conversation_embeddings.content_type,
    conversation_embeddings.chunk_index
  FROM conversation_embeddings
  WHERE conversation_embeddings.user_id = match_user_id
    AND conversation_embeddings.content_type IN ('file_content', 'file_chunk')
    AND (conversation_embeddings.embedding <#> query_embedding) * -1 > match_threshold
    AND (file_filter IS NULL OR conversation_embeddings.file_id = file_filter)
    AND (person_filter IS NULL OR conversation_embeddings.person_id = person_filter)
    AND (topic_filter IS NULL OR conversation_embeddings.topic_id = topic_filter)
  ORDER BY conversation_embeddings.embedding <#> query_embedding
  LIMIT match_count;
END;
$$;

-- 12. update_person_profiles_updated_at
CREATE OR REPLACE FUNCTION update_person_profiles_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 13. handle_new_user
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- Add comments
COMMENT ON FUNCTION update_conversations_updated_at IS 'Trigger function with secure search_path';
COMMENT ON FUNCTION match_conversation_embeddings(vector(1536), uuid, float, int, text, text) IS 'Vector search with secure search_path';
COMMENT ON FUNCTION match_conversation_summaries(vector(1536), uuid, float, int) IS 'Summary search with secure search_path';
COMMENT ON FUNCTION update_updated_at_column IS 'Generic timestamp trigger with secure search_path';
COMMENT ON FUNCTION update_conversation_on_message IS 'Conversation timestamp trigger with secure search_path';
COMMENT ON FUNCTION calculate_profile_completion_score(people) IS 'Profile scoring with secure search_path';
COMMENT ON FUNCTION update_profile_completion_score IS 'Profile score trigger with secure search_path';
COMMENT ON FUNCTION validate_message_ownership(text, uuid, uuid) IS 'Security definer function with secure search_path';
COMMENT ON FUNCTION update_message_file_count IS 'File count trigger with secure search_path';
COMMENT ON FUNCTION cleanup_orphaned_files IS 'Cleanup function with secure search_path';
COMMENT ON FUNCTION match_file_content_embeddings(vector(1536), uuid, float, int, uuid, uuid, uuid) IS 'File content search with secure search_path';
COMMENT ON FUNCTION update_person_profiles_updated_at IS 'Person profile timestamp trigger with secure search_path';
COMMENT ON FUNCTION handle_new_user IS 'User creation trigger with secure search_path';
