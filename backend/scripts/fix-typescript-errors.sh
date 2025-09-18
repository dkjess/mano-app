#!/bin/bash

# Fix TypeScript errors in Edge Functions for Deno v2 compatibility
# Changes error handling to properly type unknown errors

echo "Fixing TypeScript errors in Edge Functions..."

# Fix create-embeddings function
sed -i '' "s/error\.message/(error as any).message/g" supabase/functions/create-embeddings/index.ts

# Fix person function
sed -i '' "s/error\.message/(error as any).message/g" supabase/functions/person/index.ts

# Fix profile-get function
sed -i '' "s/error\.message/(error as any).message/g" supabase/functions/profile-get/index.ts

# Fix profile-update function
sed -i '' "s/error\.message/(error as any).message/g" supabase/functions/profile-update/index.ts

# Fix test-openai function
sed -i '' "s/fetchError\.name/(fetchError as any).name/g" supabase/functions/test-openai/index.ts
sed -i '' "s/fetchError\.message/(fetchError as any).message/g" supabase/functions/test-openai/index.ts
sed -i '' "s/error\.message/(error as any).message/g" supabase/functions/test-openai/index.ts

# Fix user-profile-foundation function
sed -i '' "s/error\.message/(error as any).message/g" supabase/functions/user-profile-foundation/index.ts

# Fix chat function
sed -i '' "s/error\.message/(error as any).message/g" supabase/functions/chat/index.ts

echo "TypeScript errors fixed!"