# Archived Test Scripts

These test scripts have been archived as part of the test suite restructuring (October 2025).

## Why These Were Archived

These scripts were redundant or obsolete:
- **Chat tests**: Replaced by comprehensive `tests/integration/chat.test.ts`
- **Action items tests**: Replaced by `tests/integration/action-items-sync.test.ts`
- **Profile tests**: Replaced by integration tests
- **Conversation tests**: Replaced by `tests/integration/chat.test.ts`
- **General/Migration tests**: Feature migrated, no longer needed
- **Browser tests**: Rarely used, manual testing preferred
- **Refactored app tests**: Old architecture, no longer relevant

## Archived Scripts

### Chat Tests (Redundant)
- `test-chat-api.ts` - Basic chat API testing
- `test-chat-flow.ts` - Full chat flow testing
- `test-chat-flow-direct.ts` - Direct API calls
- `test-self-chat.ts` - Self-reflection conversations
- `simple-conversation-test.ts` - Simple smoke test

**Replaced by**: `tests/integration/chat.test.ts`

### Action Items Tests (Redundant)
- `test-action-items.ts` - Comprehensive testing (390 lines)
- `test-action-items-sync.ts` - Kept in active tests!
- `test-action-items-with-login.ts` - Auth integration testing
- `test-action-items-simplified.ts` - Simplified version

**Replaced by**: `tests/integration/action-items-sync.test.ts`

### Profile Tests (Redundant)
- `test-dynamic-profiles.ts` - Dynamic profile updates
- `test-profile-browser.ts` - Browser-based testing

**Replaced by**: Active integration tests

### Conversation Tests (Redundant)
- `test-conversations.ts` - Basic conversation testing

**Replaced by**: `tests/integration/chat.test.ts` (includes conversation management)

### Migration/Obsolete Tests
- `test-general-migration.ts` - Tests old "general" topic migration
- `verify-general-migration.ts` - Verification for migration
- `test-refactored-app.ts` - Tests old app structure

**Reason**: Features migrated or refactored, tests no longer applicable

### Browser Tests (Rarely Used)
- `test-browser-automated.ts` - Automated browser testing
- `test-browser-simple.ts` - Simplified browser test

**Reason**: Rarely used, manual testing preferred for browser features

## Current Active Test Suite

The new structured test suite is located in `backend/tests/`:

```
tests/
├── unit/           # Pure unit tests with mocks
├── integration/    # API endpoint tests with real database
├── e2e/            # End-to-end user journey tests
└── helpers/        # Shared test utilities
```

**Key test scripts to use**:
- `test-message-sending.ts` - Message persistence testing (kept for now)
- `test-streaming.ts` - Streaming response testing (kept for now)
- `test-action-items-sync.ts` - Action items sync (kept for now)
- `test-dynamic-profiles-e2e.ts` - Profile E2E tests (kept for now)
- `test-profile-simple.ts` - Basic profile CRUD (kept for now)
- `test-conversations-e2e.ts` - Conversation E2E tests (kept for now)
- `test-person-creation.ts` - Person creation API (kept for now)
- `test-is-self.ts` - Self-reflection feature (kept for now)

## Future Cleanup

These remaining scripts will be migrated to the new structure in future iterations:
- Migrate remaining `.ts` test scripts to `tests/integration/`
- Consolidate E2E tests into `tests/e2e/`
- Remove old scripts once new tests are proven stable
