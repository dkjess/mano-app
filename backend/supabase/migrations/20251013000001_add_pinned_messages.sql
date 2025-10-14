-- Add pinned messages feature
-- Allows users to pin important coaching advice for later reference

-- Create pinned_messages table
CREATE TABLE IF NOT EXISTS public.pinned_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    person_id UUID REFERENCES public.people(id) ON DELETE CASCADE,
    topic_id UUID REFERENCES public.topics(id) ON DELETE SET NULL,
    note TEXT, -- Optional user note about why they pinned it
    pinned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensure a user can only pin the same message once
    UNIQUE(user_id, message_id)
);

-- Add indexes for fast querying
CREATE INDEX idx_pinned_messages_user_id ON public.pinned_messages(user_id);
CREATE INDEX idx_pinned_messages_person_id ON public.pinned_messages(person_id);
CREATE INDEX idx_pinned_messages_pinned_at ON public.pinned_messages(pinned_at DESC);

-- Enable RLS
ALTER TABLE public.pinned_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only see their own pinned messages
CREATE POLICY "Users can view their own pinned messages"
    ON public.pinned_messages
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own pinned messages"
    ON public.pinned_messages
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own pinned messages"
    ON public.pinned_messages
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own pinned messages"
    ON public.pinned_messages
    FOR DELETE
    USING (auth.uid() = user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_pinned_messages_updated_at
    BEFORE UPDATE ON public.pinned_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comment for documentation
COMMENT ON TABLE public.pinned_messages IS 'Stores pinned messages that users want to save for later reference';
COMMENT ON COLUMN public.pinned_messages.note IS 'Optional user note explaining why they pinned this message';
COMMENT ON COLUMN public.pinned_messages.pinned_at IS 'When the message was pinned (for sorting)';
