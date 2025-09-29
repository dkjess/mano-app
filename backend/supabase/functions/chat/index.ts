import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Anthropic } from 'https://esm.sh/@anthropic-ai/sdk@0.24.3'
import { ManagementContextBuilder, formatContextForPrompt } from '../_shared/management-context.ts'
import { FastContextBuilder } from '../_shared/fast-context-builder.ts'
import { VectorService } from '../_shared/vector-service.ts'
import { buildEnhancedSystemPrompt } from '../_shared/prompt-engineering.ts'
import { OnboardingService } from '../_shared/onboarding-service.ts'
import { getOnboardingPrompt } from '../_shared/onboarding-prompts.ts'
import { detectNewPeopleWithContext, type ContextAwarePersonDetectionResult } from '../_shared/context-aware-person-detection.ts'
import { analyzeProfileCompleteness, shouldPromptForCompletion } from '../_shared/profile-completeness.ts'
import { ConversationManager, type Conversation } from '../_shared/conversation-manager.ts'
import { 
  getNextQuestion, 
  generateCompletionMessage,
  formatProfileUpdate,
  isCorrection,
  extractCorrection,
  type PersonProfile
} from '../_shared/profile-enhancement.ts'
import { extractProfileDataWithContext } from '../_shared/context-aware-profile-enhancement.ts'
import { LearningSystem } from '../_shared/learning-system.ts'

// PostHog server-side tracking
const POSTHOG_KEY = Deno.env.get('POSTHOG_KEY')
const POSTHOG_HOST = Deno.env.get('POSTHOG_HOST') || 'https://eu.posthog.com'

