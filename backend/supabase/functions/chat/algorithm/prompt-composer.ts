/**
 * Prompt Composer
 *
 * THIS IS THE CORE OF MANO'S PERSONALITY AND COACHING STYLE.
 * All system prompts and prompt building logic lives here.
 *
 * When you want to change how Mano coaches, THIS is where you do it.
 */

import { formatContextForPrompt } from '../../_shared/management-context.ts'
import {
  getExperienceLevelGuidance,
  getToneGuidance,
  detectProblemType,
  determineResponseLengthGuidance,
  determineCoachingApproach
} from './coaching-strategy.ts'

// ============================================================================
// SYSTEM PROMPTS - These define Mano's personality and coaching approach
// ============================================================================

/**
 * Main system prompt for person-specific conversations
 * Used when coaching about a specific team member
 */
export const SYSTEM_PROMPT = `You are Mano, an intelligent management assistant and helping hand for managers.

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

/**
 * Self-reflection prompt for coaching the manager about themselves
 * Used when the person is marked as "self"
 */
export const SELF_SYSTEM_PROMPT = `You are Mano, an intelligent management coach for self-reflection and personal growth.

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

/**
 * General chat prompt for strategic thinking and broad topics
 * Used when not talking about a specific person
 */
export const GENERAL_SYSTEM_PROMPT = `You are Mano, an intelligent management assistant for strategic thinking and leadership challenges.

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

/**
 * Profile setup prompt (not currently used much, but kept for reference)
 */
export const PROFILE_SETUP_PROMPT = `You are Mano, helping a manager set up a team member's profile through natural conversation.

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

// ============================================================================
// PROMPT BUILDING FUNCTIONS
// ============================================================================

/**
 * Main entry point for building system prompts
 * Routes to the appropriate prompt builder based on context
 */
export function buildSystemPrompt(
  personName: string,
  personRole: string | null,
  relationshipType: string,
  conversationHistory: any[],
  managementContext: any,
  userProfile: any,
  profileContext?: string,
  isSelf?: boolean,
  userMessage?: string
): string {
  // Use the appropriate system prompt based on context
  if (personName === 'General') {
    return buildGeneralSystemPrompt(managementContext, conversationHistory, userProfile, userMessage)
  } else {
    return buildPersonSystemPrompt(personName, personRole, relationshipType, conversationHistory, managementContext, userProfile, profileContext, isSelf, userMessage)
  }
}

/**
 * Build prompt for person-specific conversations
 */
export function buildPersonSystemPrompt(
  personName: string,
  personRole: string | null,
  relationshipType: string,
  conversationHistory: any[],
  managementContext: any,
  userProfile: any,
  profileContext?: string,
  isSelf?: boolean,
  userMessage?: string
): string {
  const contextText = managementContext ? formatContextForPrompt(managementContext, 'general') : ''
  const historyText = conversationHistory
    .slice(-10)
    .map((msg: any) => `${msg.is_user ? 'Manager' : 'Mano'}: ${msg.content}`)
    .join('\n')

  // Enhanced user context with coaching preferences
  let userContext = userProfile?.call_name ?
    `You are speaking with ${userProfile.call_name}${userProfile.job_role ? `, ${userProfile.job_role}` : ''}${userProfile.company ? ` at ${userProfile.company}` : ''}.` :
    'You are speaking with a manager.'

  // Add experience level and tone guidance
  if (userProfile?.experience_level || userProfile?.tone_preference) {
    userContext += '\n\nCOACHING CONTEXT:'
    if (userProfile.experience_level) {
      userContext += `\n- Experience Level: ${getExperienceLevelGuidance(userProfile.experience_level)}`
    }
    if (userProfile.tone_preference) {
      userContext += `\n- Tone Preference: ${getToneGuidance(userProfile.tone_preference)}`
    }
  }

  // Add situational guidance if we have the current message
  if (userMessage) {
    const problemType = detectProblemType(userMessage)
    const coachingApproach = determineCoachingApproach(userMessage, conversationHistory, userProfile?.experience_level)
    userContext += problemType + coachingApproach
  }

  // Build enhanced prompt with profile context
  // Use self-reflection prompt for self persons
  let enhancedPrompt = isSelf ? SELF_SYSTEM_PROMPT : SYSTEM_PROMPT;

  // Adapt response length based on query complexity and user experience
  if (userMessage) {
    const lengthGuidance = determineResponseLengthGuidance(userMessage, userProfile?.experience_level, conversationHistory)
    enhancedPrompt = enhancedPrompt.replace('2-4 sentences maximum', lengthGuidance)
  }

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

/**
 * Build prompt for general/strategic conversations
 */
export function buildGeneralSystemPrompt(
  managementContext: any,
  conversationHistory: any[],
  userProfile: any,
  userMessage?: string
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

  // Enhanced user context with coaching preferences
  let userContext = userProfile?.call_name ?
    `You are speaking with ${userProfile.call_name}${userProfile.job_role ? `, ${userProfile.job_role}` : ''}${userProfile.company ? ` at ${userProfile.company}` : ''}.` :
    'You are speaking with a manager.'

  // Add experience level and tone guidance
  if (userProfile?.experience_level || userProfile?.tone_preference) {
    userContext += '\n\nCOACHING CONTEXT:'
    if (userProfile.experience_level) {
      userContext += `\n- Experience Level: ${getExperienceLevelGuidance(userProfile.experience_level)}`
    }
    if (userProfile.tone_preference) {
      userContext += `\n- Tone Preference: ${getToneGuidance(userProfile.tone_preference)}`
    }
  }

  // Add situational guidance if we have the current message
  if (userMessage) {
    const problemType = detectProblemType(userMessage)
    const coachingApproach = determineCoachingApproach(userMessage, conversationHistory, userProfile?.experience_level)
    userContext += problemType + coachingApproach
  }

  let finalPrompt = GENERAL_SYSTEM_PROMPT
    .replace('{management_context}', contextText)
    .replace('{conversation_history}', historyText)
    .replace('{user_context}', userContext)

  // Adapt response length based on query complexity
  if (userMessage) {
    const lengthGuidance = determineResponseLengthGuidance(userMessage, userProfile?.experience_level, conversationHistory)
    finalPrompt = finalPrompt.replace('2-4 sentences maximum', lengthGuidance)
  }

  console.log('🔍 PROMPT DEBUG: Final prompt preview:', {
    prompt_length: finalPrompt.length,
    includes_context: finalPrompt.includes('TEAM MEMBERS'),
    still_has_placeholder: finalPrompt.includes('{management_context}')
  })

  return finalPrompt
}
