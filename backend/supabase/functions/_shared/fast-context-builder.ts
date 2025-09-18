/**
 * Fast Context Builder for Phase 1 Optimization
 *
 * Focuses on parallel processing and essential context only
 * Optimized for speed while maintaining intelligence quality
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { VectorService } from './vector-service.ts'

export interface FastContext {
  person: any
  userProfile: any
  conversationHistory: any[]
  fileContent: string
  managementContext: {
    people: any[]
    team_size: any
    recent_themes: any[]
    current_challenges: string[]
    conversation_patterns: any
  }
  systemPrompt: string
  processingTime: number
}

export class FastContextBuilder {
  private vectorService: VectorService

  constructor(private supabase: SupabaseClient, private userId: string) {
    this.vectorService = new VectorService(supabase)
  }

  async buildStreamingContext(
    person_id: string,
    userMessage: string,
    isTopicConversation: boolean = false,
    topicId?: string,
    messageId?: string,
    hasFiles: boolean = false
  ): Promise<FastContext> {
    const startTime = Date.now()
    console.log('⚡ Fast context building started...')

    try {
      // PHASE 1: Critical data (parallel, fast)
      const [
        userProfile,
        personData,
        conversationHistory,
        basicTeamData
      ] = await Promise.all([
        this.getUserProfile(),
        this.getPersonData(person_id, isTopicConversation, topicId),
        this.getConversationHistory(person_id, isTopicConversation, topicId),
        this.getBasicTeamData()
      ])

      console.log('✅ Phase 1 complete: Critical data loaded')

      // PHASE 2: Enhanced context (parallel, moderate speed)
      const [
        fileContent,
        recentThemes,
        conversationPatterns
      ] = await Promise.all([
        hasFiles ? this.getFileContent(messageId, conversationHistory) : Promise.resolve(''),
        this.getRecentThemes(),
        this.getConversationPatterns()
      ])

      console.log('✅ Phase 2 complete: Enhanced context loaded')

      // PHASE 3: Build management context
      const managementContext = {
        people: basicTeamData.people || [],
        team_size: basicTeamData.team_size || { direct_reports: 0, stakeholders: 0, managers: 0, peers: 0 },
        recent_themes: recentThemes || [],
        current_challenges: this.extractCurrentChallenges(recentThemes),
        conversation_patterns: conversationPatterns || { most_discussed_people: [], trending_topics: [], cross_person_mentions: [] }
      }

      // PHASE 4: Build system prompt
      const systemPrompt = this.buildSystemPrompt(
        personData,
        userProfile,
        conversationHistory,
        managementContext
      )

      const processingTime = Date.now() - startTime
      console.log(`⚡ Fast context building completed in ${processingTime}ms`)

      return {
        person: personData,
        userProfile,
        conversationHistory,
        fileContent,
        managementContext,
        systemPrompt,
        processingTime
      }
    } catch (error) {
      console.error('❌ Fast context building failed:', error)
      throw new Error(`Context building failed: ${(error as any).message}`)
    }
  }

  private async getUserProfile() {
    try {
      const { data } = await this.supabase
        .from('user_profiles')
        .select('call_name, job_role, company, preferred_name')
        .eq('user_id', this.userId)
        .single()
      return data
    } catch (error) {
      console.warn('⚠️ User profile not found, using defaults')
      return { call_name: 'Manager', job_role: 'Manager', company: 'Company' }
    }
  }

  private async getPersonData(person_id: string, isTopicConversation: boolean, topicId?: string) {
    if (isTopicConversation && topicId) {
      // For topic conversations, create virtual person
      const { data: topic } = await this.supabase
        .from('topics')
        .select('*')
        .eq('id', topicId)
        .eq('user_id', this.userId)
        .single()

      return {
        id: 'mano',
        name: 'Mano',
        role: 'Management Assistant',
        relationship_type: 'assistant',
        is_self: false,
        topicTitle: topic?.title
      }
    } else {
      // Get actual person data
      const { data, error } = await this.supabase
        .from('people')
        .select('*, is_self')
        .eq('id', person_id)
        .eq('user_id', this.userId)
        .single()

      if (error || !data) {
        throw new Error('Person not found')
      }
      return data
    }
  }

  private async getConversationHistory(person_id: string, isTopicConversation: boolean, topicId?: string) {
    if (isTopicConversation && topicId) {
      const { data } = await this.supabase
        .from('messages')
        .select('*')
        .eq('topic_id', topicId)
        .order('created_at', { ascending: true })
        .limit(10)
      return data || []
    } else {
      const { data } = await this.supabase
        .from('messages')
        .select('*')
        .eq('person_id', person_id)
        .eq('user_id', this.userId)
        .order('created_at', { ascending: true })
        .limit(10)
      return data || []
    }
  }

  private async getBasicTeamData() {
    try {
      // Get people with basic info only
      const { data: people } = await this.supabase
        .from('people')
        .select('id, name, role, relationship_type, is_self')
        .eq('user_id', this.userId)
        .order('created_at', { ascending: false })

      // Calculate team size
      const team_size = {
        direct_reports: people?.filter(p => p.relationship_type === 'direct_report').length || 0,
        stakeholders: people?.filter(p => p.relationship_type === 'stakeholder').length || 0,
        managers: people?.filter(p => p.relationship_type === 'manager').length || 0,
        peers: people?.filter(p => p.relationship_type === 'peer').length || 0
      }

      return { people: people || [], team_size }
    } catch (error) {
      console.warn('⚠️ Team data fetch failed:', error)
      return { people: [], team_size: { direct_reports: 0, stakeholders: 0, managers: 0, peers: 0 } }
    }
  }

  private async getFileContent(messageId?: string, conversationHistory: any[] = []) {
    if (!messageId) return ''

    try {
      const { data: messageFiles } = await this.supabase
        .from('message_files')
        .select('*')
        .eq('message_id', messageId)
        .order('created_at', { ascending: true })

      if (!messageFiles || messageFiles.length === 0) return ''

      const fileContents = messageFiles
        .filter(file => file.extracted_content)
        .map(file => `\n--- File: ${file.original_name} (${file.file_type}) ---\n${file.extracted_content}`)

      return fileContents.length > 0
        ? '\n\n--- ATTACHED FILES ---' + fileContents.join('\n') + '\n--- END FILES ---\n'
        : ''
    } catch (error) {
      console.warn('⚠️ File content fetch failed:', error)
      return ''
    }
  }

  private async getRecentThemes() {
    try {
      // Simple recent themes - can be enhanced later
      const { data: messages } = await this.supabase
        .from('messages')
        .select('content, created_at')
        .eq('user_id', this.userId)
        .gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString())
        .limit(50)

      // Basic theme extraction
      const themes = this.extractThemes(messages || [])
      return themes.slice(0, 5) // Top 5 themes
    } catch (error) {
      console.warn('⚠️ Recent themes fetch failed:', error)
      return []
    }
  }

  private async getConversationPatterns() {
    try {
      // Simplified conversation patterns
      const { data: recentMessages } = await this.supabase
        .from('messages')
        .select('person_id, content, created_at')
        .eq('user_id', this.userId)
        .gte('created_at', new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString())
        .limit(100)

      return {
        most_discussed_people: this.getMostDiscussedPeople(recentMessages || []),
        trending_topics: [],
        cross_person_mentions: []
      }
    } catch (error) {
      console.warn('⚠️ Conversation patterns fetch failed:', error)
      return { most_discussed_people: [], trending_topics: [], cross_person_mentions: [] }
    }
  }

  private extractThemes(messages: any[]): any[] {
    // Simple keyword-based theme extraction
    const themeKeywords = {
      'performance': ['performance', 'review', 'feedback', 'improvement'],
      'career': ['career', 'growth', 'promotion', 'development'],
      'project': ['project', 'deadline', 'deliverable', 'milestone'],
      'team': ['team', 'collaboration', 'conflict', 'dynamics'],
      'personal': ['vacation', 'time off', 'personal', 'family']
    }

    const themeCounts: Record<string, number> = {}

    messages.forEach(msg => {
      const content = msg.content.toLowerCase()
      Object.entries(themeKeywords).forEach(([theme, keywords]) => {
        if (keywords.some(keyword => content.includes(keyword))) {
          themeCounts[theme] = (themeCounts[theme] || 0) + 1
        }
      })
    })

    return Object.entries(themeCounts)
      .map(([theme, frequency]) => ({ theme, frequency, people_mentioned: [], last_mentioned: new Date().toISOString(), examples: [] }))
      .sort((a: any, b: any) => b.frequency - a.frequency)
  }

  private getMostDiscussedPeople(messages: any[]): string[] {
    const personCounts: Record<string, number> = {}

    messages.forEach(msg => {
      if (msg.person_id) {
        personCounts[msg.person_id] = (personCounts[msg.person_id] || 0) + 1
      }
    })

    return Object.entries(personCounts)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 5)
      .map(([personId]) => personId)
  }

  private extractCurrentChallenges(themes: any[]): string[] {
    // Extract challenges from themes
    return themes
      .filter(theme => ['performance', 'conflict', 'project'].includes(theme.theme))
      .map(theme => `${theme.theme} management`)
      .slice(0, 3)
  }

  private buildSystemPrompt(person: any, userProfile: any, conversationHistory: any[], managementContext: any): string {
    // Import system prompts
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

Context about the person being discussed:
Name: {name}
Role: {role}
Relationship: {relationship_type}

{management_context}

Previous conversation history:
{conversation_history}

Respond in a helpful, professional tone. Focus on actionable advice and insights that will help the manager build better relationships with their team.`

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

Help them explore their thoughts, feelings, and leadership journey. This is a safe space for honest self-reflection about their management practice.`

    const GENERAL_SYSTEM_PROMPT = `You are Mano, an intelligent management assistant for strategic thinking and leadership challenges.

{user_context}

IMPORTANT: Keep responses conversational and concise (2-4 sentences max). Be direct, practical, and avoid lengthy explanations.

Response Style:
- Conversational and natural (like texting a trusted advisor)
- 2-4 sentences maximum per response
- Lead with the most actionable insight
- Ask one focused follow-up question when helpful
- Use "🤲" emoji occasionally but sparingly

Help with quick advice on: strategic planning, team leadership, communication, performance management, conflict resolution, career coaching, process improvement, and change management.

{management_context}

Previous conversation history:
{conversation_history}`

    // Select appropriate prompt
    let selectedPrompt: string
    if (person.id === 'mano' || person.relationship_type === 'assistant') {
      selectedPrompt = GENERAL_SYSTEM_PROMPT
    } else if (person.is_self) {
      selectedPrompt = SELF_SYSTEM_PROMPT
    } else {
      selectedPrompt = SYSTEM_PROMPT
    }

    // Format conversation history
    const historyText = conversationHistory
      .slice(-10)
      .map((msg: any) => `${msg.is_user ? 'Manager' : 'Mano'}: ${msg.content}`)
      .join('\n')

    // Build user context
    const userContext = userProfile?.call_name ?
      `You are speaking with ${userProfile.call_name}${userProfile.job_role ? `, ${userProfile.job_role}` : ''}${userProfile.company ? ` at ${userProfile.company}` : ''}.` :
      'You are speaking with a manager.'

    // Format management context
    const contextText = this.formatManagementContext(managementContext)

    // Replace placeholders
    return selectedPrompt
      .replace('{user_context}', userContext)
      .replace('{name}', person.name || 'Team member')
      .replace('{role}', person.role || 'Team member')
      .replace('{relationship_type}', person.relationship_type || 'colleague')
      .replace('{management_context}', contextText)
      .replace('{conversation_history}', historyText || 'No previous conversation')
  }

  private formatManagementContext(context: any): string {
    const { people, team_size, recent_themes } = context

    let formatted = `\nTEAM OVERVIEW:\n`
    formatted += `- Team size: ${team_size.direct_reports} direct reports, ${team_size.peers} peers, ${team_size.stakeholders} stakeholders\n`

    if (people.length > 0) {
      formatted += `- Team members: ${people.map((p: any) => `${p.name}${p.role ? ` (${p.role})` : ''}`).join(', ')}\n`
    }

    if (recent_themes.length > 0) {
      formatted += `\nRECENT THEMES:\n`
      formatted += recent_themes.map((theme: any) => `- ${theme.theme}: ${theme.frequency} mentions`).join('\n')
    }

    return formatted
  }
}