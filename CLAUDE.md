# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 👥 Team Roles & Collaboration Model

### Jess - CEO & Reference User
- **Role:** Product vision, strategy, and final decision maker
- **Responsibilities:**
  - Define product direction and priorities
  - Review and approve PRs on GitHub
  - Provide user perspective and product feedback
  - Make go/no-go decisions on deployments
  - Set business objectives and success criteria
- **Workflow:** Review PRs, provide feedback, merge when approved

### Claude - CTO & Engineering Lead
- **Role:** Technical implementation, architecture, and product sparring partner
- **Responsibilities:**
  - Implement features and technical solutions
  - Design system architecture and infrastructure
  - Write all code (backend, iOS, infrastructure)
  - Create PRs with complete implementation
  - Ensure production reliability and quality
  - Challenge product ideas constructively
  - Suggest technical alternatives and improvements
  - Maintain documentation and deployment processes
- **Workflow:** Build → Test → Create PR → Await approval → Auto-deploy on merge

### Collaboration Principles
- **Jess writes no code** - All technical implementation is Claude's responsibility
- **Jess reviews everything** - All changes go through PR review and approval
- **Product sparring** - Claude actively questions and refines product ideas
- **Automation first** - Technical work should minimize manual steps for Jess
- **Clear communication** - All decisions and changes documented in PRs
- **Trust but verify** - Automated testing validates all changes before deployment

### Common Scenarios

**When Jess says "let's build X":**
1. Claude asks clarifying questions about the use case
2. Claude proposes technical approach
3. Claude implements the solution
4. Claude creates PR with clear description
5. Jess reviews and merges on GitHub
6. CI/CD automatically deploys

**When there's a production issue:**
1. Claude investigates and identifies root cause
2. Claude creates hotfix with fix + tests
3. Claude creates PR explaining the issue and solution
4. Jess reviews and merges
5. CI/CD automatically fixes production

**When discussing product ideas:**
- Claude challenges assumptions ("Why do users need this?")
- Claude suggests simpler alternatives ("What if we just...")
- Claude highlights technical constraints ("This would require...")
- Claude proposes MVP scope ("We could start with...")
- Jess makes final call on direction

**Result:** Jess focuses on product and users. Claude handles all technical execution.

## 🚨 CRITICAL: Git Workflow Rules

**NEVER commit or push directly to main!** Always use feature branches and pull requests.

**MANDATORY Workflow:**
1. **Create a feature branch** for ALL code changes
2. **Commit to the feature branch**
3. **Push the feature branch** to origin
4. **Create a Pull Request** for review
5. **Only merge via PR** after approval

**Required Commands:**
```bash
# 1. Create and checkout feature branch
git checkout -b feature/description-of-change

# 2. Make changes and commit
git add <files>
git commit -m "Description"

# 3. Push feature branch (NOT main)
git push origin feature/description-of-change

# 4. Create PR
gh pr create --title "Title" --body "Description"
```

**FORBIDDEN Commands:**
```bash
git push origin main          # NEVER push directly to main
git commit && git push        # NEVER push without creating a branch first
```

**Exception:** Only push to main if explicitly instructed by the user with confirmation.

## 🏷️ CRITICAL: PR Deployment Labels

**MANDATORY:** Every PR MUST include ONE deployment type badge at the very top of the description.

### Deployment Types:

**📱 App Only - Rebuild Required**
- SwiftUI/iOS UI changes
- App logic changes
- **Jess needs to:** Rebuild app in Xcode (⇧⌘K then ⌘R)
- **No backend deployment**

**☁️ Backend Only - Auto-Deploy**
- Edge Functions changes
- Database migrations
- API/backend logic
- **Jess needs to:** Just merge - auto-deploys via CI/CD
- **No app rebuild needed**

**🔄 App + Backend - Both Required**
- Full-stack features
- Schema + UI changes
- **Jess needs to:** Merge (backend auto-deploys) + rebuild app

**📚 Docs/Config Only - No Action Required**
- Documentation updates
- Config/workflow files
- **Jess needs to:** Just merge - nothing to deploy

**Usage:** Copy the appropriate badge from `PR_TEMPLATE.md` into every PR description.

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

### Platform-Specific Code Requirements

**CRITICAL**: This is a multi-platform app (iOS, macOS, visionOS). Always use platform checks for platform-specific APIs.

