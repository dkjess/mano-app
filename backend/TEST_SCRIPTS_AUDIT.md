# Test Scripts Audit

**Date:** 2025-10-15
**Purpose:** Document which test scripts are needed, outdated, or redundant

## Summary

- **Total Edge Functions:** 10
- **Functions with tests:** 8 (80%)
- **Functions without tests:** 2 (20%)
- **Total test scripts:** 48
- **Redundant scripts:** ~15-20 (estimated)

## Edge Functions Test Coverage

### ✅ Well-Tested Functions

**1. chat** (7 test scripts)
- `test-chat-api.ts` - Basic API testing
- `test-chat-flow.ts` - Full chat flow
- `test-chat-flow-direct.ts` - Direct API calls
- `test-self-chat.ts` - Self-reflection conversations
- `test-streaming.ts` - Streaming responses
- `test-message-sending.ts` - Message persistence ⭐ MOST RECENT (2025-10-12)
- `simple-conversation-test.ts` - Quick smoke test

**Recommendation:** Keep `test-message-sending.ts` and `test-streaming.ts`. Archive others.

**2. action-items-sync** (4 test scripts)
- `test-action-items.ts` - Comprehensive (390 lines)
- `test-action-items-sync.ts` - Sync functionality (290 lines)
- `test-action-items-with-login.ts` - Auth integration (258 lines)
- `test-action-items-simplified.ts` - Simplified version (183 lines)

**Recommendation:** Keep `test-action-items-sync.ts` as primary test. Archive others.

**3. person** (3 test scripts)
- `test-person-creation.ts` - Person creation API ⭐ KEEP
- `test-e2e-person-creation.sh` - End-to-end shell test ⭐ KEEP
- `test-enhanced-person-detection.ts` - Person detection logic

**Recommendation:** Keep all three - they test different aspects.

**4. profile-update** (4 test scripts)
- `test-dynamic-profiles.ts` - Dynamic profile updates (118 lines)
- `test-dynamic-profiles-e2e.ts` - E2E testing (243 lines)
- `test-profile-simple.ts` - Basic CRUD (119 lines)
- `test-profile-browser.ts` - Browser-based testing (109 lines)

**Recommendation:** Keep `test-dynamic-profiles-e2e.ts` and `test-profile-simple.ts`. Archive others.

**5. generate-conversation-title** (2 test scripts)
- `test-conversations.ts` - Basic conversation testing (61 lines)
- `test-conversations-e2e.ts` - E2E with title generation (270 lines) ⭐ KEEP

**Recommendation:** Keep `test-conversations-e2e.ts`. Archive `test-conversations.ts`.

**6. profile-get**
- Covered by profile test scripts above

### ⚠️ Under-Tested Functions

**7. create-embeddings** - ❌ NO DIRECT TEST
- **Risk:** Medium - Embeddings are critical for context retrieval
- **Recommendation:** Create `test-create-embeddings.ts`

**8. delete-account** - ❌ NO DIRECT TEST
- **Risk:** High - Account deletion must work correctly
- **Recommendation:** Create `test-delete-account.ts`

**9. user-profile-foundation** - ❌ NO DIRECT TEST
- **Risk:** Low - Covered by onboarding tests
- **Recommendation:** Add to `test-onboarding-initial-message.ts`

### 🔧 Utility Functions

**10. test-openai**
- **Purpose:** Utility for testing OpenAI integration
- **Test Needed:** No (it IS a test utility)

## Obsolete/Migration Test Scripts

These scripts test features that have been migrated or refactored:

- `test-general-migration.ts` - Tests old "general" topic migration (Sept 2025)
- `verify-general-migration.ts` - Verification for above
- `test-refactored-app.ts` - Tests old app structure
- `test-browser-automated.ts` - Browser automation (rarely used)
- `test-browser-simple.ts` - Simplified browser test

**Recommendation:** Move to `backend/scripts/archive/` directory

## Utility/Support Scripts (Keep)

These are not function tests but development utilities:

- `seed-test-user.ts` ⭐ CRITICAL - Creates test data
- `fix-self-person.ts` ⭐ CRITICAL - Fixes missing self persons
- `test-is-self.ts` ⭐ KEEP - Tests self-reflection feature
- `get-fresh-token.sh` - Gets auth tokens
- `dev-setup.sh` - Development environment setup
- `safe-db-reset.sh` - Safe database reset

## Recommended Action Plan

### Phase 1: Create Missing Tests (High Priority)
1. Create `test-create-embeddings.ts` - Test embedding generation
2. Create `test-delete-account.ts` - Test account deletion
3. Update `test-onboarding-initial-message.ts` - Add foundation profile tests

### Phase 2: Consolidate Redundant Tests
1. **Chat tests** - Keep: `test-message-sending.ts`, `test-streaming.ts`
2. **Action items** - Keep: `test-action-items-sync.ts`
3. **Profile tests** - Keep: `test-dynamic-profiles-e2e.ts`, `test-profile-simple.ts`
4. **Conversation tests** - Keep: `test-conversations-e2e.ts`

Archive the rest in `backend/scripts/archive/`

### Phase 3: Add to MANDATORY Testing Checklist

Update CLAUDE.md to specify which tests to run before PRs:

```bash
# MANDATORY tests before creating PR:
npm run seed:dev                          # Seed test data
npm run test:person                       # Test person creation
npm run test:chat                         # Test chat/messaging
npm run test:conversations                # Test conversations
```

### Phase 4: Set Up Proper Test Suite

Create `backend/package.json` scripts:

```json
{
  "scripts": {
    "test": "npm run test:core",
    "test:core": "npm run test:person && npm run test:chat && npm run test:conversations",
    "test:person": "deno run --allow-net --allow-env scripts/test-person-creation.ts",
    "test:chat": "deno run --allow-net --allow-env scripts/test-message-sending.ts",
    "test:conversations": "deno run --allow-net --allow-env scripts/test-conversations-e2e.ts",
    "test:embeddings": "deno run --allow-net --allow-env scripts/test-create-embeddings.ts",
    "test:delete-account": "deno run --allow-net --allow-env scripts/test-delete-account.ts"
  }
}
```

## Conclusion

**Current State:**
- ✅ Core functions (chat, person, profiles) are well-tested
- ⚠️ Some functions lack direct tests (embeddings, delete-account)
- ❌ Too many redundant test scripts (48 total, ~20 needed)

**Recommended State:**
- Keep ~20 essential test scripts
- Archive ~20 redundant/obsolete scripts
- Create 2-3 missing critical tests
- Document which tests are mandatory before PRs

**Priority:** Medium - Tests exist and work, but cleanup would improve maintainability
