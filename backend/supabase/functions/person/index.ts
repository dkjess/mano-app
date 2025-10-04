import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Anthropic } from 'https://esm.sh/@anthropic-ai/sdk@0.24.3'
import { corsHeaders } from '../_shared/cors.ts'

interface PersonCreateRequest {
  name: string
  role?: string
  relationship_type: 'direct_report' | 'manager' | 'peer' | 'stakeholder' | 'self'
  team?: string
  context?: string // Why are they being added
  current_situation?: string // Current context about this person
  generate_initial_message?: boolean
  started_working_together?: string // ISO date string
}

interface PersonUpdateRequest {
  name?: string
  role?: string
  relationship_type?: 'direct_report' | 'manager' | 'peer' | 'stakeholder' | 'self'
  team?: string
  location?: string
  notes?: string
  emoji?: string
  communication_style?: string
  goals?: string
  strengths?: string
  challenges?: string
}

interface InitialMessageContext {
  person_name: string
  relationship_type: string
  role?: string
  team?: string
  context?: string
  current_situation?: string
  user_name?: string
  existing_team_size: number
  management_style?: string
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(Boolean)
    const personId = pathParts[pathParts.length - 1]
    
    // Get authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Initialize Supabase client with user context
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      {
        global: {
          headers: { Authorization: authHeader }
        }
      }
    )

    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Authentication failed' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Route based on method and path
    switch (req.method) {
      case 'POST': {
        if (url.pathname.endsWith('/detect')) {
          return await handlePersonDetection(req, supabase, user)
        } else if (url.pathname.includes('/initial-message')) {
          return await handleInitialMessageGeneration(req, supabase, user, personId)
        } else if (url.pathname.includes('/analyze')) {
          return await handlePersonAnalysis(req, supabase, user, personId)
        } else {
          return await handlePersonCreate(req, supabase, user)
        }
      }
      
      case 'GET': {
        if (url.pathname.endsWith('/list')) {
          return await handlePersonList(supabase, user)
        } else if (url.pathname.includes('/insights')) {
          return await handlePersonInsights(supabase, user, personId)
        } else if (url.pathname.includes('/suggested-topics')) {
          return await handleSuggestedTopics(supabase, user, personId)
        } else {
          return await handlePersonGet(supabase, user, personId)
        }
      }
      
      case 'PUT': {
        return await handlePersonUpdate(req, supabase, user, personId)
      }
      
      case 'DELETE': {
        return await handlePersonDelete(supabase, user, personId)
      }
      
      default:
        return new Response(JSON.stringify({ error: 'Method not allowed' }), {
          status: 405,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
  } catch (error) {
    console.error('Error in person function:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

async function handlePersonCreate(req: Request, supabase: any, user: any) {
  const body: PersonCreateRequest = await req.json()

  // Validate required fields
  if (!body.name || !body.relationship_type) {
    return new Response(JSON.stringify({ error: 'Name and relationship_type are required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Prevent manual creation of self persons (they are auto-created)
  if (body.relationship_type === 'self') {
    return new Response(JSON.stringify({ error: 'Self person is automatically created when you sign up' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Create the person
  const { data: person, error: createError } = await supabase
    .from('people')
    .insert({
      user_id: user.id,
      name: body.name,
      role: body.role || null,
      relationship_type: body.relationship_type,
      team: body.team || null,
      is_self: false, // Always false for manually created persons
      started_working_together: body.started_working_together ? new Date(body.started_working_together).toISOString() : null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    })
    .select()
    .single()

  if (createError) {
    console.error('Error creating person:', createError)
    return new Response(JSON.stringify({ error: 'Failed to create person' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Generate and save a real AI message to start the conversation
  let aiMessage = null
  if (body.generate_initial_message !== false) { // Default to true
    const messageContent = await generateInitialMessage({
      person,
      context: body.context,
      current_situation: body.current_situation,
      supabase,
      user
    })

    // Save the AI message to the messages table
    const { data: savedMessage, error: messageError } = await supabase
      .from('messages')
      .insert({
        user_id: user.id,
        person_id: person.id,
        content: messageContent,
        is_user: false,
        created_at: new Date().toISOString()
      })
      .select()
      .single()

    if (messageError) {
      console.error('Error saving initial AI message:', messageError)
    } else {
      aiMessage = savedMessage
      console.log(`✅ Created initial AI message for ${person.name}`)
    }
  }

  // Store the context if provided (for future reference)
  if (body.context || body.current_situation) {
    try {
      await supabase
        .from('person_profiles')
        .upsert({
          person_id: person.id,
          user_id: user.id,
          context_on_creation: body.context,
          current_situation: body.current_situation,
          updated_at: new Date().toISOString()
        })
    } catch (error) {
      // Ignore profile creation errors if table doesn't exist
      console.log('Note: Could not save person profile context (table may not exist)')
    }
  }

  return new Response(JSON.stringify({ 
    person,
    initialMessage: aiMessage,
    hasInitialMessage: !!aiMessage
  }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
}

async function handlePersonList(supabase: any, user: any) {
  // First get people without profiles (in case person_profiles doesn't exist)
  const { data: people, error } = await supabase
    .from('people')
    .select('*')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })

  if (error) {
    console.error('Error fetching people:', error)
    return new Response(JSON.stringify({ error: 'Failed to fetch people' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Try to get profiles separately (won't fail if table doesn't exist)
  for (const person of people || []) {
    try {
      const { data: profile } = await supabase
        .from('person_profiles')
        .select('*')
        .eq('person_id', person.id)
        .single()
      
      if (profile) {
        person.profile = profile
      }
    } catch (e) {
      // Ignore profile fetch errors
    }
  }

  return new Response(JSON.stringify({ people }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
}

async function handlePersonGet(supabase: any, user: any, personId: string) {
  const { data: person, error } = await supabase
    .from('people')
    .select(`
      *,
      is_self,
      person_profiles (
        work_style,
        communication_preferences,
        motivations,
        growth_areas,
        strengths,
        recent_achievements,
        current_challenges,
        last_one_on_one,
        next_one_on_one,
        career_goals,
        personal_notes
      )
    `)
    .eq('id', personId)
    .eq('user_id', user.id)
    .single()

  if (error || !person) {
    return new Response(JSON.stringify({ error: 'Person not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Get recent conversation summary
  const { data: recentMessages } = await supabase
    .from('messages')
    .select('content, is_user, created_at')
    .eq('person_id', personId)
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(10)

  return new Response(JSON.stringify({ 
    person,
    recentMessages,
    conversationCount: recentMessages?.length || 0
  }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
}

async function handlePersonUpdate(req: Request, supabase: any, user: any, personId: string) {
  try {
    console.log('📝 Starting person update for:', personId)
    const body: PersonUpdateRequest = await req.json()
    console.log('📝 Request body received:', JSON.stringify(body, null, 2))

    // Only update fields that exist in the people table
    // Map the request data to the actual database columns
    const updateData: any = {
      updated_at: new Date().toISOString()
    }

    // Basic fields that exist in the people table
    if (body.name !== undefined) updateData.name = body.name
    if (body.role !== undefined) updateData.role = body.role
    if (body.relationship_type !== undefined) updateData.relationship_type = body.relationship_type
    if (body.team !== undefined) updateData.team = body.team
    if (body.location !== undefined) updateData.location = body.location
    if (body.notes !== undefined) updateData.notes = body.notes
    if (body.emoji !== undefined) updateData.emoji = body.emoji
    if (body.communication_style !== undefined) updateData.communication_style = body.communication_style
    if (body.goals !== undefined) updateData.goals = body.goals
    if (body.strengths !== undefined) updateData.strengths = body.strengths
    if (body.challenges !== undefined) updateData.challenges = body.challenges

    console.log('📝 Updating person with data:', JSON.stringify(updateData, null, 2))

    // Update the person
    const { data: person, error: updateError } = await supabase
      .from('people')
      .update(updateData)
      .eq('id', personId)
      .eq('user_id', user.id)
      .select()
      .single()

    if (updateError) {
      console.error('❌ Error updating person:', updateError)
      console.error('❌ Update error details:', JSON.stringify(updateError, null, 2))
      return new Response(JSON.stringify({ error: 'Failed to update person', details: updateError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('✅ Person updated successfully:', JSON.stringify(person, null, 2))
    return new Response(JSON.stringify({ person }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('❌ Unexpected error in handlePersonUpdate:', error)
    return new Response(JSON.stringify({ error: 'Internal server error', details: (error as any).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
}

async function handlePersonDelete(supabase: any, user: any, personId: string) {
  try {
    console.log(`🗑️ Starting person deletion for: ${personId}`)
    
    // Check if person exists and belongs to user
    const { data: person, error: fetchError } = await supabase
      .from('people')
      .select('id, name')
      .eq('id', personId)
      .eq('user_id', user.id)
      .single()

    if (fetchError || !person) {
      console.log(`❌ Person not found or fetch error:`, fetchError)
      return new Response(JSON.stringify({ error: 'Person not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log(`🗑️ Found person to delete: ${person.name} (${personId})`)

  // 1. Delete vector embeddings related to this person
  try {
    const { error: embeddingsError } = await supabase
      .from('embeddings')
      .delete()
      .eq('person_id', personId)
      .eq('user_id', user.id)

    if (embeddingsError) {
      console.warn('Error deleting embeddings:', embeddingsError)
      // Continue with deletion even if embeddings fail
    } else {
      console.log('Successfully deleted embeddings for person')
    }
  } catch (error) {
    console.warn('Failed to delete embeddings:', error)
  }

  // 2. Delete messages (should cascade but let's be explicit)
  try {
    const { error: messagesError } = await supabase
      .from('messages')
      .delete()
      .eq('person_id', personId)
      .eq('user_id', user.id)

    if (messagesError) {
      console.warn('Error deleting messages:', messagesError)
      // Continue with deletion even if messages fail
    } else {
      console.log('Successfully deleted messages for person')
    }
  } catch (error) {
    console.warn('Failed to delete messages:', error)
  }

  // 3. Delete the person record
  const { error: deleteError } = await supabase
    .from('people')
    .delete()
    .eq('id', personId)
    .eq('user_id', user.id)

  if (deleteError) {
    console.error('Error deleting person:', deleteError)
    return new Response(JSON.stringify({ error: 'Failed to delete person' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

    console.log(`✅ Successfully deleted person: ${person.name}`)
    
    const successResponse = { 
      success: true, 
      message: `Successfully deleted ${person.name} and all related data` 
    }
    
    console.log(`✅ Sending delete success response:`, JSON.stringify(successResponse, null, 2))
    return new Response(JSON.stringify(successResponse), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('❌ Unexpected error in handlePersonDelete:', error)
    return new Response(JSON.stringify({ error: 'Internal server error', details: (error as any).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
}

async function generateInitialMessage(params: {
  person: any
  context?: string
  current_situation?: string
  supabase: any
  user: any
}): Promise<string> {
  const { person, context, current_situation, supabase, user } = params

  // Calculate relationship duration if started_working_together is available
  let relationshipDuration = null
  if (person.started_working_together) {
    const startDate = new Date(person.started_working_together)
    const now = new Date()
    const diffYears = (now.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24 * 365.25)

    if (diffYears < 0.1) {
      relationshipDuration = "just started working together"
    } else if (diffYears < 0.5) {
      relationshipDuration = "a few months"
    } else if (diffYears < 1) {
      relationshipDuration = "about half a year"
    } else if (diffYears < 2) {
      relationshipDuration = "about a year"
    } else if (diffYears < 5) {
      relationshipDuration = `about ${Math.floor(diffYears)} years`
    } else {
      relationshipDuration = `over ${Math.floor(diffYears)} years`
    }
  }

  // Get user profile for personalization
  const { data: userProfile } = await supabase
    .from('user_profiles')
    .select('preferred_name, job_role, company')
    .eq('user_id', user.id)
    .single()

  // Get team size for context
  const { count: teamSize } = await supabase
    .from('people')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .eq('relationship_type', 'direct_report')

  // Create context for message generation
  const messageContext: InitialMessageContext = {
    person_name: person.name,
    relationship_type: person.relationship_type,
    role: person.role,
    team: person.team,
    context: context,
    current_situation: current_situation,
    user_name: userProfile?.preferred_name,
    existing_team_size: teamSize || 0
  }

  // Generate message using Claude
  const anthropic = new Anthropic({
    apiKey: Deno.env.get('ANTHROPIC_API_KEY')!
  })

  // Get user's name for personalization
  const userName = userProfile?.preferred_name || 'there'

  const systemPrompt = `You are Mano, a thought partner for managers. ${userName} just added ${messageContext.person_name} to their network.

Your job: Ask ONE direct, actionable question that helps ${userName} think through why this person is on their mind right now.

Be conversational but direct. 1-2 sentences maximum. No preamble or pleasantries.

Good examples:
- "What brings ${messageContext.person_name} to mind right now?"
- "What's the most important thing happening with ${messageContext.person_name} at the moment?"
- "What do you most need to figure out about working with ${messageContext.person_name}?"

Bad examples (too generic, too consultant-y):
- "I wanted to check in about ${messageContext.person_name}..."
- "How have you been working together?"
- "Let me know if you need anything..."`

  const userPrompt = `${userName} just added ${messageContext.person_name} (${messageContext.relationship_type}${messageContext.role ? `, ${messageContext.role}` : ''}).
${relationshipDuration ? `They've been working together for ${relationshipDuration}.` : ''}
${messageContext.context ? `Context: ${messageContext.context}` : ''}

Generate a direct opening question that helps ${userName} engage with why ${messageContext.person_name} is relevant right now.`

  try {
    const response = await anthropic.messages.create({
      model: 'claude-3-haiku-20240307',
      max_tokens: 200,
      temperature: 0.3,
      system: systemPrompt,
      messages: [{ role: 'user', content: userPrompt }]
    })

    return response.content[0].type === 'text' 
      ? response.content[0].text
      : `I see you've added ${person.name} to your team. What's the most important thing you'd like to work on with them?`
  } catch (error) {
    console.error('Error generating initial message:', error)
    // Fallback messages based on relationship type
    const fallbacks: Record<string, string> = {
      direct_report: `I see you've added ${person.name} to your team. What's the most important thing you'd like to work on with them?`,
      manager: `You've added ${person.name} as your manager. What kind of support are you looking for from them?`,
      peer: `I notice you're working with ${person.name}. What's your main collaboration focus with them?`,
      stakeholder: `You've added ${person.name} as a stakeholder. What outcomes do you need to align on with them?`
    }
    
    return fallbacks[person.relationship_type] || 
           `Tell me about ${person.name} - what would you like me to know about working with them?`
  }
}

async function handleInitialMessageGeneration(req: Request, supabase: any, user: any, personId: string) {
  const body = await req.json()
  
  // Get person details
  const { data: person, error } = await supabase
    .from('people')
    .select('*')
    .eq('id', personId)
    .eq('user_id', user.id)
    .single()

  if (error || !person) {
    return new Response(JSON.stringify({ error: 'Person not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  const initialMessage = await generateInitialMessage({
    person,
    context: body.context,
    current_situation: body.current_situation,
    supabase,
    user
  })

  return new Response(JSON.stringify({ 
    initialMessage,
    personId: person.id,
    personName: person.name
  }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
}

async function handlePersonAnalysis(req: Request, supabase: any, user: any, personId: string) {
  // Get person and their conversation history
  const { data: person } = await supabase
    .from('people')
    .select(`
      *,
      messages (
        content,
        is_user,
        created_at
      )
    `)
    .eq('id', personId)
    .eq('user_id', user.id)
    .single()

  if (!person) {
    return new Response(JSON.stringify({ error: 'Person not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Use Claude to analyze the conversation history and build profile
  const anthropic = new Anthropic({
    apiKey: Deno.env.get('ANTHROPIC_API_KEY')!
  })

  const conversationHistory = person.messages
    ?.map((m: any) => `${m.is_user ? 'Manager' : 'Mano'}: ${m.content}`)
    .join('\n\n') || 'No conversation history yet'

  const analysisPrompt = `Analyze this conversation history about ${person.name} (${person.role || 'role unknown'}, ${person.relationship_type}) and extract:

1. Work style and preferences
2. Communication patterns
3. Strengths observed
4. Growth areas or challenges
5. Key motivations
6. Recent achievements mentioned
7. Current focuses or projects

Conversation history:
${conversationHistory}

Provide a structured analysis in JSON format.`

  try {
    const response = await anthropic.messages.create({
      model: 'claude-3-haiku-20240307',
      max_tokens: 1000,
      temperature: 0.3,
      system: 'You are an expert at analyzing workplace conversations to understand people and relationships. Provide insights in JSON format.',
      messages: [{ role: 'user', content: analysisPrompt }]
    })

    const analysis = response.content[0].type === 'text' 
      ? JSON.parse(response.content[0].text)
      : {}

    // Store the analysis
    await supabase
      .from('person_profiles')
      .upsert({
        person_id: personId,
        user_id: user.id,
        ...analysis,
        last_analyzed: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })

    return new Response(JSON.stringify({ 
      analysis,
      messageCount: person.messages?.length || 0,
      lastConversation: person.messages?.[0]?.created_at
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Error analyzing person:', error)
    return new Response(JSON.stringify({ error: 'Analysis failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
}

async function handlePersonInsights(supabase: any, user: any, personId: string) {
  // Get person with profile and recent messages
  const { data: person } = await supabase
    .from('people')
    .select(`
      *,
      person_profiles (*),
      messages (
        content,
        is_user,
        created_at
      )
    `)
    .eq('id', personId)
    .eq('user_id', user.id)
    .order('messages.created_at', { ascending: false })
    .single()

  if (!person) {
    return new Response(JSON.stringify({ error: 'Person not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Calculate insights
  const insights = {
    conversationFrequency: calculateConversationFrequency(person.messages),
    topicsDiscussed: extractTopics(person.messages),
    relationshipHealth: assessRelationshipHealth(person),
    suggestedActions: generateSuggestedActions(person),
    profileCompleteness: calculateProfileCompleteness(person.person_profiles?.[0])
  }

  return new Response(JSON.stringify({ insights }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
}

async function handleSuggestedTopics(supabase: any, user: any, personId: string) {
  // Get person details and history
  const { data: person } = await supabase
    .from('people')
    .select(`
      *,
      person_profiles (*),
      messages (
        content,
        created_at
      )
    `)
    .eq('id', personId)
    .eq('user_id', user.id)
    .single()

  if (!person) {
    return new Response(JSON.stringify({ error: 'Person not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Generate suggested topics based on relationship type and history
  const topics = generateTopicSuggestions(person)

  return new Response(JSON.stringify({ 
    topics,
    personName: person.name,
    lastConversation: person.messages?.[0]?.created_at
  }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
}

async function handlePersonDetection(req: Request, supabase: any, user: any) {
  const { message } = await req.json()
  
  if (!message) {
    return new Response(JSON.stringify({ error: 'Message is required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Get existing people for this user
  const { data: existingPeople } = await supabase
    .from('people')
    .select('name')
    .eq('user_id', user.id)

  const existingNames = existingPeople?.map((p: any) => p.name.toLowerCase()) || []

  // Use Claude to detect people mentions
  const anthropic = new Anthropic({
    apiKey: Deno.env.get('ANTHROPIC_API_KEY')!
  })

  const detectionPrompt = `Detect any people mentioned in this message. Look for:
- Direct names (e.g., "John", "Sarah Chen")
- Role references that imply specific people (e.g., "my manager", "our designer")
- Team references (e.g., "the engineering team", "my directs")

Message: "${message}"

Existing people in the system: ${existingNames.join(', ') || 'None'}

Return a JSON array of detected people with:
- name: The person's name
- role: Their role if mentioned
- relationship_type: 'direct_report', 'manager', 'peer', or 'stakeholder'
- confidence: 'high', 'medium', or 'low'
- isNew: true if not in existing people list

Only return people who seem to be specific individuals, not generic references.`

  try {
    const response = await anthropic.messages.create({
      model: 'claude-3-haiku-20240307',
      max_tokens: 500,
      temperature: 0.3,
      system: 'You are an expert at detecting people mentions in workplace conversations. Return only valid JSON.',
      messages: [{ role: 'user', content: detectionPrompt }]
    })

    const detectedPeople = response.content[0].type === 'text' 
      ? JSON.parse(response.content[0].text)
      : []

    return new Response(JSON.stringify({ 
      detectedPeople,
      existingPeople: existingNames
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Error detecting people:', error)
    return new Response(JSON.stringify({ 
      detectedPeople: [],
      error: 'Detection failed' 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
}

// Helper functions
function calculateConversationFrequency(messages: any[]): string {
  if (!messages || messages.length === 0) return 'No conversations yet'
  
  const now = new Date()
  const lastMessage = new Date(messages[0].created_at)
  const daysSinceLastMessage = Math.floor((now.getTime() - lastMessage.getTime()) / (1000 * 60 * 60 * 24))
  
  if (daysSinceLastMessage === 0) return 'Today'
  if (daysSinceLastMessage === 1) return 'Yesterday'
  if (daysSinceLastMessage < 7) return `${daysSinceLastMessage} days ago`
  if (daysSinceLastMessage < 30) return `${Math.floor(daysSinceLastMessage / 7)} weeks ago`
  return `${Math.floor(daysSinceLastMessage / 30)} months ago`
}

function extractTopics(messages: any[]): string[] {
  // Simple topic extraction - in production this would be more sophisticated
  const topics = new Set<string>()
  
  const topicKeywords = {
    'performance': ['performance', 'review', 'feedback', 'improvement'],
    'career': ['career', 'growth', 'promotion', 'development'],
    'project': ['project', 'deadline', 'deliverable', 'milestone'],
    'team': ['team', 'collaboration', 'conflict', 'dynamics'],
    'personal': ['vacation', 'time off', 'personal', 'family']
  }
  
  messages?.forEach(msg => {
    const content = msg.content.toLowerCase()
    Object.entries(topicKeywords).forEach(([topic, keywords]) => {
      if (keywords.some(keyword => content.includes(keyword))) {
        topics.add(topic)
      }
    })
  })
  
  return Array.from(topics)
}

function assessRelationshipHealth(person: any): string {
  const messages = person.messages || []
  const profile = person.person_profiles?.[0]
  
  if (messages.length === 0) return 'No data'
  if (messages.length < 5) return 'Building'
  
  // Simple heuristic - in production this would be more sophisticated
  const hasRecentConversation = messages[0] && 
    new Date(messages[0].created_at) > new Date(Date.now() - 14 * 24 * 60 * 60 * 1000)
  const hasProfile = profile && (profile.strengths || profile.growth_areas)
  
  if (hasRecentConversation && hasProfile) return 'Strong'
  if (hasRecentConversation || hasProfile) return 'Good'
  return 'Needs attention'
}

function generateSuggestedActions(person: any): string[] {
  const suggestions = []
  const messages = person.messages || []
  const profile = person.person_profiles?.[0]
  
  if (messages.length === 0) {
    suggestions.push('Start your first conversation')
  } else {
    const lastMessage = new Date(messages[0].created_at)
    const daysSinceLastMessage = Math.floor((Date.now() - lastMessage.getTime()) / (1000 * 60 * 60 * 24))
    
    if (daysSinceLastMessage > 14) {
      suggestions.push('Schedule a check-in')
    }
  }
  
  if (!profile?.strengths) {
    suggestions.push('Discuss their strengths')
  }
  
  if (!profile?.growth_areas) {
    suggestions.push('Explore growth opportunities')
  }
  
  if (!profile?.career_goals) {
    suggestions.push('Talk about career aspirations')
  }
  
  return suggestions
}

function calculateProfileCompleteness(profile: any): number {
  if (!profile) return 0
  
  const fields = [
    'work_style',
    'communication_preferences',
    'motivations',
    'growth_areas',
    'strengths',
    'recent_achievements',
    'current_challenges',
    'career_goals'
  ]
  
  const filledFields = fields.filter(field => profile[field])
  return Math.round((filledFields.length / fields.length) * 100)
}

function generateTopicSuggestions(person: any): string[] {
  const suggestions = []
  const relationshipType = person.relationship_type
  const profile = person.person_profiles?.[0]
  const messages = person.messages || []
  
  // Base suggestions by relationship type
  const baseSuggestions: Record<string, string[]> = {
    direct_report: [
      'How are you progressing on your current goals?',
      'What support do you need from me this week?',
      'What wins should we celebrate?',
      'What challenges are you facing?'
    ],
    manager: [
      'What are your priorities for our team?',
      'How can I better support team objectives?',
      'What feedback do you have for me?',
      'What should I know about upcoming changes?'
    ],
    peer: [
      'How can we better collaborate?',
      'What dependencies do we need to discuss?',
      'How is your team doing?',
      'What best practices can we share?'
    ],
    stakeholder: [
      'What are your expectations for this project?',
      'How can we better align our efforts?',
      'What risks should we address?',
      'What success metrics matter most to you?'
    ],
    self: [
      'What am I feeling about my work right now?',
      'What patterns do I notice in my management style?',
      'What growth areas should I focus on?',
      'How am I balancing my priorities?',
      'What successes should I acknowledge?'
    ]
  }
  
  suggestions.push(...(baseSuggestions[relationshipType] || []))
  
  // Add personalized suggestions based on profile
  if (profile?.current_challenges) {
    suggestions.push(`Follow up on: ${profile.current_challenges}`)
  }
  
  if (profile?.recent_achievements) {
    suggestions.push('Recognize their recent achievement')
  }
  
  // Time-based suggestions
  const now = new Date()
  const quarter = Math.floor(now.getMonth() / 3)
  if (quarter === 3) { // Q4
    suggestions.push('Discuss year-end goals and next year planning')
  }
  
  return suggestions.slice(0, 5) // Return top 5 suggestions
}