#### Colors
**WRONG:**
```swift
.background(Color(.systemGray6))  // ❌ iOS-only, crashes on macOS
```

**CORRECT:**
```swift
#if os(iOS)
.background(Color(.systemGray6))
#else
.background(Color(NSColor.controlBackgroundColor))
#endif
```

**Common Platform-Specific Colors:**
- `UIColor.systemGray6` → iOS only
- `UIColor.systemBackground` → iOS only
- `NSColor.controlBackgroundColor` → macOS only
- `NSColor.windowBackgroundColor` → macOS only

**Safe Cross-Platform Colors:**
- `Color.gray`, `Color.blue`, `Color.red`, etc. (built-in SwiftUI colors)
- `Color.primary`, `Color.secondary` (semantic colors)
- `.background`, `.regularMaterial` (SwiftUI materials)

#### Device/Platform Checks
```swift
// Check device type (iOS only)
#if os(iOS)
if UIDevice.current.userInterfaceIdiom == .pad {
    // iPad-specific code
}
#endif

// Platform check
#if os(macOS)
// macOS-specific code
#elseif os(iOS)
// iOS-specific code
#elseif os(visionOS)
// visionOS-specific code
#endif
```

#### Build Testing
**ALWAYS test both iOS and macOS builds** before creating PRs:
```bash
# Test iOS build
./scripts/build-test.sh

# Test macOS build
xcodebuild -project Mano.xcodeproj -scheme Mano -configuration Debug -destination 'platform=macOS' build
```

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
# 1. Install git hooks for workflow safety
./scripts/install-git-hooks.sh

# 2. Start Supabase services
cd backend
supabase start

# 3. CRITICAL: Serve Edge Functions with environment variables
supabase functions serve --env-file .env.local

# 4. Start ngrok for device testing (permanent custom domain)
ngrok http --url=mano.ngrok.app 54321

# 5. Seed test data (includes self person creation)
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

### 🚨 CRITICAL: Deployment Workflow Requirements

**NEVER deploy Edge Functions directly to production!** Always follow the proper CI/CD workflow:

✅ **CORRECT Deployment Process:**
```bash
# 1. Create feature branch
git checkout -b feature/your-feature-name

# 2. Make changes to Edge Functions locally
# 3. Test locally with local Supabase
cd backend
supabase functions serve --env-file .env.local

# 4. Commit changes to feature branch
git add .
git commit -m "Description of changes"

# 5. Push feature branch (NOT main)
git push origin feature/your-feature-name

# 6. Create PR for review
gh pr create --title "Title" --body "Description"

# 7. Merge PR - CI/CD automatically deploys to production
```

❌ **FORBIDDEN Commands (DO NOT USE):**
```bash
# These commands bypass review and CI/CD - NEVER USE:
supabase functions deploy --project-ref zfroutbzdkhivnpiezho  # Direct production deploy
supabase functions deploy  # If linked to production
```

### Local Development Commands
```bash
# View logs from local functions
supabase functions logs chat

# Reset and recreate test data locally
npm run seed:dev reset && npm run seed:dev

# Test functions locally only
cd backend
supabase functions serve --env-file .env.local
```

### Production Monitoring
```bash
# View production logs (read-only)
supabase functions logs chat --project-ref zfroutbzdkhivnpiezho

# Check production function status
supabase projects list
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
For testing on physical iOS devices, use ngrok to tunnel local Supabase.

**Permanent ngrok domain:** `https://mano.ngrok.app`

**Automated (via dev-setup.sh):**
- The setup script will prompt to start ngrok and show you the public URL

**Manual:**
```bash
# 1. Start ngrok tunnel with custom domain (in separate terminal)
ngrok http --url=mano.ngrok.app 54321

# 2. Verify tunnel is running
curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'
# Should output: https://mano.ngrok.app

# 3. Build and install on device via Xcode
```

**Important:**
- ngrok now uses a permanent custom domain: `mano.ngrok.app`
- No need to update BackendEnvironment.swift - already configured
- Use shake gesture in app to switch between Production/Local/Localhost
- Simulator uses localhost (127.0.0.1:54321) by default

