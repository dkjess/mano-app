-- Add title field to pinned_messages for AI-generated summaries
-- The title is generated asynchronously after pinning for fast UX

ALTER TABLE public.pinned_messages
ADD COLUMN title TEXT;

-- Add index for title searches (if we want to search by title later)
CREATE INDEX idx_pinned_messages_title ON public.pinned_messages(title);

-- Add comment for documentation
COMMENT ON COLUMN public.pinned_messages.title IS 'AI-generated title summarizing the pinned advice. Generated asynchronously after pinning.';
