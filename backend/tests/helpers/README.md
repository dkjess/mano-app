# Test Helpers

Shared utilities and helpers for testing Mano backend Edge Functions.

## Files

- `test-helpers.ts` - Core test utilities including:
  - Mock Anthropic API
  - Mock Supabase Client
  - Test data factories (createTestUser, createTestPerson, etc.)
  - HTTP request helpers
  - Assertion helpers
  - Test environment setup/teardown

## Usage

```typescript
import {
  MockAnthropicAPI,
  MockSupabaseClient,
  createTestUser,
  createTestPerson,
  makeTestRequest,
  assertValidPerson
} from '../helpers/test-helpers.ts';

// In your test:
const mockClient = new MockSupabaseClient();
mockClient.setMockUser(createTestUser());
mockClient.setMockData('people', [createTestPerson()]);

// Test your function with mocks
const result = await yourFunction(mockClient);
assertValidPerson(result);
```

## Mock vs Integration Tests

- **Use mocks** (MockSupabaseClient, MockAnthropicAPI) for **unit tests** in `tests/unit/`
- **Use real clients** (makeTestRequest) for **integration tests** in `tests/integration/`
- **Use full E2E** for **end-to-end tests** in `tests/e2e/`
