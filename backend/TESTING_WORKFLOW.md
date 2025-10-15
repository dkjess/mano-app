# Testing Workflow Guide

**When to run tests, how to run them, and when to update them.**

## 🎯 Quick Reference

### When Working on Code

| Situation | Tests to Run | Command |
|-----------|-------------|---------|
| **Before starting work** | None | Just code! |
| **After writing new function** | Unit tests for that function | `npm run test:unit` |
| **After changing API endpoint** | Integration test for that endpoint | `npm run test:<function-name>` |
| **Before committing** | Core tests | `npm run test:core` |
| **Before creating PR** | All tests | `npm run test` |
| **After merge conflicts** | All tests | `npm run test` |

### When to Update Tests

| Change Type | What to Update |
|-------------|----------------|
| **New Edge Function** | Create unit + integration tests |
| **Changed Edge Function logic** | Update unit tests |
| **Changed API contract** | Update integration tests |
| **New onboarding step** | Update E2E onboarding test |
| **Changed database schema** | Update test data factories |
| **Fixed a bug** | Add regression test |

## 📋 Detailed Workflows

### 1. Daily Development Workflow

```bash
# Morning: Start your day
cd backend
supabase start
npm run seed:dev
supabase functions serve --env-file .env.local

# Work on your feature
# ... make changes to code ...

# Quick check: Run unit tests (fast, <1s)
npm run test:unit

# Full check: Run integration tests when you touch APIs
npm run test:integration

# Before committing: Run core tests
npm run test:core
```

### 2. Creating a New Edge Function

**Example**: Creating `profile-analytics` function

```bash
# 1. Create the function
mkdir -p supabase/functions/profile-analytics
# ... write function code ...

# 2. Create unit tests
touch tests/unit/profile-analytics.test.ts
# ... write unit tests for business logic ...

# 3. Run unit tests
npm run test:unit

# 4. Create integration tests
touch tests/integration/profile-analytics.test.ts
# ... write integration tests for API endpoint ...

# 5. Run integration tests
npm run test:integration

# 6. Add to package.json scripts
# Add: "test:profile-analytics": "cd tests && deno test --allow-all integration/profile-analytics.test.ts"

# 7. Run all tests
npm run test

# 8. Commit (tests will run automatically via git hook)
git add .
git commit -m "feat: Add profile analytics function"
```

### 3. Changing an Existing Edge Function

**Example**: Adding pagination to `person` function

```bash
# 1. Make changes to function
# ... edit supabase/functions/person/index.ts ...

# 2. Update unit tests to test new logic
# ... edit tests/unit/person.test.ts ...
npm run test:unit

# 3. Update integration tests to test new API behavior
# ... edit tests/integration/person.test.ts ...
npm run test:integration

# 4. Run specific test to verify
npm run test:person

# 5. Run all tests to ensure nothing broke
npm run test

# 6. Commit
git commit -m "feat: Add pagination to person list API"
```

### 4. Fixing a Bug

**Example**: Chat function crashes on empty message

```bash
# 1. Reproduce the bug locally
# ... test the function manually ...

# 2. Write a failing test that reproduces the bug
# ... add test case to tests/integration/chat.test.ts ...

# 3. Verify test fails
npm run test:chat
# Expected: Test should fail

# 4. Fix the bug
# ... edit supabase/functions/chat/index.ts ...

# 5. Verify test now passes
npm run test:chat
# Expected: Test should pass

# 6. Run all tests
npm run test

# 7. Commit with bug fix + test
git commit -m "fix: Handle empty messages in chat function"
```

### 5. Before Creating a PR

**MANDATORY checklist:**

```bash
# 1. Ensure local environment is clean
npm run reset
npm run seed:dev

# 2. Run all tests
npm run test

# 3. Check test coverage (if you added significant code)
npm run test:coverage

# 4. Run the build test script (if iOS changes)
./scripts/build-test.sh

# 5. Manual smoke test
# - Test the feature in the app
# - Check logs for errors
# - Verify database state

# 6. Only after ALL pass, create PR
git push origin your-feature-branch
gh pr create
```

## 🔄 Continuous Testing Workflow

### While Developing (Watch Mode)

For rapid feedback during development:

```bash
# Terminal 1: Watch tests (reruns on file changes)
npm run test:watch

# Terminal 2: Make changes
# ... edit code ...
# Tests automatically rerun!
```

### Before Every Commit (Git Hook)

We have a pre-commit hook that runs automatically:

```bash
# When you commit, this runs automatically:
git commit -m "your message"

# Behind the scenes:
# 1. Runs npm run test:core
# 2. If tests fail → commit blocked
# 3. If tests pass → commit succeeds

# To bypass (ONLY for emergencies):
git commit --no-verify -m "emergency fix"
```

## 🎨 Test Maintenance Guidelines

### When Edge Function Logic Changes

**What changed**: Business logic inside a function

**What to update**: Unit tests

