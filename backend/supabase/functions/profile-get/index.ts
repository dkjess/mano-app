import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Anthropic } from 'https://esm.sh/@anthropic-ai/sdk@0.24.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Get person_id from query params
    const url = new URL(req.url)
    const personId = url.searchParams.get('person_id')
    
    if (!personId) {
      return new Response(
        JSON.stringify({ error: 'person_id parameter is required' }),
        { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Create Supabase client with user's auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Authorization header is required' }),
        { 
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    // Check if profile exists
    const { data: existingProfile, error: fetchError } = await supabase
      .from('person_profiles')
      .select('*')
      .eq('person_id', personId)
      .single()

    if (fetchError && fetchError.code !== 'PGRST116') { // PGRST116 = not found
      throw fetchError
    }

    // If profile doesn't exist, create it with AI-generated content
    if (!existingProfile) {
      let content = '';
      
      try {
        // Get person data to generate contextual profile
        const { data: personData } = await supabase
          .from('people')
          .select('*')
          .eq('id', personId)
          .single();

        if (personData) {
          // Get user's context for better profile generation
          const { data: userProfile } = await supabase
            .from('user_profiles')
            .select('call_name, job_role, company')
            .eq('user_id', personData.user_id)
            .single();

          // Get user ID for auth context
          const { data: { user } } = await supabase.auth.getUser();
          
          if (user) {
            // Get management context for personalized profile generation
            const { data: teamMembers } = await supabase
              .from('people')
              .select('name, role, relationship_type')
              .eq('user_id', user.id)
              .neq('id', personId)
              .limit(10);

            const anthropic = new Anthropic({
              apiKey: Deno.env.get('ANTHROPIC_API_KEY')!,
            });

            const teamContext = teamMembers && teamMembers.length > 0 
              ? `Team context: ${teamMembers.map(p => `${p.name} (${p.role || 'role unknown'}, ${p.relationship_type})`).join(', ')}`
              : 'First team member being added';

            const managerContext = userProfile?.call_name 
              ? `Manager: ${userProfile.call_name}${userProfile.job_role ? `, ${userProfile.job_role}` : ''}${userProfile.company ? ` at ${userProfile.company}` : ''}`
              : 'Manager context not available';

            const prompt = `You are generating an initial AI profile for a team member that a manager is tracking. This profile will help the manager have better conversations and provide more personalized management advice.

**Person Details:**
- Name: ${personData.name}
- Role: ${personData.role || 'Not specified'}
- Relationship: ${personData.relationship_type}
- ${managerContext}
- ${teamContext}

**Profile Purpose:**
This profile serves as initial context for AI conversations about this person. It should help the AI assistant provide relevant management advice and ask better questions during future conversations.

**Instructions:**
Generate a concise initial profile (100-150 words) that:
1. **Acknowledges their role and relationship** in a management context
2. **Suggests potential areas of focus** based on their relationship type and role
3. **Identifies likely management challenges or opportunities** that might arise
4. **Provides context for future conversations** about their development, performance, or collaboration

**Relationship-specific focus:**
- direct_report: Development opportunities, performance management, career growth potential
- manager: Managing up strategies, communication preferences, alignment approaches  
- peer: Collaboration opportunities, shared challenges, mutual support
- stakeholder: Project coordination, communication cadence, success metrics

Write in a professional, helpful tone that provides useful context for management conversations. Focus on actionable insights that will help the manager have better conversations about this person.`;

            const response = await anthropic.messages.create({
              model: 'claude-sonnet-4-20250514',
              max_tokens: 400,
              system: prompt,
              messages: [
                {
                  role: 'user',
                  content: `Generate the initial AI profile for ${personData.name}.`
                }
              ]
            });

            const textContent = response.content.find(block => block.type === 'text');
            if (textContent?.text) {
              content = textContent.text;
              console.log('✅ Generated AI profile for:', personData.name);
            }
          }
        }
      } catch (aiError) {
        console.error('⚠️ AI profile generation failed:', aiError);
        // Continue with empty profile if AI generation fails
      }

      const { data: newProfile, error: createError } = await supabase
        .from('person_profiles')
        .insert({ 
          person_id: personId,
          content: content
        })
        .select()
        .single()

      if (createError) throw createError

      return new Response(
        JSON.stringify(newProfile),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 201
        }
      )
    }

    // Return existing profile
    return new Response(
      JSON.stringify(existingProfile),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in profile-get function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})