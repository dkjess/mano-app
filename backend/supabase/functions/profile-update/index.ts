import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  // Only allow PUT method
  if (req.method !== 'PUT') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  try {
    // Parse request body
    const body = await req.json()
    const { person_id, content } = body

    if (!person_id) {
      return new Response(
        JSON.stringify({ error: 'person_id is required' }),
        { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (typeof content !== 'string') {
      return new Response(
        JSON.stringify({ error: 'content must be a string' }),
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

    // Try to update existing profile
    const { data: updatedProfile, error: updateError } = await supabase
      .from('person_profiles')
      .update({ 
        content,
        updated_at: new Date().toISOString()
      })
      .eq('person_id', person_id)
      .select()
      .single()

    // If profile doesn't exist, create it
    if (updateError && updateError.code === 'PGRST116') {
      const { data: newProfile, error: createError } = await supabase
        .from('person_profiles')
        .insert({ 
          person_id,
          content
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

    if (updateError) throw updateError

    return new Response(
      JSON.stringify(updatedProfile),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in profile-update function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})