```typescript
// Example: Added validation logic to person creation
Deno.test("Person Creation Validation", async (t) => {
  await t.step("should reject invalid relationship types", async () => {
    const mockClient = new MockSupabaseClient();

    // Add new test case for new validation
    const result = await createPerson(mockClient, {
      name: "Alice",
      relationship_type: "invalid-type"  // New validation
    });

    assertEquals(result.error, "Invalid relationship type");
  });
});
```

### When API Contract Changes

**What changed**: Request/response format of an Edge Function

**What to update**: Integration tests

```typescript
// Example: Added pagination parameters to person list
Deno.test("Person List API", async (t) => {
  await t.step("should support pagination", async () => {
    const response = await makeTestRequest('/person', 'GET', null, {
      'Authorization': 'Bearer test-token',
      // New query parameters
      'page': '2',
      'limit': '10'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.page, 2);
    assertEquals(response.data.results.length, 10);
  });
});
```

### When Database Schema Changes

**What changed**: Added/modified database tables or columns

**What to update**: Test data factories and related tests

```typescript
// Example: Added 'department' column to people table

// Update test factory (in tests/helpers/test-helpers.ts)
export const createTestPerson = (overrides: Partial<any> = {}) => ({
  id: crypto.randomUUID(),
  user_id: crypto.randomUUID(),
  name: 'Test Person',
  role: 'Software Engineer',
  relationship_type: 'direct_report',
  department: 'Engineering',  // New field
  ...overrides
});

// Update tests that create people
Deno.test("Person with department", async (t) => {
  await t.step("should save department", async () => {
    const person = createTestPerson({ department: 'Product' });
    // ... rest of test ...
  });
});
```

### When Onboarding Flow Changes

**What changed**: Added/removed/modified onboarding steps

**What to update**: E2E onboarding tests

```typescript
// Example: Added "team size" question to onboarding

Deno.test("Complete Onboarding Flow", async (t) => {
  // ... existing steps ...

  await t.step("Step 4: User provides team size", async () => {
    const response = await makeTestRequest('/user-profile-foundation', 'PUT', {
      call_name: 'Taylor',
      job_role: 'Engineering Manager',
      experience_level: 'intermediate',
      tone_preference: 'balanced',
      team_size: 'medium',  // New field
      onboarding_step: 4    // New step
    }, {
      'Authorization': `Bearer ${authToken}`
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.profile.team_size, 'medium');
  });
});
```

## 🚨 Common Pitfalls

### ❌ Running Tests Without Supabase

```bash
# This will fail:
npm run test:integration
# Error: Failed to connect to http://127.0.0.1:54321

# Fix: Start Supabase first
supabase start
npm run test:integration
```

### ❌ Running Integration Tests Without Edge Functions

```bash
# This will hang/timeout:
npm run test:integration
# Hanging... waiting for response...

# Fix: Start Edge Functions
supabase functions serve --env-file .env.local
# Then in another terminal:
npm run test:integration
```

### ❌ Forgetting to Seed Test Data

```bash
# Tests may fail with "User not found" or similar
npm run test:integration

# Fix: Seed test data
npm run seed:dev
npm run test:integration
```

### ❌ Stale Test Data

```bash
# Tests failing due to leftover data from previous runs

# Fix: Reset database
npm run reset
npm run seed:dev
npm run test
```

## 📊 Test Performance Guidelines

### Expected Test Speeds

- **Unit tests**: < 1 second per file
- **Integration tests**: < 5 seconds per file
- **E2E tests**: < 30 seconds per test
- **Full test suite**: < 2 minutes

### If Tests Are Slow

```bash
# Diagnose which tests are slow
npm run test:coverage

# Run only fast unit tests during development
npm run test:unit

# Run integration tests only when needed
npm run test:integration

# Run full suite before PR only
npm run test
```

## 🎯 Test-Driven Development (Recommended)

### TDD Workflow

```bash
# 1. Write failing test first
# ... write test in tests/unit/my-feature.test.ts ...

# 2. Run test - should fail
npm run test:unit
# Expected: ❌ Test fails (good!)

# 3. Implement minimum code to pass test
# ... write code in supabase/functions/my-feature/index.ts ...

# 4. Run test - should pass
npm run test:unit
# Expected: ✅ Test passes

# 5. Refactor if needed
# ... improve code ...

# 6. Run test - should still pass
npm run test:unit
# Expected: ✅ Test still passes

# 7. Repeat for next feature
```

### Benefits of TDD

- ✅ Tests guide your implementation
- ✅ Better code design (forced to think about testability)
- ✅ Fewer bugs (caught early)
- ✅ Confidence to refactor
- ✅ Documentation (tests show how code should work)

## 📚 Additional Resources

- [Backend Test README](./tests/README.md) - Comprehensive testing guide
- [Unit Testing Guidelines](./tests/unit/README.md) - How to write unit tests
- [Integration Testing Guidelines](./tests/integration/README.md) - How to write integration tests
- [E2E Testing Guidelines](./tests/e2e/README.md) - How to write E2E tests
- [CLAUDE.md - Testing Section](../CLAUDE.md#testing-standards--development-workflow) - Team standards
