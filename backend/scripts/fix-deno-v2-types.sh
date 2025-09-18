#!/bin/bash

echo "Fixing Deno v2 TypeScript errors comprehensively..."

# Fix all error handling - wrap error access with (error as any)
find supabase/functions -name "*.ts" -type f -exec sed -i '' \
  -e 's/error\.message/(error as any).message/g' \
  -e 's/error\.stack/(error as any).stack/g' \
  -e 's/error\.name/(error as any).name/g' \
  -e 's/fetchError\.message/(fetchError as any).message/g' \
  -e 's/fetchError\.name/(fetchError as any).name/g' \
  -e 's/fetchError\.stack/(fetchError as any).stack/g' \
  -e 's/attachmentError\.stack/(attachmentError as any).stack/g' \
  -e 's/embeddingError\.name/(embeddingError as any).name/g' \
  -e 's/embeddingError\.message/(embeddingError as any).message/g' \
  -e 's/vectorError\.name/(vectorError as any).name/g' \
  -e 's/vectorError\.message/(vectorError as any).message/g' {} \;

# Fix ContentBlock text access with type assertion
find supabase/functions -name "*.ts" -type f -exec sed -i '' \
  -e "s/textContent\.text/(textContent as any).text/g" \
  -e "s/textContent?.text/(textContent as any)?.text/g" {} \;

# Fix implicit any in arrow functions
find supabase/functions -name "*.ts" -type f -exec sed -i '' \
  -e 's/\.map(m =>/\.map((m: any) =>/g' \
  -e 's/\.map(p =>/\.map((p: any) =>/g' \
  -e 's/\.filter(msg =>/\.filter((msg: any) =>/g' \
  -e 's/\.filter(person =>/\.filter((person: any) =>/g' \
  -e 's/\.filter(conv =>/\.filter((conv: any) =>/g' \
  -e 's/\.find(p =>/\.find((p: any) =>/g' \
  -e 's/\.sort((a, b)/\.sort((a: any, b: any)/g' \
  -e 's/\.some(f =>/\.some((f: any) =>/g' {} \;

# Fix globalThis type issues - cast to any
find supabase/functions -name "*.ts" -type f -exec sed -i '' \
  -e 's/globalThis\.vectorEmbeddingSession/(globalThis as any).vectorEmbeddingSession/g' \
  -e 's/globalThis\.embeddingSession/(globalThis as any).embeddingSession/g' {} \;

# Fix Supabase namespace reference
find supabase/functions -name "*.ts" -type f -exec sed -i '' \
  -e 's/new Supabase\.ai\.Session/new (Supabase as any).ai.Session/g' {} \;

echo "Deno v2 TypeScript errors fixed!"