async function trackServerEvent(distinctId: string, event: string, properties: Record<string, any> = {}) {
  if (!POSTHOG_KEY) return // Skip if no key configured
  
  try {
    await fetch(`${POSTHOG_HOST}/capture/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        api_key: POSTHOG_KEY,
        event,
        distinct_id: distinctId,
        properties: {
          ...properties,
          environment: 'edge_function',
          timestamp: new Date().toISOString(),
        }
      })
    })
  } catch (error) {
    console.warn('PostHog tracking failed:', error)
  }
}

// Performance tracking utility
class PerformanceTracker {
  private startTime: number
  private checkpoints: { [key: string]: number } = {}
  private userId: string
  private requestId: string

  constructor(userId: string, requestId: string) {
    this.startTime = Date.now()
    this.userId = userId
    this.requestId = requestId
    this.checkpoints.request_start = this.startTime
  }

  checkpoint(name: string) {
    this.checkpoints[name] = Date.now()
  }

  getDuration(from: string, to?: string): number {
    const fromTime = this.checkpoints[from] || this.startTime
    const toTime = to ? this.checkpoints[to] : Date.now()
    return toTime - fromTime
  }

  async trackCompletion(eventData: Record<string, any> = {}) {
    const totalDuration = Date.now() - this.startTime
    
    await trackServerEvent(this.userId, 'edge_function_performance', {
      request_id: this.requestId,
      total_duration_ms: totalDuration,
      context_build_duration_ms: this.getDuration('request_start', 'context_complete'),
      anthropic_duration_ms: this.getDuration('anthropic_start', 'anthropic_complete'),
      intelligence_duration_ms: this.getDuration('intelligence_start', 'intelligence_complete'),
      streaming_duration_ms: this.getDuration('streaming_start', 'streaming_complete'),
      ...eventData
    })
  }
}


// Helper function to estimate tokens from text
function estimateTokens(text: string): number {
  // Rough estimation: 1 token ≈ 4 characters
  return Math.ceil(text.length / 4);
}

// Helper function to chunk large text files
function chunkLargeText(text: string, maxTokens: number = 10000): string[] {
  const chunks: string[] = [];
  const estimatedTokens = estimateTokens(text);
  
  if (estimatedTokens <= maxTokens) {
    return [text];
  }
  
  // Calculate chunk size in characters
  const chunkSizeChars = maxTokens * 4;
  const totalChunks = Math.ceil(text.length / chunkSizeChars);
  
  console.log(`📊 Chunking large text: ${estimatedTokens} tokens into ${totalChunks} chunks`);
  
  // For VTT/SRT files, try to chunk by timestamps
  if (text.includes('-->') && (text.includes('WEBVTT') || /^\d+\s*\n/.test(text))) {
    // Split by double newlines to get subtitle blocks
    const blocks = text.split(/\n\n+/);
    let currentChunk = '';
    
    for (const block of blocks) {
      if (estimateTokens(currentChunk + block) > maxTokens && currentChunk) {
        chunks.push(currentChunk.trim());
        currentChunk = block;
      } else {
        currentChunk += (currentChunk ? '\n\n' : '') + block;
      }
    }
    
    if (currentChunk) {
      chunks.push(currentChunk.trim());
    }
  } else {
    // For other text files, chunk by sentences or lines
    const lines = text.split('\n');
    let currentChunk = '';
    
    for (const line of lines) {
      if (estimateTokens(currentChunk + line) > maxTokens && currentChunk) {
        chunks.push(currentChunk.trim());
        currentChunk = line;
      } else {
        currentChunk += (currentChunk ? '\n' : '') + line;
      }
    }
    
    if (currentChunk) {
      chunks.push(currentChunk.trim());
    }
  }
  
  return chunks;
}

// Helper function to process AI SDK attachments
async function processAttachments(attachments: Array<{name?: string; contentType?: string; url: string}>) {
  const processedFiles: Array<{
    name: string;
    contentType: string;
    content: string;
    size: number;
    isLarge?: boolean;
    chunks?: string[];
    estimatedTokens?: number;
  }> = [];

  console.log(`📎 PROCESS DEBUG: Starting to process ${attachments.length} attachments`);

  for (const attachment of attachments) {
    try {
      console.log(`📎 PROCESS DEBUG: Processing attachment:`, {
        name: attachment.name,
        contentType: attachment.contentType,
        urlLength: attachment.url?.length,
        urlPreview: attachment.url?.substring(0, 50) + '...'
      });
      // Extract content from Data URL
      const dataUrl = attachment.url;
      console.log(`📎 PROCESS DEBUG: Data URL structure:`, {
        fullLength: dataUrl.length,
        startsWithData: dataUrl.startsWith('data:'),
        containsComma: dataUrl.includes(','),
        commaIndex: dataUrl.indexOf(',')
      });
      
      const [header, base64Data] = dataUrl.split(',');
      
      console.log(`📎 PROCESS DEBUG: After splitting:`, {
        header: header,
        base64DataLength: base64Data?.length,
        base64DataPreview: base64Data?.substring(0, 50) + '...'
      });
      
      if (!base64Data) {
        console.warn('❌ PROCESS DEBUG: Invalid data URL for attachment:', attachment.name);
        console.warn('❌ PROCESS DEBUG: Data URL was:', dataUrl);
        continue;
      }
      
      // Enhanced content type detection with filename fallback
      let contentType = attachment.contentType || header.match(/data:([^;]+)/)?.[1] || 'application/octet-stream';
      
      // Simple filename fallback for VTT/SRT files
      if (contentType === 'application/octet-stream' && attachment.name) {
        const ext = attachment.name.split('.').pop()?.toLowerCase();
        if (ext === 'vtt') contentType = 'text/vtt';
        if (ext === 'srt') contentType = 'text/plain';
      }
      
      // Enhanced error logging for debugging
      console.log(`📎 DEBUG: Processing attachment details:`, {
        name: attachment.name,
        originalContentType: attachment.contentType,
        detectedContentType: contentType,
        headerInfo: header,
        base64Length: base64Data.length,
        base64Preview: base64Data.substring(0, 20) + '...'
      });
      
      // Decode base64 content
      let binaryData: string;
      let size: number;
      
      try {
        // For text files, decode directly to string
        if (contentType.startsWith('text/') || contentType === 'application/json') {
          console.log(`📎 Decoding text file: ${attachment.name} (${contentType})`);
          console.log(`📎 Base64 data length: ${base64Data.length}`);
          console.log(`📎 Base64 preview: ${base64Data.substring(0, 50)}...`);
          
          // Use TextDecoder for better text handling
          const binaryArray = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0));
          binaryData = new TextDecoder().decode(binaryArray);
          
          console.log(`📎 Decoded text preview: ${binaryData.substring(0, 100)}...`);
        } else {
          // For other files, just get the size
          binaryData = `[Binary content: ${attachment.name}]`;
        }
        size = base64Data.length * 0.75; // Approximate decoded size
        console.log(`📎 Successfully processed ${attachment.name} (${contentType}, ~${size} bytes)`);
      } catch (decodeError) {
        console.error(`❌ Failed to process attachment ${attachment.name}:`, decodeError);
        console.error(`❌ Content type: ${contentType}`);
        console.error(`❌ Base64 data: ${base64Data.substring(0, 100)}...`);
        throw new Error(`Failed to process attachment: ${attachment.name}`);
      }
      
      let textContent = '';
      
      // Process based on content type with validation
      if (contentType.startsWith('text/') || contentType === 'application/json' || 
          contentType === 'text/csv' || contentType === 'text/markdown' ||
          contentType === 'text/vtt' || contentType === 'text/x-vtt') {
        // Text files can be directly decoded
        textContent = binaryData;
        
        // Validate the decoded content
        if (!textContent || textContent.trim().length === 0) {
          console.warn(`⚠️ Empty or invalid text content for ${attachment.name}`);
          textContent = `[File: ${attachment.name} - content could not be extracted]`;
        } else {
          console.log(`✅ Successfully extracted ${textContent.length} characters from ${attachment.name}`);
          
          // Special handling for meeting transcripts
          if (contentType === 'text/vtt' || contentType === 'text/x-vtt') {
            const hasWebVTTHeader = textContent.startsWith('WEBVTT');
            const hasTimestamps = textContent.includes('-->');
            console.log(`📹 VTT file analysis: Valid header: ${hasWebVTTHeader}, Has timestamps: ${hasTimestamps}`);
          }
        }
      } else if (contentType.startsWith('image/')) {
        // For images, we'll include the data URL for vision models
        textContent = `[Image: ${attachment.name || 'uploaded image'}]`;
      } else {
        // Other file types - for now just store metadata
        textContent = `[File: ${attachment.name || 'uploaded file'} (${contentType})]`;
      }
      
      // Check if this is a large text file that needs chunking
      const tokens = estimateTokens(textContent);
      const isLarge = tokens > 15000; // Threshold for large files
      
      const fileData: any = {
        name: attachment.name || 'unnamed-file',
        contentType,
        content: textContent,
        size,
        estimatedTokens: tokens
      };
      
      if (isLarge && (contentType.startsWith('text/') || contentType === 'application/json')) {
        console.log(`📊 Large file detected: ${attachment.name} (~${tokens} tokens)`);
        fileData.isLarge = true;
        fileData.chunks = chunkLargeText(textContent);
        console.log(`📊 Split into ${fileData.chunks.length} chunks`);
      } else {
        fileData.isLarge = false;
      }
      
      processedFiles.push(fileData);
      
      console.log(`📎 Processed attachment: ${attachment.name} (${contentType}, ${size} bytes, ~${tokens} tokens)`);
      
    } catch (error) {
      console.error('❌ PROCESS DEBUG: Error processing attachment:', attachment.name, error);
      console.error('❌ PROCESS DEBUG: Error stack:', (error as any).stack);
      console.error('❌ PROCESS DEBUG: Attachment was:', JSON.stringify(attachment, null, 2));
      // Don't throw - just skip this attachment and continue
    }
  }
  
  return processedFiles;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ChatRequest {
  person_id: string;
  message: string;
}

interface StreamingChatRequest {
  action?: 'streaming_chat';
  messages: Array<{
    role: 'user' | 'assistant' | 'system';
    content: string;
  }>;
  person_id?: string;
  topic_id?: string;
  messageId?: string;
  attachments?: Array<{
    name?: string;
    contentType?: string;
    url: string; // Data URL from AI SDK
  }>;
}

interface Message {
  id: string;
  person_id: string;
  content: string;
  is_user: boolean;
  created_at: string;
}

interface Person {
  id: string;
  user_id: string;
  name: string;
  role: string | null;
  relationship_type: string;
  created_at: string;
  updated_at: string;
  team?: string | null;
  location?: string | null;
  notes?: string | null;
  communication_style?: string | null;
  goals?: string | null;
  strengths?: string | null;
  challenges?: string | null;
}

// System prompts - optimized for conversational brevity
const SYSTEM_PROMPT = `You are Mano, an intelligent management assistant and helping hand for managers.

{user_context}

IMPORTANT: Keep responses conversational and concise (2-4 sentences max). Be direct, practical, and avoid lengthy explanations.

Your role:
- Give quick, actionable management advice
- Ask focused questions to understand situations
- Suggest specific next steps
- Be supportive but brief

Response Style:
- Conversational and natural (like texting a colleague)
- 2-4 sentences maximum per response
- Lead with the most important insight
- Ask one focused follow-up question
- Use "✋" emoji occasionally but sparingly

For new people conversations:
- Acknowledge their context quickly
- Give ONE specific insight or action
- Ask what they need help with next

Example: "Got it - sounds like {name} needs clearer expectations. Try setting 30-min weekly check-ins to align on priorities. What's your biggest challenge with them right now?"

Context about the person being discussed:
Name: {name}
Role: {role}
Relationship: {relationship_type}

{management_context}

Previous conversation history:
{conversation_history}


Important: When discussing broader topics that extend beyond this individual:
- If the conversation shifts to team-wide challenges, projects, or initiatives, naturally suggest: "This sounds like it affects more than just {name}. Would you like to create a Topic for [topic name] to explore this more broadly?"
- Examples: team morale issues, cross-functional projects, process improvements, strategic initiatives

Respond in a helpful, professional tone. Focus on actionable advice and insights that will help the manager build better relationships with their team. When relevant team context adds value, reference it naturally in your response. Use hand emojis occasionally to reinforce the "helping hand" theme, but don't overdo it.`;

const SELF_SYSTEM_PROMPT = `You are Mano, an intelligent management coach for self-reflection and personal growth.

{user_context}

IMPORTANT: Keep responses conversational and concise (2-4 sentences max). Be direct, practical, and avoid lengthy explanations.

Your role in self-reflection:
- Help the manager reflect on their leadership style and growth
- Ask thoughtful questions to deepen self-awareness
- Identify patterns in their management approach
- Celebrate wins and acknowledge challenges
- Suggest specific actions for personal development

Response Style:
- Supportive and encouraging
- 2-4 sentences maximum per response
- Focus on self-discovery and insight
- Ask reflective questions when appropriate

Management Context:
{management_context}

Previous conversation history:
{conversation_history}

Help them explore their thoughts, feelings, and leadership journey. This is a safe space for honest self-reflection about their management practice.`;

const GENERAL_SYSTEM_PROMPT = `You are Mano, an intelligent management assistant for strategic thinking and leadership challenges.

{user_context}

IMPORTANT: Keep responses conversational and concise (2-4 sentences max). Be direct, practical, and avoid lengthy explanations.

Response Style:
- Conversational and natural (like texting a trusted advisor)
- 2-4 sentences maximum per response
- Lead with the most actionable insight
- Ask one focused follow-up question when helpful
- Use "🤲" emoji occasionally but sparingly

You have full visibility into the user's entire team. When relevant to the discussion:
- Reference specific team members by name and role
- Connect topics to people's strengths or challenges
- Suggest who might be involved or affected
- Use the team context to provide more personalized strategic advice

Help with quick advice on: strategic planning, team leadership, communication, performance management, conflict resolution, career coaching, process improvement, and change management.

Coaching Approach:
- For complex challenges: Ask 1 clarifying question, then give specific advice
- For urgent situations: Jump straight to actionable solutions
- For recurring patterns: Point out the pattern briefly and suggest a framework
- For people-related questions: Reference specific team members from the context

Example: "Sounds like team alignment is the core issue. Try a 90-min strategy session to get everyone on the same page about priorities. What's your biggest concern about facilitating that?"

Management Context: {management_context}

Previous Conversation: {conversation_history}

Be warm but brief. Make every sentence count. Remember: you know all team members and can reference them when it adds value to your advice.`;

const PROFILE_SETUP_PROMPT = `You are Mano, helping a manager set up a team member's profile through natural conversation.

Your role in profile setup:
- Ask one question at a time to gather profile information
- Extract structured data from natural language responses  
- Provide confirmations when information is updated
- Guide the conversation toward completion
- Be conversational and helpful, not robotic

Current person: {name}
Profile completion status: {completion_status}
Next question to ask: {next_question}

Previous conversation:
{conversation_history}

If the user provides profile information, acknowledge it and ask the next logical question. If they want to skip or finish, respect that choice. Keep the tone friendly and conversational.`;

// Database functions - simplified versions for edge function
async function getMessages(personId: string, supabase: any): Promise<Message[]> {
  const { data, error } = await supabase
    .from('messages')
    .select('*')
    .eq('person_id', personId)
    .order('created_at', { ascending: true });

  if (error) throw error;
  return data || [];
}

async function createMessage(
  messageData: {
    person_id: string;
    content: string;
    is_user: boolean;
    user_id: string;
  },
  supabase: any
): Promise<Message> {
  const { data, error } = await supabase
    .from('messages')
    .insert(messageData)
    .select()
    .single();

  if (error) throw error;
  return data;
}

// Check if this is a profile setup conversation
function isProfileSetupConversation(messages: Message[]): boolean {
  if (messages.length === 0) return false;
  
  // Check if the first system message is about profile setup
  const firstMessage = messages[0];
  return !firstMessage.is_user && (
    firstMessage.content.includes("Let's set up their profile") ||
    firstMessage.content.includes("What's") && firstMessage.content.includes("role")
  );
}

// Determine the current field being asked about in profile setup
function getCurrentProfileField(messages: Message[]): string {
  const lastAssistantMessage = messages
    .filter(m => !m.is_user)
    .pop();
    
  if (!lastAssistantMessage) return 'role';
  
  const content = lastAssistantMessage.content.toLowerCase();
  
  if (content.includes('role') || content.includes('job') || content.includes('title')) {
    return 'role';
  } else if (content.includes('company') || content.includes('team')) {
    return 'company';
  } else if (content.includes('relationship') || content.includes('know')) {
    return 'relationship';
  } else if (content.includes('location') || content.includes('based')) {
    return 'location';
  } else if (content.includes('details') || content.includes('remember')) {
    return 'notes';
  }
  
  return 'role'; // Default
}

// Update person profile with extracted data
async function updatePersonProfile(
  personId: string, 
  extractedData: any, 
  supabase: any
): Promise<Person> {
  const updateData: any = {};
  
  // Map extracted fields to database columns
  const fieldMapping: Record<string, string> = {
    'role': 'role',
    'company': 'team',
    'team': 'team',
    'relationship': 'relationship_type',
    'relationship_type': 'relationship_type',
    'location': 'location',
    'notes': 'notes',
    'communication_style': 'communication_style',
    'goals': 'goals',
    'strengths': 'strengths',
    'challenges': 'challenges'
  };
  
  // Primary field
  if (extractedData.primaryField && extractedData.extractedValue) {
    const dbField = fieldMapping[extractedData.primaryField];
    if (dbField) {
      updateData[dbField] = extractedData.extractedValue;
    }
  }
  
  // Additional fields
  if (extractedData.additionalFields) {
    for (const field of extractedData.additionalFields) {
      const dbField = fieldMapping[field.field];
      if (dbField && field.value) {
        updateData[dbField] = field.value;
      }
    }
  }
  
  if (Object.keys(updateData).length === 0) {
    // No updates to make, just return current person
    const { data } = await supabase
      .from('people')
      .select('*')
      .eq('id', personId)
      .single();
    return data;
  }
  
  const { data, error } = await supabase
    .from('people')
    .update(updateData)
    .eq('id', personId)
    .select()
    .single();
    
  if (error) throw error;
  return data;
}

// Handle streaming chat functionality
async function handleStreamingChat({
  supabase,
  anthropic,
  user,
  person_id,
  userMessage,
  topicId,
  hasFiles,
  isTopicConversation,
  topicTitle,
  messageId,
  performanceTracker,
  processedFiles = []
}: {
  supabase: any,
  anthropic: any,
  user: any,
  person_id: string,
  userMessage: string,
  topicId?: string,
  hasFiles?: boolean,
  isTopicConversation?: boolean,
  topicTitle?: string,
  messageId?: string,
  performanceTracker?: PerformanceTracker,
  processedFiles?: Array<{name: string; contentType: string; content: string; size: number}>
}) {
  console.log('🚀 STREAMING CHAT START')
  console.log('📋 Request details:', {
    person_id,
    userMessage: userMessage.substring(0, 100) + (userMessage.length > 100 ? '...' : ''),
    topicId,
    hasFiles,
    isTopicConversation,
    topicTitle,
    userId: user.id
  });
  
  console.log('🔍 TOPIC DEBUG: Input parameters:', {
    topicId: topicId || 'undefined',
    isTopicConversation: isTopicConversation || false,
    topicTitle: topicTitle || 'undefined'
  });

  try {
    // Performance checkpoint: Start context building
    performanceTracker?.checkpoint('context_start');

    // Get user profile
    const { data: userProfile } = await supabase
      .from('user_profiles')
      .select('call_name, job_role, company')
      .eq('user_id', user.id)
      .single()

    // All conversations are now UUID-based (topic or person)
    let person: Person
    let actualTopicId = topicId
    
    if (isTopicConversation && topicId) {
      // For topic conversations, get topic details
      try {
        const { data: topic } = await supabase
          .from('topics')
          .select('*')
          .eq('id', topicId)
          .eq('user_id', user.id)
          .single()

        if (topic) {
          actualTopicId = topic.id
          topicTitle = topic.title
          console.log('✅ TOPIC DEBUG: Topic found and set:', {
            actualTopicId,
            topicTitle: topic.title
          });
        } else {
          console.log('❌ TOPIC DEBUG: Topic not found in database');
        }
      } catch (error) {
        console.error('❌ TOPIC DEBUG: Error getting topic:', error)
      }
      
      // For topic conversations, create virtual person representing Mano
      person = {
        id: 'mano',
        user_id: '',
        name: 'Mano',
        role: 'Management Assistant',
        relationship_type: 'assistant',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
    } else {
      // Get person details including is_self flag
      const { data: personData, error: personError } = await supabase
        .from('people')
        .select('*, is_self')
        .eq('id', person_id)
        .eq('user_id', user.id)
        .single()

      if (personError || !personData) {
        return new Response(JSON.stringify({ error: 'Person not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      
      person = personData
    }

    // Get conversation history (from topic if applicable, otherwise from person's active conversation)
    let conversationHistory
    if (isTopicConversation && actualTopicId) {
      // For topic conversations, get messages from the topic
      const { data: topicMessages } = await supabase
        .from('messages')
        .select('*')
        .eq('topic_id', actualTopicId)
        .order('created_at', { ascending: true })
      conversationHistory = topicMessages || []
    } else {
      // For person conversations, get messages from active conversation
      const conversationManager = new ConversationManager(supabase, user.id);
      const conversation = await conversationManager.getOrCreateActiveConversation(person_id);

      const { data: conversationMessages } = await supabase
        .from('messages')
        .select('*')
        .eq('conversation_id', conversation.id)
        .order('created_at', { ascending: true })
      conversationHistory = conversationMessages || []
    }

    // Get file content for the most recent user message if files are present
    let fileContent = ''
    if (hasFiles) {
      console.log('🔍 FILE DEBUG: hasFiles flag is true, fetching file content...')
      try {
        let targetMessageId = messageId;
        
        // If no messageId provided, get the most recent user message to find attached files
        if (!targetMessageId) {
          const latestMessage = conversationHistory
            .filter((msg: any) => msg.is_user)
            .sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())[0]
          targetMessageId = latestMessage?.id;
        }
        
        if (targetMessageId) {
          console.log('🔍 FILE DEBUG: Target message ID for file fetching:', targetMessageId)
          
          // Get files for this message
          const { data: messageFiles, error: filesError } = await supabase
            .from('message_files')
            .select('*')
            .eq('message_id', targetMessageId)
            .order('created_at', { ascending: true })
          
          if (filesError) {
            console.error('❌ FILE DEBUG: Error fetching files:', filesError)
          } else if (messageFiles && messageFiles.length > 0) {
            console.log(`🔍 FILE DEBUG: Found ${messageFiles.length} files for message ${targetMessageId}`)
            
            // Extract content from all files
            const fileContents = []
            for (const file of messageFiles) {
              console.log(`🔍 FILE DEBUG: Processing file ${file.original_name} (${file.file_type})`)
              console.log(`🔍 FILE DEBUG: Processing status: ${file.processing_status}`)
              console.log(`🔍 FILE DEBUG: Has extracted content: ${!!file.extracted_content}`)
              
              if (file.extracted_content) {
                fileContents.push(`\n--- File: ${file.original_name} (${file.file_type}) ---\n${file.extracted_content}`)
                console.log(`✅ FILE DEBUG: Added content from ${file.original_name} (${file.extracted_content.length} chars)`)
              } else {
                console.log(`⚠️ FILE DEBUG: No extracted content for ${file.original_name} - status: ${file.processing_status}`)
                fileContents.push(`\n--- File: ${file.original_name} (${file.file_type}) ---\n[File content not yet processed]`)
              }
            }
            
            if (fileContents.length > 0) {
              fileContent = '\n\n--- ATTACHED FILES ---' + fileContents.join('\n') + '\n--- END FILES ---\n'
              console.log(`✅ FILE DEBUG: Final file content prepared (${fileContent.length} chars)`)
            }
          } else {
            console.log('⚠️ FILE DEBUG: No files found for target message')
          }
        } else {
          console.log('⚠️ FILE DEBUG: No target message ID found')
        }
      } catch (fileError) {
        console.error('❌ FILE DEBUG: Error processing files:', fileError)
      }
    } else {
      console.log('🔍 FILE DEBUG: hasFiles flag is false, skipping file content')
    }

    // Build enhanced management context with vector search
    performanceTracker?.checkpoint('intelligence_start');
    let managementContext
    try {
      console.log('🔍 CONTEXT DEBUG: Building management context...', {
        person_id,
        userMessage: userMessage.substring(0, 50) + '...',
        isTopicConversation,
        actualTopicId,
        user_id: user.id
      })
      
      const contextBuilder = new ManagementContextBuilder(supabase, user.id)
      const { context } = await contextBuilder.buildFullContext(
        person_id, 
        userMessage,
        isTopicConversation,
        actualTopicId,
        false // includeProactiveInsights
      )
      
      console.log('🔍 CONTEXT DEBUG: Raw context received:', {
        people_count: context.people?.length || 0,
        people_names: context.people?.map((p: any) => p.name) || [],
        team_size: context.team_size,
        conversation_patterns_count: context.conversation_patterns?.most_discussed_people?.length || 0
      })
      
      // Convert to expected format for prompt building
      managementContext = {
        people: context.people,
        team_size: context.team_size,
        recent_themes: context.recent_themes,
        current_challenges: context.current_challenges,
        conversation_patterns: context.conversation_patterns,
        semantic_context: context.semantic_context
      }
      
      console.log('🔍 CONTEXT DEBUG: Final managementContext for prompt:', {
        people_count: managementContext.people?.length || 0,
        people_sample: managementContext.people?.slice(0, 2)?.map((p: any) => ({ name: p.name, role: p.role })) || []
      })
    } catch (contextError) {
      console.error('❌ CRITICAL: Failed to gather enhanced management context:', contextError)
      // Provide basic fallback context instead of undefined
      managementContext = {
        people: [],
        team_size: { total: 0, direct_reports: 0, stakeholders: 0, peers: 0 },
        recent_themes: [],
        current_challenges: [],
        conversation_patterns: { cross_referencing: [] },
        semantic_context: undefined
      }
    }
    performanceTracker?.checkpoint('intelligence_complete');

    // User message is already created by the client, so we skip that step
    
    // Performance checkpoint: Complete context building
    performanceTracker?.checkpoint('context_complete');

    // Get profile context for person conversations
    let profileContext = '';
    if (!isTopicConversation && person_id) {
      try {
        const { data: profile } = await supabase
          .from('person_profiles')
          .select('content')
          .eq('person_id', person_id)
          .single();
        
        if (profile?.content) {
          profileContext = profile.content;
          console.log('✅ Retrieved profile context for person:', person_id);
        }
      } catch (profileError) {
        console.log('ℹ️ No profile context available for person:', person_id);
      }
    }

    // Build system prompt and context
    let systemPrompt
    if (isTopicConversation) {
      // Topic conversations should use the general prompt with user context
      systemPrompt = buildGeneralSystemPrompt(managementContext, conversationHistory, userProfile)
    } else {
      // Person conversations use person-specific prompt with profile context
      systemPrompt = buildSystemPrompt(
        person.name,
        person.role,
        person.relationship_type,
        conversationHistory,
        managementContext,
        userProfile,
        profileContext,
        person.is_self
      )
    }

    // Format conversation history
    const historyText = conversationHistory
      .slice(-10)
      .map((msg: any) => `${msg.is_user ? 'Manager' : 'Mano'}: ${msg.content}`)
      .join('\n')

    // Create a ReadableStream for streaming response
    const readableStream = new ReadableStream({
      async start(controller) {
        let fullResponse = ''
        const encoder = new TextEncoder()
        
        // For AI SDK compatibility, no initial signals needed
        // Just stream the text directly

        try {
          // Send thinking indicator to client
          console.log('🧠 Sending thinking indicator to client...')
          const thinkingData = `data: ${JSON.stringify({ thinking: true, message: 'Analyzing your message and building context...' })}\n\n`
          controller.enqueue(encoder.encode(thinkingData))

          console.log('🚀 Starting TRUE streaming response generation...')

          // Performance checkpoint: Start Anthropic API call
          performanceTracker?.checkpoint('anthropic_start');

          // Prepare the full user message including file content
          const fullUserMessage = userMessage + fileContent
          console.log('📝 Sending to Anthropic:', {
            originalMessage: userMessage.substring(0, 100),
            hasFileContent: fileContent.length > 0,
            fileContentLength: fileContent.length,
            totalMessageLength: fullUserMessage.length
          })

          // Send "generating response" indicator
          const generatingData = `data: ${JSON.stringify({ thinking: true, message: 'Generating response...' })}\n\n`
          controller.enqueue(encoder.encode(generatingData))

          // Get TRUE streaming response from Anthropic
          const streamingResponse = await anthropic.messages.stream({
            model: 'claude-sonnet-4-20250514',
            max_tokens: 4000,
            system: systemPrompt, // Use the built system prompt
            messages: [
              {
                role: 'user',
                content: fullUserMessage
              }
            ]
          })

          // Send thinking complete signal
          const thinkingCompleteData = `data: ${JSON.stringify({ thinking: false, message: 'Starting response...' })}\n\n`
          controller.enqueue(encoder.encode(thinkingCompleteData))

          console.log('🚀 Starting TRUE streaming response...')

          // Start background message saving (blocking to get conversation_id)
          let conversationIdForAI: string | null = null
          try {
            conversationIdForAI = await saveMessagesInBackground(
              userMessage,
              person_id,
              user.id,
              isTopicConversation,
              actualTopicId,
              processedFiles,
              supabase
            )
            console.log('✅ User message saved, conversation_id:', conversationIdForAI)
          } catch (error) {
            console.error('❌ Background message save failed:', error)
          }

          // Stream the response as it comes from Anthropic
          for await (const chunk of streamingResponse) {
            if (chunk.type === 'content_block_delta' && chunk.delta.type === 'text_delta') {
              const textChunk = chunk.delta.text
              fullResponse += textChunk

              // Send larger chunks for smoother streaming
              // Strategy: Send word-by-word or in small phrases
              const words = textChunk.split(/(\s+)/) // Keep whitespace
              let buffer = ''

              for (const word of words) {
                buffer += word

                // Send buffer when we hit a word boundary or reach reasonable size
                if (buffer.length >= 5 || word.trim().length > 0) {
                  const sseData = `data: ${JSON.stringify({ content: buffer })}\n\n`
                  controller.enqueue(encoder.encode(sseData))
                  buffer = ''

                  // Small delay between chunks for smooth perception (20-40ms)
                  await new Promise(resolve => setTimeout(resolve, Math.random() * 20 + 20))
                }
              }

              // Send any remaining buffer
              if (buffer.length > 0) {
                const sseData = `data: ${JSON.stringify({ content: buffer })}\n\n`
                controller.enqueue(encoder.encode(sseData))
              }
            }
          }

          // Performance checkpoint: Streaming complete
          performanceTracker?.checkpoint('anthropic_complete');

          // Save the AI response and run intelligence in background
          console.log('🔄 Saving AI response in background...')
          const saveAIResponsePromise = saveAIResponseInBackground(
            fullResponse,
            person_id,
            user.id,
            isTopicConversation,
            actualTopicId,
            userMessage,
            managementContext,
            supabase,
            conversationIdForAI
          ).catch(error => {
            console.error('❌ Background AI response save failed:', error)
          })

          // Stream completion signal
          const completionData = `data: ${JSON.stringify({ done: true })}\n\n`
          controller.enqueue(encoder.encode(completionData))

          console.log('✅ Streaming complete, background operations running...')
        } catch (error) {
          console.error('❌ Streaming error:', error)

          // Send error to client
          const errorData = `data: ${JSON.stringify({ error: 'An error occurred while generating the response.' })}\n\n`
          controller.enqueue(encoder.encode(errorData))
        } finally {
          controller.close()
        }
      }
    })

    return new Response(readableStream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        ...corsHeaders
      },
    })

  } catch (error) {
    console.error('Error in streaming chat:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
}

// Helper function to build system prompt (simplified from client-side)
function buildSystemPrompt(
  personName: string,
  personRole: string | null,
  relationshipType: string,
  conversationHistory: any[],
  managementContext: any,
  userProfile: any,
  profileContext?: string,
  isSelf?: boolean
): string {
  // Use the appropriate system prompt based on context
  if (personName === 'General') {
    return buildGeneralSystemPrompt(managementContext, conversationHistory, userProfile)
  } else {
    return buildPersonSystemPrompt(personName, personRole, relationshipType, conversationHistory, managementContext, userProfile, profileContext, isSelf)
  }
}

function buildPersonSystemPrompt(
  personName: string,
  personRole: string | null,
  relationshipType: string,
  conversationHistory: any[],
  managementContext: any,
  userProfile: any,
  profileContext?: string,
  isSelf?: boolean
): string {
  const contextText = managementContext ? formatContextForPrompt(managementContext) : ''
  const historyText = conversationHistory
    .slice(-10)
    .map((msg: any) => `${msg.is_user ? 'Manager' : 'Mano'}: ${msg.content}`)
    .join('\n')
  
  const userContext = userProfile?.call_name ? 
    `You are speaking with ${userProfile.call_name}${userProfile.job_role ? `, ${userProfile.job_role}` : ''}${userProfile.company ? ` at ${userProfile.company}` : ''}.` : 
    'You are speaking with a manager.'

  // Build enhanced prompt with profile context
  // Use self-reflection prompt for self persons
  let enhancedPrompt = isSelf ? SELF_SYSTEM_PROMPT : SYSTEM_PROMPT;
  
  // Add profile context if available
  if (profileContext && profileContext.trim()) {
    const profileSection = `

AI Profile Context for ${personName}:
${profileContext}

This profile provides background context about ${personName} to help you give more personalized and relevant management advice. Reference this context naturally in your responses when appropriate, but don't explicitly mention that you have this profile information.`;
    
    // Insert profile context after the main system prompt but before the conversation history
    const contextPlaceholder = '{management_context}';
    enhancedPrompt = enhancedPrompt.replace(contextPlaceholder, contextText + profileSection);
  } else {
    enhancedPrompt = enhancedPrompt.replace('{management_context}', contextText);
  }

  return enhancedPrompt
    .replace('{name}', personName)
    .replace('{role}', personRole || 'Team member')
    .replace('{relationship_type}', relationshipType)
    .replace('{conversation_history}', historyText)
    .replace('{user_context}', userContext)
}

function buildGeneralSystemPrompt(
  managementContext: any,
  conversationHistory: any[],
  userProfile: any
): string {
  console.log('🔍 PROMPT DEBUG: Building general system prompt with context:', {
    managementContext_exists: !!managementContext,
    people_count: managementContext?.people?.length || 0,
    contextText_preview: managementContext ? 'will format...' : 'NO CONTEXT'
  })
  
  const contextText = managementContext ? formatContextForPrompt(managementContext, 'general') : 'NO TEAM CONTEXT AVAILABLE'
  
  console.log('🔍 PROMPT DEBUG: Formatted context text preview:', {
    contextText_length: contextText.length,
    contextText_preview: contextText.substring(0, 200) + '...',
    includes_team_members: contextText.includes('TEAM MEMBERS'),
    includes_people_names: managementContext?.people?.some((p: any) => contextText.includes(p.name)) || false
  })
  
  const historyText = conversationHistory
    .slice(-10)
    .map((msg: any) => `${msg.is_user ? 'Manager' : 'Mano'}: ${msg.content}`)
    .join('\n')
  
  const userContext = userProfile?.call_name ? 
    `You are speaking with ${userProfile.call_name}${userProfile.job_role ? `, ${userProfile.job_role}` : ''}${userProfile.company ? ` at ${userProfile.company}` : ''}.` : 
    'You are speaking with a manager.'

  const finalPrompt = GENERAL_SYSTEM_PROMPT
    .replace('{management_context}', contextText)
    .replace('{conversation_history}', historyText)
    .replace('{user_context}', userContext)
    
  console.log('🔍 PROMPT DEBUG: Final prompt preview:', {
    prompt_length: finalPrompt.length,
    includes_context: finalPrompt.includes('TEAM MEMBERS'),
    still_has_placeholder: finalPrompt.includes('{management_context}')
  })
  
  return finalPrompt
}

// Extract actionable content that could be added to profiles
function extractProfileSuggestions(
  assistantResponse: string,
  personName: string
): ProfileSuggestion[] {
  console.log('🔍 PROFILE SUGGESTIONS: Starting extraction');
  console.log('🔍 PROFILE SUGGESTIONS: Response preview:', assistantResponse.substring(0, 200));
  console.log('🔍 PROFILE SUGGESTIONS: Person name:', personName);
  
  const suggestions: ProfileSuggestion[] = [];
  
  // Simple approach: Find ALL list items in the response
  // Pattern for bullet points: - item
  const bulletPoints = assistantResponse.match(/^[\s]*[-•]\s+(.+)$/gm) || [];
  
  // Pattern for numbered lists: 1. item, 2. item, etc.
  const numberedItems = assistantResponse.match(/^[\s]*\d+\.\s+(.+)$/gm) || [];
  
  // Combine all list items
  const allListItems = [...bulletPoints, ...numberedItems];
  
  console.log('🔍 PROFILE SUGGESTIONS: Found list items:', {
    bulletPoints: bulletPoints.length,
    numberedItems: numberedItems.length,
    total: allListItems.length
  });
  
  // If we found any list items, create suggestions for them
  if (allListItems.length > 0) {
    // Group items by their position in the response to create logical groupings
    let currentGroup: string[] = [];
    let lastIndex = -1;
    
    allListItems.forEach((item, index) => {
      const itemIndex = assistantResponse.indexOf(item);
      
      // If this item is close to the previous one (within 200 chars), group them
      if (lastIndex === -1 || itemIndex - lastIndex < 200) {
        currentGroup.push(item);
      } else {
        // Start a new group
        if (currentGroup.length > 0) {
          const suggestion = createSuggestionFromItems(currentGroup, personName, suggestions.length);
          if (suggestion) suggestions.push(suggestion);
        }
        currentGroup = [item];
      }
      lastIndex = itemIndex;
    });
    
    // Don't forget the last group
    if (currentGroup.length > 0) {
      const suggestion = createSuggestionFromItems(currentGroup, personName, suggestions.length);
      if (suggestion) suggestions.push(suggestion);
    }
  }
  
  console.log('🔍 PROFILE SUGGESTIONS: Created suggestions:', suggestions.length);
  return suggestions;
}

function createSuggestionFromItems(items: string[], personName: string, index: number): ProfileSuggestion | null {
  if (items.length === 0) return null;
  
  // Clean up the items (remove bullet/number markers)
  const cleanedItems = items.map(item => {
    return item
      .replace(/^[\s]*[-•]\s+/, '')  // Remove bullet points
      .replace(/^[\s]*\d+\.\s+/, '')  // Remove numbers
      .trim();
  });
  
  // Determine the type based on content
  let type: 'action_items' | 'schedule' | 'notes' | 'insights' = 'action_items';
  const firstItem = cleanedItems[0].toLowerCase();
  
  if (firstItem.includes('meeting') || firstItem.includes('1:1') || firstItem.includes('schedule')) {
    type = 'schedule';
  } else if (firstItem.includes('note') || firstItem.includes('remember')) {
    type = 'notes';
  } else if (firstItem.includes('insight') || firstItem.includes('observation')) {
    type = 'insights';
  }
  
  // Format as clean checkbox items (without extra markdown)
  const formattedItems = cleanedItems.map(item => `- [ ] ${item}`);
  
  // Create appropriate title based on type
  let title = 'Add to Profile';
  let heading = `## Items for ${personName}`;
  
  switch (type) {
    case 'action_items':
      title = 'Add Action Items';
      heading = `## Action Items for ${personName}`;
      break;
    case 'schedule':
      title = 'Add to Schedule';
      heading = `## Schedule for ${personName}`;
      break;
    case 'notes':
      title = 'Add Notes';
      heading = `## Notes about ${personName}`;
      break;
    case 'insights':
      title = 'Add Insights';
      heading = `## Insights about ${personName}`;
      break;
  }
  
  const content = `${heading}\n\n${formattedItems.join('\n')}`;
  const preview = items.length === 1 
    ? cleanedItems[0].substring(0, 50) + (cleanedItems[0].length > 50 ? '...' : '')
    : `${items.length} items`;
    
  console.log('🔍 PROFILE SUGGESTIONS: Created suggestion content:', content);
  console.log('🔍 PROFILE SUGGESTIONS: Preview:', preview);
  
  return {
    id: `${type}_${index}`,
    type,
    title,
    content,
    preview
  };
}

// Helper function to format error messages
function getErrorMessage(error: any): string {
  const errorMessage = (error as any).message || '';
  
  // Check for rate limit errors
  if (errorMessage.includes('rate_limit_error') || errorMessage.includes('429')) {
    return "🤚 I'm getting too many requests right now. Let's try again in a moment!"
  }
  
  // Check for specific error types
  if (errorMessage.includes('RATE_LIMIT')) {
    return "🤚 I'm getting too many requests right now. Let's try again in a moment!"
  }
  if (errorMessage.includes('SERVER_ERROR')) {
    return "🤷 I'm having some technical difficulties. Mind trying that again?"
  }
  if (errorMessage.includes('AUTH_ERROR')) {
    return "🔑 There's an authentication issue with my AI service. Please contact support."
  }
  
  return "🤔 Something went wrong on my end. Would you like to try sending that message again?"
}

// Background database operations for true streaming
async function saveMessagesInBackground(
  userMessage: string,
  person_id: string,
  user_id: string,
  isTopicConversation: boolean,
  topicId: string | undefined,
  processedFiles: Array<{name: string; contentType: string; content: string; size: number}>,
  supabase: any
): Promise<string | null> {
  console.log('🔄 Background: Starting user message save...')

  try {
    let conversation_id: string | null = null;

    // Get or create conversation for person-based chats
    if (!isTopicConversation && person_id) {
      const conversationManager = new ConversationManager(supabase, user_id);
      const conversation = await conversationManager.getOrCreateActiveConversation(person_id);
      conversation_id = conversation.id;
      console.log('✅ Background: Using conversation:', conversation_id);
    }

    // Save user message
    const { data: userMessageRecord, error: userError } = await supabase
      .from('messages')
      .insert({
        content: userMessage,
        person_id: isTopicConversation ? null : person_id,
        topic_id: isTopicConversation ? topicId : null,
        conversation_id: conversation_id,
        is_user: true,
        user_id: user_id
      })
      .select()
      .single()

    if (userError) {
      console.error('❌ Background: Failed to save user message:', userError)
      throw userError
    }

    console.log('✅ Background: User message saved successfully:', userMessageRecord.id)

    // Save files if any
    if (processedFiles.length > 0) {
      console.log('📎 Background: Saving message files...')
      for (const file of processedFiles) {
        const { error: fileError } = await supabase
          .from('message_files')
          .insert({
            message_id: userMessageRecord.id,
            original_name: file.name,
            file_type: file.contentType,
            extracted_content: file.content,
            file_size: file.size,
            user_id: user_id
          })

        if (fileError) {
          console.error('❌ Background: Failed to save file:', fileError)
        } else {
          console.log('✅ Background: File saved:', file.name)
        }
      }
    }

    // Return the conversation_id for use by AI response save
    return conversation_id
  } catch (error) {
    console.error('❌ Background: User message save failed:', error)
    throw error
  }
}

async function saveAIResponseInBackground(
  fullResponse: string,
  person_id: string,
  user_id: string,
  isTopicConversation: boolean,
  topicId: string | undefined,
  userMessage: string,
  managementContext: any,
  supabase: any,
  conversation_id: string | null
): Promise<void> {
  console.log('🔄 Background: Starting AI response save and intelligence...')

  try {
    // Create a service role client for background operations
    const serviceSupabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    console.log('🔍 Background: Step 1 - Created service role client for background operations')

    console.log('🔍 Background: Step 2 - Using conversation_id from user message:', conversation_id)

    // 1. Save AI response
    console.log('🔍 Background: Step 4 - Starting database insert...')
    console.log('🔍 Background: Insert params:', {
      contentLength: fullResponse.length,
      person_id: isTopicConversation ? null : person_id,
      topic_id: isTopicConversation ? topicId : null,
      conversation_id: conversation_id,
      is_user: false,
      user_id: user_id
    })
    const { data: assistantMessage, error: responseError } = await serviceSupabase
      .from('messages')
      .insert({
        content: fullResponse,
        person_id: isTopicConversation ? null : person_id,
        topic_id: isTopicConversation ? topicId : null,
        conversation_id: conversation_id,
        is_user: false,
        user_id: user_id
      })
      .select()
      .single()

    console.log('🔍 Background: Step 5 - Database insert completed')

    if (responseError) {
      console.error('❌ Background: Failed to save AI response:', responseError)
      throw responseError
    }

    console.log('✅ Background: AI response saved successfully:', assistantMessage.id)

    // 2. Run intelligence processing (simplified for Phase 1)
    console.log('🧠 Background: Starting intelligence processing...')

    try {
      // Person detection (simplified)
      if (!isTopicConversation && Deno.env.get('ANTHROPIC_API_KEY')) {
        const { detectNewPeopleWithContext } = await import('../_shared/context-aware-person-detection.ts')

        const existingPeopleNames = managementContext.people?.map((p: any) => p.name) || []
        const detectionResult = await detectNewPeopleWithContext(
          userMessage.trim(),
          existingPeopleNames,
          managementContext,
          Deno.env.get('ANTHROPIC_API_KEY')!
        )

        if (detectionResult.hasNewPeople) {
          console.log('👥 Background: Person detection found new people:', detectionResult.detectedPeople.map((p: any) => p.name))
        }
      }
    } catch (intelligenceError) {
      console.error('⚠️ Background: Intelligence processing failed (non-fatal):', intelligenceError)
      // Don't throw - intelligence failure shouldn't break the core flow
    }

    console.log('✅ Background: All operations complete')
  } catch (error) {
    console.error('❌ Background: AI response save failed:', error)
    throw error
  }
}

serve(async (req) => {
  console.log('🔥 EDGE FUNCTION DEBUG: Request received!', {
    method: req.method,
    url: req.url,
    timestamp: new Date().toISOString()
  });
  
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize clients
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const anthropic = new Anthropic({
      apiKey: Deno.env.get('ANTHROPIC_API_KEY')!,
    })

    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      console.error('Auth error in edge function:', authError)
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    
    console.log('Edge function auth context:', {
      user_id: user.id,
      user_email: user.email,
      auth_header_present: !!req.headers.get('Authorization')
    })

    // Parse request body
    const requestBody = await req.json()

    // Handle streaming chat requests (both new AI SDK format and legacy)
    if (requestBody.action === 'streaming_chat' || requestBody.messages) {
      // Initialize performance tracking
      const requestId = crypto.randomUUID();
      const perf = new PerformanceTracker(user.id, requestId);
      
      // Extract data from new AI SDK format or legacy format
      let person_id: string | undefined;
      let topic_id: string | undefined;
      let userMessage: string;
      let messageId: string | undefined;
      let processedFiles: Array<{name: string; contentType: string; content: string; size: number}> = [];

      if (requestBody.messages) {
        // New AI SDK format
        const { 
          messages,
          person_id: personId, 
          topic_id: topicId,
          messageId: msgId
        }: StreamingChatRequest = requestBody;

        person_id = personId;
        topic_id = topicId;
        messageId = msgId;
        
        // Get the last user message
        const lastMessage = messages[messages.length - 1];
        
        // Extract attachments from the last user message (AI SDK v4 format)
        const attachments = lastMessage?.experimental_attachments || [];
        
        // Process attachments if present
        perf.checkpoint('attachment_processing_start');
        if (attachments && attachments.length > 0) {
          console.log(`📎 ATTACHMENT DEBUG: Processing ${attachments.length} attachments from message...`);
          console.log(`📎 ATTACHMENT DEBUG: Raw attachments:`, JSON.stringify(attachments, null, 2));
          
          try {
            processedFiles = await processAttachments(attachments);
            console.log(`✅ ATTACHMENT DEBUG: Processed ${processedFiles.length} files successfully`);
            console.log(`✅ ATTACHMENT DEBUG: Processed files:`, processedFiles.map(f => ({
              name: f.name,
              contentType: f.contentType,
              contentLength: f.content.length,
              contentPreview: f.content.substring(0, 50) + '...'
            })));
          } catch (attachmentError) {
            console.error(`❌ ATTACHMENT DEBUG: Failed to process attachments:`, attachmentError);
            console.error(`❌ ATTACHMENT DEBUG: Error stack:`, (attachmentError as any).stack);
            throw attachmentError;
          }
        } else {
          console.log(`📎 ATTACHMENT DEBUG: No attachments to process`);
        }
        perf.checkpoint('attachment_processing_complete');
        if (!lastMessage || lastMessage.role !== 'user') {
          return new Response(JSON.stringify({ error: 'No user message found' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        userMessage = lastMessage.content;
        
        // If we have processed files, append their content to the user message
        if (processedFiles.length > 0) {
          // Check if any files are large
          const hasLargeFiles = processedFiles.some((f: any) => f.isLarge);
          
          if (hasLargeFiles) {
            // For large files, include the full content for immediate analysis
            console.log(`📊 Large file processing mode activated - including full content`);
            
            const fileContexts = processedFiles.map(file => {
              if (file.contentType.startsWith('text/') || file.contentType === 'application/json') {
                if (file.isLarge) {
                  // For large files, include full content but add a note
                  return `\n\n**Large File: ${file.name}** (${file.contentType}, ~${file.estimatedTokens} tokens)\n${file.content}`;
                } else {
                  return `\n\n**File: ${file.name}** (${file.contentType})\n${file.content}`;
                }
              } else {
                return `\n\n**File: ${file.name}** (${file.contentType}, ${file.size} bytes)`;
              }
            }).join('');
            
            userMessage += `\n\n**Attached Files:**${fileContexts}`;
          } else {
            // Normal processing for small files
            const fileContexts = processedFiles.map(file => {
              if (file.contentType.startsWith('text/') || file.contentType === 'application/json') {
                return `\n\n**File: ${file.name}** (${file.contentType})\n${file.content}`;
              } else {
                return `\n\n**File: ${file.name}** (${file.contentType}, ${file.size} bytes)`;
              }
            }).join('');
            
            userMessage += `\n\n**Attached Files:**${fileContexts}`;
          }
          
          console.log(`📎 Enhanced message with ${processedFiles.length} file(s), large files: ${hasLargeFiles}`);
        }

        console.log('🔍 EDGE FUNCTION DEBUG: AI SDK format request received:', {
          person_id,
          topic_id,
          messageCount: messages.length,
          attachmentCount: processedFiles.length,
          userMessage: userMessage?.substring(0, 100)
        });
      } else {
        // Legacy format - keep for backward compatibility
        const { 
          person_id: personId, 
          message, 
          topicId, 
          messageId: msgId
        } = requestBody;

        person_id = personId;
        topic_id = topicId;
        messageId = msgId;
        userMessage = message;

        console.log('🔍 EDGE FUNCTION DEBUG: Legacy format request received:', {
          person_id,
          topicId,
          userMessage: userMessage?.substring(0, 100)
        });
      }

      if (!userMessage) {
        return new Response(JSON.stringify({ error: 'message is required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      // Performance tracking: Start main chat processing
      perf.checkpoint('streaming_start');

      // Determine if we have files based on processed attachments
      const hasFiles = processedFiles && processedFiles.length > 0;
      
      const result = await handleStreamingChat({
        supabase,
        anthropic,
        user,
        person_id,
        userMessage,
        topicId: topic_id,
        hasFiles,
        isTopicConversation: !!topic_id,
        topicTitle: undefined, // Will be fetched from DB if needed
        messageId,
        performanceTracker: perf,
        processedFiles
      });

      perf.checkpoint('streaming_complete');
      await perf.trackCompletion();

      return result
    }

    // Handle regular chat requests
    const { person_id, message: userMessage }: ChatRequest = requestBody

    if (!person_id || !userMessage) {
      return new Response(JSON.stringify({ error: 'person_id and message are required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Initialize onboarding service
    const onboardingService = new OnboardingService(supabase)
    const onboardingContext = await onboardingService.getOnboardingContext(user.id)

    // Handle onboarding logic
    if (onboardingContext.isNewUser || !onboardingContext.hasPreferredName) {
      // Extract name from message if user is providing it
      if (!onboardingContext.hasPreferredName) {
        const extractedName = onboardingService.extractNameFromMessage(userMessage)
        if (extractedName) {
          await onboardingService.updatePreferredName(user.id, extractedName)
          onboardingContext.hasPreferredName = true
        }
      }

      // Auto-create team members mentioned in conversation
      const teamMentions = onboardingService.detectTeamMemberMention(userMessage)
      for (const mention of teamMentions) {
        try {
          await supabase.from('people').insert({
            user_id: user.id,
            name: mention.name,
            role: mention.role || null,
            relationship_type: mention.relationship || 'direct_report'
          })
        } catch (error) {
          // Ignore duplicate entries
          console.log(`Person ${mention.name} might already exist`)
        }
      }

      // Update onboarding step if needed
      if (teamMentions.length > 0 && onboardingContext.currentStep === 'welcome') {
        await onboardingService.updateOnboardingStep(user.id, 'team_building')
      }
    }

    // Check if onboarding should be completed
    if (!onboardingContext.isNewUser && await onboardingService.shouldCompleteOnboarding(user.id)) {
      await onboardingService.completeOnboarding(user.id)
      onboardingContext.isNewUser = false
    }

    // Get person details (or handle 'general' case)
    let person: Person
    if (person_id === 'general') {
      person = {
        id: 'general',
        user_id: user.id,
        name: 'general',
        role: 'Management Assistant',
        relationship_type: 'assistant',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
    } else {
      const { data: personData, error: personError } = await supabase
        .from('people')
        .select('*')
        .eq('id', person_id)
        .eq('user_id', user.id)
        .single()

      if (personError || !personData) {
        return new Response(JSON.stringify({ error: 'Person not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      person = personData
    }

    // Build fast context for streaming IMMEDIATELY (before saving messages)
    console.log('⚡ Starting fast context building for streaming...')
    const startTime = Date.now()
    const fastContextBuilder = new FastContextBuilder(supabase, user.id)
    const fastContext = await fastContextBuilder.buildStreamingContext(
      person_id,
      userMessage,
      person_id === 'general', // isTopicConversation
      undefined, // topicId (not used for person conversations)
      messageId, // for file processing
      processedFiles.length > 0 // hasFiles
    )
    const contextBuildTime = Date.now() - startTime

    console.log(`⚡ Fast context building took ${contextBuildTime}ms for user ${user.id}`)
    console.log(`✅ Context includes ${fastContext.managementContext.people.length} people, ${fastContext.managementContext.recent_themes.length} themes`)

    // For compatibility with existing code, map fast context to expected format
    const managementContext = fastContext.managementContext
    const enhancement = null // Not using conversational intelligence in Phase 1

    // Get conversation history from fast context (already loaded)
    const conversationHistory = fastContext.conversationHistory

    // 📨 User message will be saved in background (Phase 1 optimization - no blocking)
    console.log('⚡ Starting TRUE streaming - user message will be saved asynchronously')

    // Context already built above for streaming optimization

    // Check if user is responding to a profile prompt and process with context
    let profileUpdateResult = null;
    if (person_id !== 'general') {
      try {
        // Check if this might be a profile response by looking at recent conversation
        const recentMessages = conversationHistory.slice(-3); // Last 3 messages for context
        const lastAssistantMessage = recentMessages.filter(m => !m.is_user).pop();
        
        if (lastAssistantMessage && 
           (lastAssistantMessage.content.includes("What's") || 
            lastAssistantMessage.content.includes("Tell me") || 
            lastAssistantMessage.content.includes("role") ||
            lastAssistantMessage.content.includes("location") ||
            lastAssistantMessage.content.includes("company") ||
            lastAssistantMessage.content.includes("relationship"))) {
          
          console.log('🔍 Potential profile response detected, using context-aware extraction');
          
          // Determine what field was being asked about
          const currentField = getCurrentProfileField(conversationHistory);
          const personName = person.name;
          
          // Use context-aware profile extraction
          const extractionResult = await extractProfileDataWithContext(
            userMessage,
            currentField,
            personName,
            person_id,
            user.id,
            supabase,
            Deno.env.get('ANTHROPIC_API_KEY')!
          );
          
          console.log('🔍 Context-aware profile extraction result:', {
            field: currentField,
            extracted: extractionResult.extractedValue,
            confidence: extractionResult.confidence,
            teamMatches: extractionResult.teamPatternMatches.length,
            insights: extractionResult.contextualInsights.length
          });
          
          // Update person profile if we extracted something valuable
          if (extractionResult.extractedValue && extractionResult.confidence > 0.6) {
            const updateData: any = {};
            
            // Map field to database column
            const fieldMapping: Record<string, string> = {
              'role': 'role',
              'company': 'team',
              'team': 'team',
              'relationship': 'relationship_type',
              'location': 'location',
              'notes': 'notes'
            };
            
            const dbField = fieldMapping[currentField];
            if (dbField) {
              updateData[dbField] = extractionResult.extractedValue;
              
              // Also update any additional fields that were extracted
              extractionResult.additionalFields.forEach(field => {
                const additionalDbField = fieldMapping[field.field];
                if (additionalDbField && field.confidence > 0.7) {
                  updateData[additionalDbField] = field.value;
                }
              });
              
              // Update the person record
              const { data: updatedPerson } = await supabase
                .from('people')
                .update(updateData)
                .eq('id', person_id)
                .eq('user_id', user.id)
                .select()
                .single();
              
              if (updatedPerson) {
                profileUpdateResult = {
                  field: currentField,
                  value: extractionResult.extractedValue,
                  confidence: extractionResult.confidence,
                  teamMatches: extractionResult.teamPatternMatches,
                  insights: extractionResult.contextualInsights
                };
                
                console.log('🔍 Profile updated successfully:', updateData);
              }
            }
          }
        }
      } catch (profileError) {
        console.error('Context-aware profile enhancement failed:', profileError);
        // Don't fail the whole request if profile enhancement fails
      }
    }

    // Format conversation history
    const historyText = conversationHistory
      .slice(-10) // Only use last 10 messages for context
      .map((msg: Message) => `${msg.is_user ? 'Manager' : 'Mano'}: ${msg.content}`)
      .join('\n')

    // Check if profile completion should be prompted
    let profilePrompt = null
    if (person_id !== 'general') {
      try {
        // Get person details with profile fields
        const { data: personData } = await supabase
          .from('people')
          .select('*')
          .eq('id', person_id)
          .eq('user_id', user.id)
          .single();

        if (personData) {
          // Get conversation count
          const { count: conversationCount } = await supabase
            .from('messages')
            .select('*', { count: 'exact', head: true })
            .eq('person_id', person_id)
            .eq('is_user', true);

          // Analyze if we should prompt for profile completion
          const completeness = analyzeProfileCompleteness(personData);
          const shouldPrompt = shouldPromptForCompletion(
            personData,
            conversationCount || 0,
            personData.last_profile_prompt
          );

          if (shouldPrompt && completeness.suggestions.length > 0) {
            profilePrompt = completeness.suggestions[0];
            
            // Update last prompt date
            await supabase
              .from('people')
              .update({ last_profile_prompt: new Date().toISOString() })
              .eq('id', person_id);
          }
        }
      } catch (error) {
        console.error('Profile completion check failed:', error);
      }
    }

    // Choose system prompt based on onboarding state
    let systemPrompt: string
    
    if (onboardingContext.isNewUser || !onboardingContext.hasPreferredName) {
      // Use onboarding prompt
      const userProfile = await onboardingService.getUserProfile(user.id)
      systemPrompt = getOnboardingPrompt(
        onboardingContext.currentStep,
        userProfile?.preferred_name || undefined
      )
    } else {
      // Use enhanced system prompt with conversational intelligence
      if (enhancement) {
        // Use conversational intelligence to enhance the prompt
        let baseSystemPrompt: string
        if (person.name === 'general') {
          baseSystemPrompt = GENERAL_SYSTEM_PROMPT
            .replace('{conversation_history}', historyText || 'No previous conversation')
        } else {
          baseSystemPrompt = SYSTEM_PROMPT
            .replace('{name}', person.name)
            .replace('{role}', person.role || 'No specific role')
            .replace('{relationship_type}', person.relationship_type)
            .replace('{conversation_history}', historyText || 'No previous conversation')
        }

        const enhancedContext = formatContextForPrompt(managementContext, person_id, userMessage)
        const basePromptWithContext = baseSystemPrompt.replace('{management_context}', enhancedContext)

        systemPrompt = buildEnhancedSystemPrompt(
          basePromptWithContext,
          managementContext,
          enhancement,
          person_id
        )
      } else {
        // Fallback to basic enhanced context
        let baseSystemPrompt: string
        if (person.name === 'general') {
          baseSystemPrompt = GENERAL_SYSTEM_PROMPT
            .replace('{conversation_history}', historyText || 'No previous conversation')
        } else {
          baseSystemPrompt = SYSTEM_PROMPT
            .replace('{name}', person.name)
            .replace('{role}', person.role || 'No specific role')
            .replace('{relationship_type}', person.relationship_type)
            .replace('{conversation_history}', historyText || 'No previous conversation')
        }

        const enhancedContext = formatContextForPrompt(managementContext, person_id, userMessage)
        systemPrompt = baseSystemPrompt.replace('{management_context}', enhancedContext)
      }
    }

    // Modify system prompt to include profile completion prompt if needed
    if (profilePrompt) {
      const profilePromptText = `

PROFILE COMPLETION PROMPT:
After providing your main response, gently ask: "${profilePrompt.prompt}"

This will help you give better, more personalized advice in future conversations. Keep the prompt natural and conversational - don't make it feel like a form to fill out.`;

      systemPrompt = `${systemPrompt}${profilePromptText}`;
    }

    // Call Claude API with retry logic  
    let claudeResponse: string = 'Sorry, I had trouble generating a response.'
    const maxRetries = 2

    for (let attempt = 1; attempt <= maxRetries + 1; attempt++) {
      try {
        const response = await anthropic.messages.create({
          model: 'claude-sonnet-4-20250514', // Keep default for regular chat
          max_tokens: 600,
          system: systemPrompt,
          messages: [
            {
              role: 'user',
              content: userMessage
            }
          ]
        })

        const textContent = response.content.find(block => block.type === 'text')
        claudeResponse = (textContent as any)?.text || 'Sorry, I had trouble generating a response.'
        break

      } catch (error: any) {
        console.error(`Claude API attempt ${attempt} failed:`, error)
        
        if (attempt === maxRetries + 1) {
          // Return user-friendly error message
          if (error.status === 429) {
            claudeResponse = '🤚 I\'m getting too many requests right now. Let\'s try again in a moment!'
          } else if (error.status >= 500) {
            claudeResponse = '🤷 I\'m having some technical difficulties. Mind trying that again?'
          } else if (error.status === 401) {
            claudeResponse = '🔑 There\'s an authentication issue with my AI service. Please contact support.'
          } else {
            claudeResponse = '🤔 Something went wrong on my end. Would you like to try sending that message again?'
          }
        } else {
          // Wait before retrying (exponential backoff)
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000))
        }
      }
    }

    // Profile updates will now be handled via explicit API calls from the client
    // No automatic detection or updates

    // Save Claude's response
    const assistantMessage = await createMessage({
      person_id,
      content: claudeResponse,
      is_user: false,
      user_id: user.id
    }, supabase)

    // Store embeddings for both messages using dedicated embeddings function
    const embeddingsToCreate = [
      {
        userId: user.id,
        personId: person_id,
        messageId: userMessageRecord.id,
        content: userMessage,
        messageType: 'user',
        metadata: {}
      },
      {
        userId: user.id,
        personId: person_id,
        messageId: assistantMessage.id,
        content: claudeResponse,
        messageType: 'assistant',
        metadata: {}
      }
    ]
    
    fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/create-embeddings`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
      },
      body: JSON.stringify({ embeddings: embeddingsToCreate })
    }).catch(error => {
      console.error('❌ Background embedding creation error:', error)
    })

    // Process conversation for learning patterns (background task)
    const learningSystem = new LearningSystem(supabase, user.id, Deno.env.get('ANTHROPIC_API_KEY')!)
    learningSystem.processConversationForLearning(
      conversationHistory,
      person_id,
      managementContext
    ).catch(console.error)

    // Detect new people mentioned in the user message with full context
    let personDetection = null
    try {
      // Skip person detection for AI-generated welcome messages to prevent double detection
      const isWelcomeMessage = fullResponse.includes("Got it -") || 
                             fullResponse.toLowerCase().includes("try setting up") ||
                             (userMessage.trim().length < 50 && managementContext.people?.length === 1);
      
      if (!isWelcomeMessage) {
        // Get existing people names
        const { data: existingPeople } = await supabase
          .from('people')
          .select('name')
          .eq('user_id', user.id)
        
        const existingNames = existingPeople?.map((p: any) => p.name) || []
        
        // Use context-aware person detection with full management context
        const detectionResult = await detectNewPeopleWithContext(
          userMessage, 
          existingNames, 
          managementContext,
          Deno.env.get('ANTHROPIC_API_KEY')!
        )
      
        if (detectionResult.hasNewPeople) {
          personDetection = detectionResult
          console.log(`Context-aware person detection found ${detectionResult.detectedPeople.length} people (context used: ${detectionResult.contextUsed})`)
        }
      } else {
        console.log('🚫 Skipping person detection for AI welcome message in general processing')
      }
    } catch (detectionError) {
      console.error('Context-aware person detection failed:', detectionError)
      // Don't fail the whole request if detection fails
    }

    // Return response with person detection and profile completion results
    const responseData: any = {
      userMessage: userMessageRecord,
      assistantMessage,
      personDetection,
      shouldRetry: claudeResponse.includes('🤚') || claudeResponse.includes('🤷') || claudeResponse.includes('🤔')
    };

    if (profilePrompt) {
      responseData.profilePrompt = {
        field: profilePrompt.field,
        prompt: profilePrompt.prompt,
        examples: profilePrompt.examples
      };
    }

    if (profileUpdateResult) {
      responseData.profileUpdateResult = profileUpdateResult;
    }

    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Error in chat function:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
}) 