### Service URLs (when running locally)
- **Supabase API:** http://127.0.0.1:54321 (simulator) / https://mano.ngrok.app (device)
- **Supabase Studio:** http://127.0.0.1:54323
- **Edge Functions:** http://127.0.0.1:54321/functions/v1/
- **Database:** postgresql://postgres:postgres@127.0.0.1:54322/postgres

### Important Notes
- **Self Person Creation**: If the database trigger doesn't create the self person on user signup, run `npx tsx scripts/fix-self-person.ts`
- **Testing**: Use `npx tsx scripts/test-is-self.ts` to verify self-reflection functionality
- **Chat Prompts**: Self conversations use a dedicated coaching-focused prompt for personal growth
- **Device Testing**: Always start ngrok for device testing - the automated setup script handles this

### ⚠️ CRITICAL: Production Safety Policies

**NEVER make direct production changes without proper review process!**

#### Database Safety
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

#### Edge Function Deployment Safety
✅ **Safe Process:**
```bash
# Always use feature branch workflow
git checkout -b feature/your-change
git add .
git commit -m "Description"
git push origin feature/your-change
gh pr create
# Wait for review and CI/CD deployment
```

❌ **Forbidden Direct Deployments:**
```bash
supabase functions deploy --project-ref zfroutbzdkhivnpiezho  # BYPASSES REVIEW
supabase functions deploy  # If linked to production - DANGEROUS
```

**Production Project ID:** `zfroutbzdkhivnpiezho`
- All production changes must go through PR review and CI/CD
- Direct deployments bypass important safety checks and code review
- Always run `supabase unlink` to return to local development after any production operations

### Troubleshooting
- **Edge Functions authentication errors:** Always use `--env-file .env.local`
- **Chat API 500 errors:** Ensure logged in with test user and Supabase is running
- **"User already exists":** Normal - use `npm run seed:dev reset` to start fresh
- **Device testing issues:** Ensure ngrok tunnel is running with `ngrok http --url=mano.ngrok.app 54321`
- **ngrok permanent domain:** Now uses `mano.ngrok.app` - no need to update config after restarts
- **No ngrok tunnel:** Check if ngrok is installed (`brew install ngrok`) and port 4040 is accessible
- **Environment switching:** Shake device in app to access developer settings and switch between Production/Local/Localhost

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
**Location**: `backend/tests/` (structured test suite)
**Configuration**: `backend/tests/deno.json`

**Test Directory Structure:**
```
backend/tests/
├── unit/           # Pure unit tests with mocks (70% of tests)
├── integration/    # API endpoint tests with real database (25% of tests)
├── e2e/            # End-to-end user journey tests (5% of tests)
└── helpers/        # Shared test utilities and mocks
```

**Test Commands:**
```bash
cd backend

# Run all tests
npm run test                    # All tests (unit + integration + e2e)
npm run test:unit               # Only unit tests (fast, with mocks)
npm run test:integration        # Only integration tests (requires Supabase running)
npm run test:e2e                # Only end-to-end tests (full system)
npm run test:watch              # Run tests in watch mode
npm run test:coverage           # Generate coverage report

# Run specific test suites
npm run test:core               # Core functionality (person, chat, embeddings, delete-account)
npm run test:person             # Person creation and management
npm run test:chat               # Chat and messaging
npm run test:embeddings         # Embedding generation
npm run test:delete-account     # Account deletion
npm run test:action-items       # Action items sync
```

**Testing Requirements:**
- **Unit Tests**: Every Edge Function MUST have unit tests in `tests/unit/`
- **Integration Tests**: Every Edge Function endpoint MUST have integration tests in `tests/integration/`
- **Mocking**: Use MockSupabaseClient and MockAnthropicAPI from `tests/helpers/test-helpers.ts`
- **Coverage Goal**: >80% code coverage on backend (focus on unit tests)
- **Integration Tests**: Test actual HTTP endpoints with real local Supabase
- **E2E Tests**: Critical user journeys only (onboarding, chat flow, account deletion)

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

1. **Write Tests First** (TDD recommended)
   - Write unit tests in `tests/unit/` before implementation
   - Write integration tests in `tests/integration/` for API endpoints
   - Define expected behavior in tests
   - Use tests to guide implementation

2. **Implement Feature**
   - Backend: Edge Functions with TypeScript
   - iOS: SwiftUI with modern iOS 26+ APIs
   - Ensure all tests pass: `npm run test`

