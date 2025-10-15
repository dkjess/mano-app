# End-to-End Tests

Complete user journey tests that verify the entire system works together (backend + iOS app).

## Purpose
- Test critical user workflows end-to-end
- Verify iOS app can communicate with backend
- Test real-world scenarios
- Run before major releases

## Structure
```
e2e/
├── onboarding-flow.test.ts        # Test user signup → first message
├── conversation-flow.test.ts      # Test creating person → chatting → pinning advice
└── delete-account-flow.test.ts    # Test account deletion cascade
```

## Example Test
```typescript
import { assertEquals, assertExists } from "@std/assert";

Deno.test("Onboarding Flow", async (t) => {
  await t.step("User can sign up and create first person", async () => {
    // 1. Create user account
    // 2. Create first person
    // 3. Verify welcome message generated
    // 4. Send first user message
    // 5. Verify AI response received
  });
});
```

## Prerequisites
- Local Supabase running
- Edge Functions running
- Clean test database
- ngrok tunnel for device testing (optional)

## Running E2E Tests
```bash
cd backend
deno task test:e2e
```

## Notes
- E2E tests are slower - run sparingly
- Focus on happy paths and critical failures
- Should cover <5% of total test cases
- Can be run manually before releases
