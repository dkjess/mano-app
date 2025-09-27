# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Mano** is an AI-powered companion application for people managers. This repository contains both:
- iOS SwiftUI client (thin client architecture)
- Supabase backend with Edge Functions (`backend/` folder)

The iOS app is designed as a thin client that connects to the existing Supabase backend.

## Swift Development Standards

**MANDATORY**: This project requires iOS 26.0+ and uses the latest Swift/SwiftUI APIs. 
- **Never use deprecated APIs** - Always check for deprecation warnings
- **Always use the most modern syntax** available in Swift and SwiftUI
- **Follow Apple's latest design guidelines** and API patterns
- **Test on latest iOS versions** - The app targets cutting-edge iOS features

## Architecture

### Backend (backend/)
- **Supabase Edge Functions** in TypeScript/Deno
- **Main chat function** at `supabase/functions/chat/index.ts` - handles AI conversations using Anthropic Claude
- **Database migrations** for people management, conversations, embeddings
- **Storage** for message attachments
- **Authentication** with Google OAuth and email

### iOS Client
- `ManoApp.swift` - Main app entry point
- `ContentView.swift` - Primary view with navigation
- `WaveView.swift` - Secondary view (demo)
- Target: iOS 26.0, macOS 26.0, visionOS 26.0
- Bundle ID: `ai.supermano.Mano`

## Development Commands

### Local Development Setup

**Automated Setup (Recommended):**
```bash
cd backend
./scripts/dev-setup.sh
```

**Note**: The setup script will prompt you to:
1. Start Edge Functions with environment variables
2. Start ngrok for device testing (creates public tunnel)

**Manual Setup:**
```bash
# 1. Start Supabase services
cd backend
supabase start

# 2. CRITICAL: Serve Edge Functions with environment variables
supabase functions serve --env-file .env.local

# 3. Start ngrok for device testing (in separate terminal)
ngrok http 54321

# 4. Seed test data (includes self person creation)
npm run seed:dev

# If self person is missing, run the fix script
npx tsx scripts/fix-self-person.ts
```

**Test User Credentials:**
- Email: `dev@mano.local`
- Password: `dev123456`

### Self-Reflection Feature (is_self)

### Overview
Mano supports self-reflection conversations through a special "self" person that represents the user themselves:
- **Auto-creation**: Each user gets a self person created automatically (via database trigger or fix script)
- **Database Flag**: Self persons have `is_self=true` and `relationship_type='self'`
- **Special Prompts**: Self conversations use `SELF_SYSTEM_PROMPT` for reflection-focused coaching
- **Unique Constraint**: Only one self person allowed per user (enforced at database level)

### Testing Self-Reflection
```bash
# Test the is_self functionality
npx tsx scripts/test-is-self.ts

# Fix missing self persons for existing users
npx tsx scripts/fix-self-person.ts
```

### Self-Reflection Topics
Self persons get unique conversation starters:
- "What am I feeling about my work right now?"
- "What patterns do I notice in my management style?"
- "What growth areas should I focus on?"
- "How am I balancing my priorities?"
- "What successes should I acknowledge?"

## Backend Development
```bash
# Deploy functions
supabase functions deploy

# View logs
supabase functions logs chat

# Reset and recreate test data
npm run seed:dev reset && npm run seed:dev
```

### iOS Development

**MANDATORY BUILD TESTING**: Always run the build test script before claiming any iOS code changes work:

```bash
# Required: Test build with consistent target (iPhone 16 Pro, iOS 26.0)
./scripts/build-test.sh

# The script will output:
# ✅ Build SUCCEEDED! - Safe to proceed
# ❌ Build FAILED! - Fix errors before continuing

# Open in Xcode for development
open Mano.xcodeproj

# Manual build from command line (if needed)
xcodebuild -project Mano.xcodeproj -scheme Mano -configuration Debug
```

**Build Testing Requirements:**
- **Always use** `./scripts/build-test.sh` before claiming code works
- **Target consistency**: iPhone 16 Pro with iOS 26.0
- **Error visibility**: Script captures and displays all build errors
- **No assumptions**: Never assume code compiles without testing

### Device Testing with ngrok
For testing on physical iOS devices, use ngrok to tunnel local Supabase:

**Automated (via dev-setup.sh):**
- The setup script will prompt to start ngrok and show you the public URL

**Manual:**
```bash
# 1. Start ngrok tunnel (in separate terminal)
ngrok http 54321

# 2. Get the tunnel URL (convenience script)
./scripts/get-ngrok-url.sh

# OR manually:
curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'

# 3. Update Config.swift with the ngrok URL
# Replace DEBUG supabaseURL with: https://[your-ngrok-id].ngrok-free.app

# 4. Build and install on device via Xcode
```

**Important:**
- Update `Mano/Config.swift` to use the ngrok URL for device testing
- Revert to localhost for simulator testing
- ngrok generates a new URL each restart

