-- Fix: Remove SECURITY DEFINER from views if accidentally set
-- https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view

-- Recreate messages_with_person_info WITHOUT security definer
DROP VIEW IF EXISTS messages_with_person_info;

CREATE VIEW messages_with_person_info
WITH (security_invoker = true) AS
SELECT
  m.*,
  CASE
    WHEN m.person_id IS NOT NULL THEN p.name
    WHEN m.topic_id IS NOT NULL THEN t.title
    ELSE 'Unknown'
  END as person_name,
  CASE
    WHEN m.person_id IS NOT NULL THEN p.role
    WHEN m.topic_id IS NOT NULL AND t.title = 'General' THEN 'Management Coaching'
    WHEN m.topic_id IS NOT NULL THEN 'Topic Discussion'
    ELSE 'Unknown'
  END as person_role,
  CASE
    WHEN m.person_id IS NOT NULL THEN p.relationship_type
    WHEN m.topic_id IS NOT NULL AND t.title = 'General' THEN 'assistant'
    WHEN m.topic_id IS NOT NULL THEN 'topic'
    ELSE 'unknown'
  END as relationship_type,
  CASE
    WHEN m.person_id IS NOT NULL THEN 'person'
    WHEN m.topic_id IS NOT NULL THEN 'topic'
    ELSE 'unknown'
  END as message_type
FROM messages m
LEFT JOIN people p ON (m.person_id IS NOT NULL AND p.id::text = m.person_id)
LEFT JOIN topics t ON (m.topic_id IS NOT NULL AND t.id = m.topic_id);

-- Grant access to the view
GRANT SELECT ON messages_with_person_info TO authenticated;

-- Enable security barrier (different from security definer - this is safe)
ALTER VIEW messages_with_person_info SET (security_barrier = true);

-- Recreate people_profile_analytics WITHOUT security definer
DROP VIEW IF EXISTS people_profile_analytics;

CREATE VIEW people_profile_analytics
WITH (security_invoker = true) AS
SELECT
  user_id,
  COUNT(*) as total_people,
  ROUND(AVG(profile_completion_score), 2) as avg_completion_score,
  COUNT(CASE WHEN profile_completion_score >= 80 THEN 1 END) as complete_profiles,
  COUNT(CASE WHEN profile_completion_score < 50 THEN 1 END) as incomplete_profiles,
  COUNT(CASE WHEN last_profile_prompt IS NOT NULL THEN 1 END) as profiles_prompted
FROM people
GROUP BY user_id;

-- Grant access to the view
GRANT SELECT ON people_profile_analytics TO authenticated;

-- Enable security barrier (safe)
ALTER VIEW people_profile_analytics SET (security_barrier = true);

-- Add comment explaining the fix
COMMENT ON VIEW messages_with_person_info IS 'View with SECURITY INVOKER to respect RLS policies of querying user';
COMMENT ON VIEW people_profile_analytics IS 'View with SECURITY INVOKER to respect RLS policies of querying user';
