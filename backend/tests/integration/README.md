# Integration Tests

Tests that verify Edge Functions work correctly with real Supabase (local) but may mock external APIs.

## Purpose
- Test HTTP endpoints and API contracts
- Verify database interactions work correctly
- Test with real local Supabase instance
- May mock external APIs (Anthropic) for speed/reliability

## Structure
```
integration/
├── chat.test.ts                    # Test /chat endpoint
├── person.test.ts                  # Test /person endpoint
├── action-items-sync.test.ts       # Test /action-items-sync endpoint
├── create-embeddings.test.ts       # Test /create-embeddings endpoint
└── delete-account.test.ts          # Test /delete-account endpoint
```

## Example Test
```typescript
import { assertEquals, assertExists } from "@std/assert";
import { makeTestRequest } from "@test-helpers";

Deno.test("Chat API", async (t) => {
  await t.step("should create streaming response", async () => {
    const response = await makeTestRequest('/chat', 'POST', {
      message: 'Hello',
      person_id: 'test-person-id'
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertExists(response.data);
  });
});
```

## Prerequisites
- Local Supabase must be running: `supabase start`
- Edge Functions must be running: `supabase functions serve --env-file .env.local`
- Test data seeded: `npm run seed:dev`

## Running Integration Tests
```bash
cd backend
deno task test:integration
```