3. **Validate & Verify**
   - Run unit tests: `npm run test:unit` (fast, no external dependencies)
   - Run integration tests: `npm run test:integration` (requires Supabase running)
   - Run core test suite: `npm run test:core`
   - Check test coverage: `npm run test:coverage`
   - Manual testing with dev environment

4. **Code Review Checklist**
   - [ ] All tests passing (`npm run test`)
   - [ ] New Edge Function has unit tests in `tests/unit/`
   - [ ] New Edge Function has integration tests in `tests/integration/`
   - [ ] Coverage >80% on new code
   - [ ] No deprecated APIs used
   - [ ] Follows architectural patterns
   - [ ] Mock dependencies properly isolated (unit tests)
   - [ ] Real Supabase tested (integration tests)

### Test Data & Environment

**Test Database**: Uses local Supabase with test data
**Test User**: `dev@mano.local` / `dev123456`
**Mock APIs**: All external APIs (Anthropic, etc.) should be mocked in **unit tests**
**Real APIs**: Integration tests use real local Supabase, but may mock external APIs

**Test Prerequisites:**
```bash
# 1. Start local Supabase
supabase start

# 2. Seed test data
npm run seed:dev

# 3. Start Edge Functions (for integration tests)
supabase functions serve --env-file .env.local

# 4. Run tests
npm run test
```

**Structured Test Suites:**
- `tests/unit/` - Fast, isolated tests with mocks
- `tests/integration/` - API endpoint tests with real database
  - `person.test.ts` - Person creation and management
  - `chat.test.ts` - Chat and messaging functionality
  - `create-embeddings.test.ts` - Embedding generation
  - `delete-account.test.ts` - Account deletion cascade
  - `action-items-sync.test.ts` - Action items synchronization
- `tests/e2e/` - Full user journey tests
  - `onboarding-flow.test.ts` - Complete signup → onboarding → first message

**Legacy Test Scripts** (being phased out):
- `scripts/test-person-creation.ts` - Use `npm run test:person` instead
- `scripts/test-is-self.ts` - Still useful for debugging self-reflection
- `scripts/fix-self-person.ts` - Utility script, not a test

### When to Run Tests (Quick Reference)

| Situation | Command | Why |
|-----------|---------|-----|
| **After writing function logic** | `npm run test:unit` | Fast feedback on business logic |
| **After changing API endpoint** | `npm run test:<function-name>` | Verify endpoint contract |
| **Before committing** | Auto-runs via git hook | Prevent broken code |
| **Before creating PR** | `npm run test` | Full validation |
| **After merge conflicts** | `npm run test` | Ensure nothing broke |
| **During active development** | `npm run test:watch` | Continuous feedback |

### When to Update Tests

| You Changed... | Update These Tests | How |
|----------------|-------------------|-----|
| **New Edge Function** | Unit + Integration | Create both test files |
| **Function business logic** | Unit tests | Add/update test cases |
| **API request/response** | Integration tests | Update request/response assertions |
| **Database schema** | Test data factories | Update `createTest*` helpers |
| **Onboarding flow** | E2E onboarding test | Add/modify onboarding steps |
| **Fixed a bug** | Add regression test | Reproduce bug, then fix |

### Automated Testing (Git Hooks)

**Pre-commit Hook**: Automatically runs `npm run test:core` before every commit.

```bash
# Setup once:
npm run setup:hooks

# What happens:
# 1. You commit: git commit -m "fix: something"
# 2. Hook runs: npm run test:core
# 3. If tests pass → commit succeeds ✅
# 4. If tests fail → commit blocked ❌

# Emergency bypass (use sparingly):
git commit --no-verify -m "emergency fix"
```

### Test Maintenance Best Practices

1. **Keep tests close to code** - Test structure mirrors function structure
2. **Test behavior, not implementation** - Test what functions do, not how
3. **One assertion per test** - Makes failures easier to diagnose
4. **Fast feedback** - Unit tests <1s, integration <5s
5. **Clean up after tests** - No leftover data in database
6. **Update tests with code** - Tests are part of the feature, not separate

### CI/CD Integration

**Future**: Automated testing pipeline will:
- Run all unit tests on every commit
- Block merges if tests fail
- Generate coverage reports
- Run integration tests against staging environment

**Current**: Manual testing workflow ensures quality before deployment