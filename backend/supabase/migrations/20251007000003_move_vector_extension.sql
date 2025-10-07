-- Fix: Move vector extension from public schema to extensions schema
-- https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public

-- Create extensions schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS extensions;

-- Drop the extension from public (will be recreated in extensions)
DROP EXTENSION IF EXISTS vector CASCADE;

-- Create vector extension in extensions schema
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- Grant usage on extensions schema to relevant roles
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- Add comment
COMMENT ON EXTENSION vector IS 'Vector extension moved to extensions schema for security best practices';
