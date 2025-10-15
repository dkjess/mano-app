# Unit Tests

Pure unit tests that test individual functions and modules in isolation using mocks.

## Purpose
- Test business logic without external dependencies
- Fast execution (no network calls, no database)
- Use mocks for Supabase, Anthropic, and other external services
- Aim for >80% code coverage

## Structure
```
unit/
├── chat/
│   ├── coaching-strategy.test.ts    # Test coaching algorithm
│   ├── prompt-composer.test.ts      # Test prompt generation
│   └── profile-intelligence.test.ts # Test profile extraction
├── person/
│   ├── person-creation.test.ts      # Test person creation logic
│   └── person-detection.test.ts     # Test person detection
└── ...
```

## Example Test
```typescript
import { assertEquals } from "@std/assert";
import { MockSupabaseClient, createTestUser } from "@test-helpers";

Deno.test("Feature Name", async (t) => {
  await t.step("should handle specific scenario", async () => {
    const mockClient = new MockSupabaseClient();
    mockClient.setMockUser(createTestUser());

    const result = await functionUnderTest(mockClient);

    assertEquals(result.success, true);
  });
});
```

## Running Unit Tests
```bash
cd backend
deno task test:unit
```