### Service URLs (when running locally)
- **Supabase API:** http://127.0.0.1:54321 (simulator) / https://[ngrok-id].ngrok-free.app (device)
- **Supabase Studio:** http://127.0.0.1:54323
- **Edge Functions:** http://127.0.0.1:54321/functions/v1/
- **Database:** postgresql://postgres:postgres@127.0.0.1:54322/postgres

### Important Notes
- **Self Person Creation**: If the database trigger doesn't create the self person on user signup, run `npx tsx scripts/fix-self-person.ts`
- **Testing**: Use `npx tsx scripts/test-is-self.ts` to verify self-reflection functionality
- **Chat Prompts**: Self conversations use a dedicated coaching-focused prompt for personal growth
- **Device Testing**: Always start ngrok for device testing - the automated setup script handles this

### ⚠️ CRITICAL: Production Database Safety
**NEVER reset production database without explicit confirmation!**

✅ **Safe Commands:**
```bash
npm run reset          # Protected script - blocks production resets
./scripts/safe-db-reset.sh  # Always check environment first
```

❌ **Dangerous Commands:**
```bash
npm run reset:unsafe   # Bypasses protection - use with extreme caution
supabase db reset --linked  # WILL DESTROY PRODUCTION DATA
```

**Production Project ID:** `zfroutbzdkhivnpiezho`
- The safe reset script automatically detects if you're linked to production
- Always run `supabase unlink` to return to local development after production operations

### Troubleshooting
- **Edge Functions authentication errors:** Always use `--env-file .env.local`
- **Chat API 500 errors:** Ensure logged in with test user and Supabase is running
- **"User already exists":** Normal - use `npm run seed:dev reset` to start fresh
- **Device testing issues:** Ensure ngrok tunnel is running and Config.swift uses correct ngrok URL
- **ngrok URL changes:** Each ngrok restart generates a new URL - update Config.swift accordingly
- **No ngrok tunnel:** Check if ngrok is installed (`brew install ngrok`) and port 4040 is accessible

## iOS Client Integration

### SwiftUI iOS 18+ Syntax Requirements

**CRITICAL**: ALWAYS use the most modern Swift and SwiftUI APIs available. The project targets iOS 26.0 - never use deprecated APIs.

**Before writing any Swift code**:
1. Check if the API is deprecated
2. Use the latest iOS 18+ patterns
3. Prefer modern Swift concurrency (async/await) over older patterns
4. Use the newest SwiftUI navigation and state management APIs

#### Modern vs Outdated SwiftUI Patterns

**TextField Modifiers:**
```swift
// ✅ CORRECT - Modern iOS 15+ syntax
TextField("Email", text: $email)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()

// ❌ OUTDATED - Pre-iOS 15 syntax (DO NOT USE)
TextField("Email", text: $email)
    .autocapitalization(.none)  // This API is deprecated
    .disableAutocorrection(true) // Old pattern
```

**Navigation:**
```swift
// ✅ CORRECT - Modern iOS 16+ syntax
NavigationStack {
    // content
}
.navigationDestination(isPresented: $showView) {
    DestinationView()
}

// ❌ OUTDATED - Never use these deprecated patterns
NavigationView { }  // Deprecated in iOS 16
NavigationLink("", isActive: $isActive)  // Deprecated in iOS 16
```

**Async/Await:**
```swift
// ✅ CORRECT - Modern Swift concurrency
Task {
    try await performAsyncWork()
}

// ❌ OUTDATED - Completion handlers
performWork { result in
    // handle result
}
```

**Observable Objects:**
```swift
// ✅ CORRECT - Use @ObservedObject for singletons
@ObservedObject private var manager = Manager.shared

// ❌ INCORRECT - Don't use @StateObject with singletons
@StateObject private var manager = Manager.shared
```

### Required Dependencies
Add Supabase Swift SDK via Swift Package Manager:
- URL: `https://github.com/supabase/supabase-swift`
- Import both `Supabase` and `Combine` modules

### MainActor/Sendable Concurrency Issues

**CRITICAL**: This project uses `-default-isolation=MainActor`, which causes all types to default to MainActor isolation. This creates conflicts with Supabase's generic methods that require `Decodable & Sendable` types.

**Problem Pattern:**
```swift
// ❌ FAILS - Generic .execute().value triggers MainActor isolation conflict
let response: [MyStruct] = try await client
    .from("table")
    .select()
    .execute()
    .value  // Error: MainActor-isolated conformance cannot satisfy Sendable requirement
```

**✅ SOLUTION - Manual Decoding Pattern:**
```swift
// ✅ WORKS - Avoid generic constraint by getting raw data first
let data = try await client
    .from("table")
    .select()
    .execute()
    .data  // Get raw Data (no generic constraint)

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let response = try decoder.decode([MyStruct].self, from: data)  // Manual decode
```

