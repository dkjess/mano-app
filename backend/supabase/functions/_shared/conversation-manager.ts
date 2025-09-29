/**
 * Conversation Management Utilities
 * Handles creating, finding, and managing conversations for people
 */

export interface Conversation {
  id: string;
  person_id: string;
  title: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export class ConversationManager {
  constructor(private supabase: any, private userId: string) {}

  /**
   * Get or create an active conversation for a person
   * Returns the active conversation if it exists, otherwise creates a new one
   */
  async getOrCreateActiveConversation(personId: string): Promise<Conversation> {
    // First, try to find an active conversation
    const { data: existingConversation, error: findError } = await this.supabase
      .from('conversations')
      .select('*')
      .eq('person_id', personId)
      .eq('is_active', true)
      .order('updated_at', { ascending: false })
      .limit(1)
      .single();

    if (!findError && existingConversation) {
      console.log(`✅ Found active conversation ${existingConversation.id} for person ${personId}`);
      return existingConversation;
    }

    // No active conversation found, create a new one
    console.log(`🆕 Creating new conversation for person ${personId}`);

    const { data: newConversation, error: createError } = await this.supabase
      .from('conversations')
      .insert({
        person_id: personId,
        title: null, // Will be generated later
        is_active: true
      })
      .select()
      .single();

    if (createError) {
      console.error('❌ Error creating conversation:', createError);
      throw new Error(`Failed to create conversation: ${createError.message}`);
    }

    console.log(`✅ Created new conversation ${newConversation.id} for person ${personId}`);
    return newConversation;
  }

  /**
   * Get all conversations for a person, ordered by most recent
   */
  async getPersonConversations(personId: string): Promise<Conversation[]> {
    const { data: conversations, error } = await this.supabase
      .from('conversations')
      .select('*')
      .eq('person_id', personId)
      .order('updated_at', { ascending: false });

    if (error) {
      console.error('❌ Error fetching conversations:', error);
      throw new Error(`Failed to fetch conversations: ${error.message}`);
    }

    return conversations || [];
  }

  /**
   * Archive the current active conversation and create a new one
   */
  async archiveAndCreateNew(personId: string): Promise<Conversation> {
    // First, archive any active conversations
    const { error: archiveError } = await this.supabase
      .from('conversations')
      .update({ is_active: false })
      .eq('person_id', personId)
      .eq('is_active', true);

    if (archiveError) {
      console.error('❌ Error archiving conversations:', archiveError);
      throw new Error(`Failed to archive conversations: ${archiveError.message}`);
    }

    // Now create a new active conversation
    return await this.getOrCreateActiveConversation(personId);
  }

  /**
   * Update conversation title
   */
  async updateConversationTitle(conversationId: string, title: string): Promise<void> {
    const { error } = await this.supabase
      .from('conversations')
      .update({ title })
      .eq('id', conversationId);

    if (error) {
      console.error('❌ Error updating conversation title:', error);
      throw new Error(`Failed to update conversation title: ${error.message}`);
    }

    console.log(`✅ Updated conversation ${conversationId} title to: "${title}"`);
  }

  /**
   * Get message count for a conversation
   */
  async getConversationMessageCount(conversationId: string): Promise<number> {
    const { count, error } = await this.supabase
      .from('messages')
      .select('*', { count: 'exact' })
      .eq('conversation_id', conversationId);

    if (error) {
      console.error('❌ Error counting messages:', error);
      return 0;
    }

    return count || 0;
  }

  /**
   * Check if a conversation needs a title (has enough messages but no title)
   */
  async shouldGenerateTitle(conversationId: string): Promise<boolean> {
    const { data: conversation, error } = await this.supabase
      .from('conversations')
      .select('title')
      .eq('id', conversationId)
      .single();

    if (error || !conversation) {
      return false;
    }

    // Already has a title
    if (conversation.title && conversation.title.trim() !== '') {
      return false;
    }

    // Check message count
    const messageCount = await this.getConversationMessageCount(conversationId);

    // Generate title after 5+ messages
    return messageCount >= 5;
  }
}