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

  // Only allow DELETE method
  if (req.method !== 'DELETE') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  try {
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

    // Create client with user's token to verify they're authenticated
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    // Get current user
    const { data: { user }, error: userError } = await userClient.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Authentication failed' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`🗑️ Deleting account for user: ${user.id}`)

    // Create admin client with service role key
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Step 1: Delete storage files first (not cascade deleted automatically)
    try {
      const userFolder = `${user.id}`
      console.log(`🗑️ Deleting storage files for user: ${userFolder}`)

      // List all files in user's folder
      const { data: files, error: listError } = await adminClient
        .storage
        .from('message-attachments')
        .list(userFolder)

      if (listError) {
        console.warn('Warning: Could not list storage files:', listError)
      } else if (files && files.length > 0) {
        // Delete all files in user's folder
        const filePaths = files.map(file => `${userFolder}/${file.name}`)
        const { error: deleteFilesError } = await adminClient
          .storage
          .from('message-attachments')
          .remove(filePaths)

        if (deleteFilesError) {
          console.warn('Warning: Could not delete some storage files:', deleteFilesError)
        } else {
          console.log(`✅ Deleted ${files.length} storage files`)
        }
      }
    } catch (storageError) {
      console.warn('Warning: Storage cleanup failed:', storageError)
      // Continue with user deletion even if storage cleanup fails
    }

    // Step 2: Delete user using admin client
    // This will cascade delete all related database data:
    // - user_profiles (cascade)
    // - people (cascade)
    // - conversations (cascade via people)
    // - messages (cascade)
    // - message_files (cascade)
    // - topics (cascade after migration)
    // - conversation_embeddings (cascade)
    // - conversation_summary_embeddings (cascade)
    // - recurring_patterns (cascade)
    // - cross_conversation_connections (cascade)
    // - action_items (cascade)
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id)

    if (deleteError) {
      console.error('Error deleting user:', deleteError)
      throw deleteError
    }

    console.log(`✅ Successfully deleted account for user: ${user.id}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Account successfully deleted'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in delete-account function:', error)
    return new Response(
      JSON.stringify({ error: (error as any).message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
