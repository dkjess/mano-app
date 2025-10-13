#!/usr/bin/env -S deno run --allow-net --allow-env

/**
 * Test streaming response with markdown formatting
 * Verifies that chunks are word-complete and markdown is preserved
 */

const FUNCTION_URL = 'http://127.0.0.1:54321/functions/v1/chat';

// Test user token (dev@mano.local) - get fresh token with: ./scripts/get-fresh-token.sh
const TEST_USER_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwOi8vMTI3LjAuMC4xOjU0MzIxL2F1dGgvdjEiLCJzdWIiOiIwMzBlNTE4NS01Nzk2LTQ5ODUtOWEwNy1lNmI4MTBjYjNhYmUiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzYwMzg3NzM0LCJpYXQiOjE3NjAzODQxMzQsImVtYWlsIjoiZGV2QG1hbm8ubG9jYWwiLCJwaG9uZSI6IiIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIiwicHJvdmlkZXJzIjpbImVtYWlsIl19LCJ1c2VyX21ldGFkYXRhIjp7ImVtYWlsIjoiZGV2QG1hbm8ubG9jYWwiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwicGhvbmVfdmVyaWZpZWQiOmZhbHNlLCJzdWIiOiIwMzBlNTE4NS01Nzk2LTQ5ODUtOWEwNy1lNmI4MTBjYjNhYmUifSwicm9sZSI6ImF1dGhlbnRpY2F0ZWQiLCJhYWwiOiJhYWwxIiwiYW1yIjpbeyJtZXRob2QiOiJwYXNzd29yZCIsInRpbWVzdGFtcCI6MTc2MDM4NDEzNH1dLCJzZXNzaW9uX2lkIjoiMWFhMTkxZWYtZTg1YS00MzhmLTgzNTktMTU3MDJhMmY3YTQzIiwiaXNfYW5vbnltb3VzIjpmYWxzZX0.DA9bXhyWAgcVcBy0WW_C0RZ5B56gK_egqRA-XlAEeyA";

async function testStreaming() {
  console.log('🧪 Testing streaming with markdown formatting\n');

  // First, get a person_id to send messages to
  console.log('📋 Fetching people...');
  const peopleResponse = await fetch('http://127.0.0.1:54321/rest/v1/people?select=id,name,is_self', {
    headers: {
      'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
      'Authorization': `Bearer ${TEST_USER_TOKEN}`,
    },
  });

  const people = await peopleResponse.json();
  if (!people || people.length === 0) {
    console.error('❌ No people found. Run npm run seed:dev first.');
    return;
  }

  const personId = people[0].id;
  console.log(`✅ Using person: ${people[0].name} (${personId})\n`);

  const testMessage = "Give me a brief example response with **bold text**, *italics*, and a `code snippet`. Keep it short.";

  console.log(`📤 Sending: "${testMessage}"\n`);

  const response = await fetch(FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${TEST_USER_TOKEN}`,
    },
    body: JSON.stringify({
      person_id: personId,
      message: testMessage,
    }),
  });

  console.log('📊 Response:', response.status, response.statusText);
  const headers = Object.fromEntries(response.headers.entries());
  console.log('📋 Content-Type:', headers['content-type']);

  if (!response.ok) {
    console.error('❌ Request failed:', response.status, response.statusText);
    const error = await response.text();
    console.error('Error:', error);
    return;
  }

  // If it's JSON instead of SSE, the response was buffered
  if (headers['content-type']?.includes('application/json')) {
    const json = await response.json();
    console.log('⚠️  Response was buffered as JSON (not streaming)');
    console.log('Response:', JSON.stringify(json, null, 2));
    return;
  }

  console.log('📥 Receiving chunks:\n');
  console.log('─'.repeat(60));

  const reader = response.body?.getReader();
  const decoder = new TextDecoder();

  let chunkCount = 0;
  let fullText = '';
  let hasSplitWords = false;
  let buffer = '';

  if (reader) {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');

      // Keep the last incomplete line in buffer
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          try {
            const jsonStr = line.slice(6);
            if (jsonStr.trim() === '[DONE]') continue;

            const data = JSON.parse(jsonStr);

            if (data.content) {
              chunkCount++;
              fullText += data.content;

              // Check if chunk looks like a split word (no spaces, very short)
              const isSuspicious = data.content.length <= 3 && !data.content.includes(' ') && !/[.,!?]/.test(data.content);

              console.log(`Chunk ${chunkCount}: "${data.content}" ${isSuspicious ? '⚠️  (suspicious)' : '✅'}`);

              if (isSuspicious) {
                hasSplitWords = true;
              }
            }
          } catch (e) {
            // Skip invalid JSON lines
          }
        }
      }
    }
  }

  console.log('─'.repeat(60));
  console.log('\n📝 Complete response:');
  console.log(fullText);
  console.log('\n📊 Results:');
  console.log(`  Total chunks: ${chunkCount}`);
  console.log(`  Split words detected: ${hasSplitWords ? '❌ YES (needs fixing)' : '✅ NO (good!)'}`);
  console.log(`  Markdown preserved: ${fullText.includes('**') && fullText.includes('*') && fullText.includes('`') ? '✅ YES' : '❌ NO'}`);
}

testStreaming().catch(console.error);
