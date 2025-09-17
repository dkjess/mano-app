import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ActionItem {
  id?: string
  person_id?: string
  content: string
  is_completed: boolean
  is_hidden: boolean
  position_in_profile?: string
}

interface SyncRequest {
  person_id: string
  action_items: ActionItem[]
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get user from JWT
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (req.method === 'GET') {
      // Get action items for a person
      const url = new URL(req.url)
      const person_id = url.searchParams.get('person_id')

      if (!person_id) {
        return new Response(
          JSON.stringify({ error: 'person_id is required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const { data: items, error } = await supabaseClient
        .from('action_items')
        .select('*')
        .eq('person_id', person_id)
        .eq('created_by', user.id)
        .order('created_at', { ascending: true })

      if (error) {
        console.error('Error fetching action items:', error)
        return new Response(
          JSON.stringify({ error: 'Failed to fetch action items' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      return new Response(
        JSON.stringify({ action_items: items }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (req.method === 'POST') {
      // Sync action items (create/update/delete)
      const { person_id, action_items }: SyncRequest = await req.json()

      if (!person_id || !action_items) {
        return new Response(
          JSON.stringify({ error: 'person_id and action_items are required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Get existing action items for this person
      const { data: existingItems, error: fetchError } = await supabaseClient
        .from('action_items')
        .select('id, content, is_completed, is_hidden')
        .eq('person_id', person_id)
        .eq('created_by', user.id)

      if (fetchError) {
        console.error('Error fetching existing items:', fetchError)
        return new Response(
          JSON.stringify({ error: 'Failed to fetch existing items', details: fetchError }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const existingIds = new Set(existingItems?.map(item => item.id) || [])
      const incomingIds = new Set(action_items.filter(item => item.id).map(item => item.id))

      // Items to delete (exist in DB but not in incoming)
      const itemsToDelete = existingItems?.filter(item => !incomingIds.has(item.id)) || []

      // Items to create (no ID)
      const itemsToCreate = action_items.filter(item => !item.id)

      // Items to update (have ID and exist in DB)
      const itemsToUpdate = action_items.filter(item => item.id && existingIds.has(item.id))

      const operations = []

      // Delete items
      if (itemsToDelete.length > 0) {
        const deleteIds = itemsToDelete.map(item => item.id)
        operations.push(
          supabaseClient
            .from('action_items')
            .delete()
            .in('id', deleteIds)
            .eq('created_by', user.id)
        )
      }

      // Create new items
      if (itemsToCreate.length > 0) {
        const newItems = itemsToCreate.map(item => ({
          person_id,
          content: item.content,
          is_completed: item.is_completed,
          is_hidden: item.is_hidden,
          position_in_profile: item.position_in_profile,
          created_by: user.id,
          completed_at: item.is_completed ? new Date().toISOString() : null,
        }))

        operations.push(
          supabaseClient
            .from('action_items')
            .insert(newItems)
        )
      }

      // Update existing items
      for (const item of itemsToUpdate) {
        const existingItem = existingItems?.find(existing => existing.id === item.id)
        const wasCompleted = existingItem?.is_completed
        const isNowCompleted = item.is_completed

        operations.push(
          supabaseClient
            .from('action_items')
            .update({
              content: item.content,
              is_completed: item.is_completed,
              is_hidden: item.is_hidden,
              position_in_profile: item.position_in_profile,
              completed_at: !wasCompleted && isNowCompleted ? new Date().toISOString() : 
                           wasCompleted && !isNowCompleted ? null : 
                           existingItem?.completed_at,
              hidden_at: !existingItem?.is_hidden && item.is_hidden ? new Date().toISOString() : 
                        existingItem?.is_hidden && !item.is_hidden ? null :
                        existingItem?.hidden_at,
            })
            .eq('id', item.id)
            .eq('created_by', user.id)
        )
      }

      // Execute all operations
      const results = await Promise.all(operations)
      
      // Check for errors
      const errors = results.filter(result => result.error).map(result => result.error)
      if (errors.length > 0) {
        console.error('Sync errors:', errors)
        return new Response(
          JSON.stringify({ error: 'Failed to sync some items', details: errors }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      return new Response(
        JSON.stringify({ success: true, synced: action_items.length }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Action items sync error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})