# Mano Backend Test Suite

Comprehensive testing framework for Mano's Edge Functions and backend services.

## 🎯 Test Philosophy

**Backend = Foundation**: Test EVERYTHING. Aim for >80% coverage.
- Backend bugs affect ALL users
- Backend is our source of truth
- Comprehensive testing prevents production issues

## 📁 Directory Structure

```
tests/
├── unit/           # Pure unit tests with mocks (70% of tests)
│   ├── README.md   # Unit testing guidelines
│   └── *.test.ts   # Fast, isolated tests
│
├── integration/    # API endpoint tests with real DB (25% of tests)
│   ├── README.md   # Integration testing guidelines
│   ├── person.test.ts
│   ├── chat.test.ts
│   ├── create-embeddings.test.ts
│   ├── delete-account.test.ts
│   └── action-items-sync.test.ts
│
├── e2e/            # End-to-end user journeys (5% of tests)
│   └── README.md   # E2E testing guidelines
│
└── helpers/        # Shared utilities
    ├── README.md
    └── test-helpers.ts  # Mocks, factories, assertions
```

## 🚀 Quick Start

### Prerequisites
```bash
# 1. Start local Supabase
cd backend
supabase start

# 2. Seed test data
npm run seed:dev

# 3. Start Edge Functions (for integration/e2e tests)
supabase functions serve --env-file .env.local
```

### Running Tests
```bash
# Run all tests
npm run test

# Run by type
npm run test:unit           # Fast, no external dependencies
npm run test:integration    # Requires Supabase running
npm run test:e2e            # Full system tests

# Run specific test suites
npm run test:core           # Core functionality tests
npm run test:person         # Person management
npm run test:chat           # Chat and messaging
npm run test:embeddings     # Embedding generation
npm run test:delete-account # Account deletion
npm run test:action-items   # Action items sync

# Watch mode
npm run test:watch

# Coverage report
npm run test:coverage
```

## 📊 Test Pyramid

```
     ╱╲
    ╱E2E╲          5% - Critical user journeys
   ╱━━━━━━╲
  ╱ Integration╲   25% - API endpoints with real DB
 ╱━━━━━━━━━━━━━━╲
╱     Unit       ╲ 70% - Pure functions with mocks
━━━━━━━━━━━━━━━━━━
```

### Unit Tests (70%)
- **Purpose**: Test business logic in isolation
- **Speed**: Fast (<1s per test file)
- **Dependencies**: All mocked
- **Coverage**: >80% of code

### Integration Tests (25%)
- **Purpose**: Test HTTP endpoints with real database
- **Speed**: Medium (requires Supabase)
- **Dependencies**: Real local Supabase, mocked external APIs
- **Coverage**: All Edge Function endpoints

### E2E Tests (5%)
- **Purpose**: Test complete user workflows
- **Speed**: Slow (full system)
- **Dependencies**: Everything running
- **Coverage**: Critical paths only

## 🧪 Test Coverage

### Current Coverage

| Edge Function | Unit Tests | Integration Tests | E2E Tests |
|---------------|------------|-------------------|-----------|
| chat | ⏳ Pending | ✅ Complete | ⏳ Pending |
| person | ✅ Complete | ✅ Complete | ⏳ Pending |
| create-embeddings | ⏳ Pending | ✅ Complete | - |
| delete-account | ⏳ Pending | ✅ Complete | ⏳ Pending |
| action-items-sync | ⏳ Pending | ✅ Complete | - |
| profile-update | ⏳ Pending | ⏳ Pending | - |
| profile-get | ⏳ Pending | ⏳ Pending | - |
| generate-conversation-title | ⏳ Pending | ⏳ Pending | - |
| user-profile-foundation | ⏳ Pending | ⏳ Pending | - |

**Legend**: ✅ Complete | ⏳ Pending | - Not Needed

## 📝 Writing Tests

### Example Unit Test
```typescript
import { assertEquals } from "@std/assert";
import { MockSupabaseClient, createTestUser } from "@test-helpers";

Deno.test("Person Creation", async (t) => {
  await t.step("should create person with valid data", async () => {
    const mockClient = new MockSupabaseClient();
    mockClient.setMockUser(createTestUser());

    const person = await createPerson(mockClient, {
      name: "Alice",
      relationship_type: "direct_report"
    });

    assertEquals(person.name, "Alice");
  });
});
```

### Example Integration Test
```typescript
import { assertEquals } from "@std/assert";
import { makeTestRequest } from "@test-helpers";

Deno.test("Person API", async (t) => {
  await t.step("should create person via API", async () => {
    const response = await makeTestRequest('/person', 'POST', {
      name: "Alice",
      relationship_type: "direct_report"
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.name, "Alice");
  });
});
```

## 🎨 Test Helpers

Available in `tests/helpers/test-helpers.ts`:

### Mocks
- `MockSupabaseClient` - Mock Supabase for unit tests
- `MockAnthropicAPI` - Mock Anthropic AI for unit tests

### Factories
- `createTestUser()` - Create test user object
- `createTestPerson()` - Create test person object
- `createTestMessage()` - Create test message object

### Utilities
- `makeTestRequest()` - Make HTTP requests to Edge Functions
- `assertValidPerson()` - Assert person object is valid
- `assertValidMessage()` - Assert message object is valid

## 🔧 Configuration

Configuration is in `tests/deno.json`:
- Test tasks (test, test:unit, test:integration, test:e2e)
- Import mappings (@test-helpers, @std/assert, etc.)
- Environment variables for local Supabase

## 📚 Best Practices

1. **Test Names**: Use descriptive names with "should" statements
2. **Arrange-Act-Assert**: Structure tests clearly
3. **One Assertion Per Test**: Keep tests focused
4. **Mock External Dependencies**: In unit tests, mock everything
5. **Clean Up**: Tests should not leave data behind
6. **Fast Tests**: Unit tests should be <1s, integration <5s
7. **Independent Tests**: Tests should not depend on each other
8. **Coverage**: Aim for >80% on backend code

## 🚨 Troubleshooting

### Tests Failing Locally
```bash
# 1. Ensure Supabase is running
supabase status

# 2. Reset and seed database
npm run reset
npm run seed:dev

# 3. Restart Edge Functions
supabase functions serve --env-file .env.local

# 4. Run tests again
npm run test
```

### Integration Tests Timing Out
- Ensure Edge Functions are running
- Check Supabase is accessible at http://127.0.0.1:54321
- Increase timeout in test if needed

### Mock Not Working
- Check you're importing from @test-helpers
- Verify mock setup is correct
- Ensure you're using mocks in unit tests, not integration tests

## 📖 Further Reading

- [Backend Testing Guidelines](./unit/README.md)
- [Integration Testing Guidelines](./integration/README.md)
- [E2E Testing Guidelines](./e2e/README.md)
- [Test Helpers Documentation](./helpers/README.md)
- [CLAUDE.md - Testing Section](../../CLAUDE.md#testing-standards--development-workflow)