**Key Points:**
- Always use `.execute().data` instead of `.execute().value` for fetching
- Manually decode with `JSONDecoder` afterward
- This pattern avoids the `T: Decodable & Sendable` generic constraint that conflicts with MainActor isolation
- Used successfully in `ProfileService.swift` and should be applied to all Supabase data fetching

### Key Integration Points
1. **Authentication** - Use Supabase Auth with Google OAuth
2. **Chat API** - Call `/functions/v1/chat` for AI interactions
3. **Real-time** - Subscribe to message updates
4. **File uploads** - Handle attachments via Supabase Storage

### Data Models
Match the backend schema:
```swift
struct Person: Codable, Identifiable {
    let id: UUID
    let name: String
    let role: String?
    let relationshipType: String
    let team: String?
}

struct Message: Codable, Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let personId: UUID?
    let topicId: UUID?
    let createdAt: Date
}
```

### Client Responsibilities
- Render conversations and UI
- Handle user input and file uploads
- Real-time updates via subscriptions
- Cache minimal data for responsive UI

### Client Restrictions
- No AI processing on device
- No direct LLM API calls
- Minimal local data storage
- All business logic stays in Edge Functions

## Testing Standards & Development Workflow

**MANDATORY**: Testing is a core part of our development workflow. All features MUST include comprehensive tests before being considered complete.

### Backend Testing (Required)

**Framework**: Deno's built-in testing framework
**Location**: `backend/tests/`
**Configuration**: `backend/tests/deno.json`

**Test Commands:**
```bash
cd backend
npm run test                # Run all tests
npm run test:watch          # Run tests in watch mode  
npm run test:coverage       # Run tests with coverage report
npm run test:integration    # Run integration tests
```

**Testing Requirements:**
- **Unit Tests**: Every Edge Function MUST have unit tests
- **Mocking**: Use MockSupabaseClient and MockAnthropicAPI from test-helpers.ts
- **Coverage**: Aim for >80% code coverage on all new features
- **Integration Tests**: Test actual HTTP endpoints when RUN_INTEGRATION_TESTS=true

**Test Structure:**
```typescript
// Example unit test structure
Deno.test("Feature Name", async (t) => {
  await t.step("should handle specific scenario", async () => {
    const mockClient = new MockSupabaseClient();
    const handler = new FeatureHandler(mockClient);
    
    const result = await handler.processFeature(testData);
    
    assertEquals(result.success, true);
    assertExists(result.data);
  });
});
```

**Mock Usage:**
```typescript
// Mock external dependencies
const mockSupabase = new MockSupabaseClient();
const mockAnthropic = new MockAnthropicAPI();

// Set up mock data
mockSupabase.setMockUser(createTestUser());
mockAnthropic.setMockResponse('default', { 
  content: [{ type: 'text', text: 'Mock response' }] 
});
```

### iOS Testing (Required)

**Framework**: XCTest (native iOS testing)
**Location**: iOS project test targets
**Requirements**: 
- Unit tests for all ViewModels and Services
- UI tests for critical user flows
- Mock network requests for testing

**Test Commands:**
```bash
# Run tests from Xcode
⌘+U

# Run from command line
xcodebuild test -project Mano.xcodeproj -scheme Mano -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Development Workflow

**MANDATORY PROCESS**: Before any feature is considered complete:

1. **Write Tests First** (TDD when possible)
   - Write unit tests before implementation
   - Define expected behavior in tests
   - Use tests to guide implementation

2. **Implement Feature**
   - Backend: Edge Functions with TypeScript
   - iOS: SwiftUI with modern iOS 26+ APIs
   - Ensure all tests pass

3. **Validate & Verify**
   - Run full test suite: `npm run test`
   - Check test coverage: `npm run test:coverage`
   - Run integration tests if applicable
   - Manual testing with dev environment

4. **Code Review Checklist**
   - [ ] All tests passing
   - [ ] New functionality has tests
   - [ ] No deprecated APIs used
   - [ ] Follows architectural patterns
   - [ ] Mock dependencies properly isolated

### Test Data & Environment

**Test Database**: Uses local Supabase with test data
**Test User**: `dev@mano.local` / `dev123456`
**Mock APIs**: All external APIs (Anthropic, etc.) should be mocked in tests

**Test Utilities Available:**
- `createTestUser()` - Generate test user objects
- `createTestPerson()` - Generate test person objects  
- `createTestMessage()` - Generate test message objects
- `makeTestRequest()` - Helper for HTTP endpoint testing
- `assertValidPerson()` - Validate person object structure
- `assertValidMessage()` - Validate message object structure

### CI/CD Integration

**Future**: Automated testing pipeline will:
- Run all unit tests on every commit
- Block merges if tests fail
- Generate coverage reports
- Run integration tests against staging environment

**Current**: Manual testing workflow ensures quality before deployment