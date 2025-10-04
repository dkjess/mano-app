#!/usr/bin/env -S deno run --allow-net --allow-env

/**
 * Smoke tests to verify critical functionality after deployment
 * Run against staging or production to ensure basic functionality works
 */

const BASE_URL = Deno.args[0] || 'http://127.0.0.1:54321';
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

console.log('🧪 Running smoke tests against:', BASE_URL);
console.log('');

let exitCode = 0;

async function test(name: string, fn: () => Promise<void>) {
  try {
    await fn();
    console.log(`✅ ${name}`);
  } catch (error) {
    console.error(`❌ ${name}`);
    console.error(`   Error: ${error.message}`);
    exitCode = 1;
  }
}

// Test 1: Edge Functions are responding
await test('Edge Functions endpoint is accessible', async () => {
  const response = await fetch(`${BASE_URL}/functions/v1/`, {
    headers: { 'apikey': ANON_KEY }
  });

  if (!response.ok && response.status !== 404) {
    throw new Error(`Functions endpoint returned ${response.status}`);
  }
});

// Test 2: Database is accessible via REST API
await test('Database REST API is accessible', async () => {
  const response = await fetch(`${BASE_URL}/rest/v1/`, {
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json'
    }
  });

  if (!response.ok && response.status !== 404) {
    throw new Error(`REST API returned ${response.status}`);
  }
});

// Test 3: Auth endpoint is working
await test('Auth endpoint is accessible', async () => {
  const response = await fetch(`${BASE_URL}/auth/v1/health`, {
    headers: { 'apikey': ANON_KEY }
  });

  if (!response.ok) {
    throw new Error(`Auth health check failed with ${response.status}`);
  }
});

// Test 4: Person function exists
await test('Person function is deployed', async () => {
  const response = await fetch(`${BASE_URL}/functions/v1/person`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({})
  });

  // Should fail with 400/401 (not authenticated), not 404 (not found)
  if (response.status === 404) {
    throw new Error('Person function not found');
  }
});

// Test 5: Chat function exists
await test('Chat function is deployed', async () => {
  const response = await fetch(`${BASE_URL}/functions/v1/chat`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({})
  });

  // Should fail with 400/401 (not authenticated), not 404 (not found)
  if (response.status === 404) {
    throw new Error('Chat function not found');
  }
});

console.log('');
if (exitCode === 0) {
  console.log('🎉 All smoke tests passed!');
} else {
  console.log('💥 Some smoke tests failed');
}

Deno.exit(exitCode);
