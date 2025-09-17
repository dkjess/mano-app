# iOS Test Setup Instructions

This document provides step-by-step instructions for adding XCTest targets to the Mano Xcode project.

## Test Files Created

The following test files have been created and need to be added to Xcode test targets:

### Unit Tests (ManoTests/)
- `ManoTests/Models/PersonTests.swift` - Tests for Person model
- `ManoTests/Models/MessageTests.swift` - Tests for Message model  
- `ManoTests/Services/SupabasePeopleManagerTests.swift` - Tests for people management
- `ManoTests/Services/SupabaseAuthManagerTests.swift` - Tests for authentication

### UI Tests (ManoUITests/)
- `ManoUITests/ManoUITests.swift` - UI and integration tests

## Adding Test Targets to Xcode Project

### Step 1: Add Unit Test Target

1. Open `Mano.xcodeproj` in Xcode
2. Select the project file in the navigator
3. Click the `+` button at the bottom of the targets list
4. Choose `iOS` → `Test` → `Unit Testing Bundle`
5. Configure the target:
   - **Product Name:** `ManoTests`
   - **Target to be Tested:** `Mano`
   - **Language:** `Swift`
   - **Use Core Data:** No
6. Click `Finish`

### Step 2: Add UI Test Target

1. Click the `+` button again to add another target
2. Choose `iOS` → `Test` → `UI Testing Bundle`
3. Configure the target:
   - **Product Name:** `ManoUITests`
   - **Target to be Tested:** `Mano`
   - **Language:** `Swift`
4. Click `Finish`

### Step 3: Add Test Files to Targets

1. Delete the default test files that Xcode created:
   - `ManoTests/ManoTests.swift`
   - `ManoUITests/ManoUITests.swift`

2. Add the created test files:
   - Right-click on `ManoTests` target in navigator
   - Choose `Add Files to "Mano"`
   - Navigate to `/Users/jess/code/Mano/ManoTests/`
   - Select all test files in the Models and Services folders
   - Make sure `ManoTests` target is checked
   - Click `Add`

3. Add UI test files:
   - Right-click on `ManoUITests` target in navigator
   - Choose `Add Files to "Mano"`
   - Navigate to `/Users/jess/code/Mano/ManoUITests/`
   - Select `ManoUITests.swift`
   - Make sure `ManoUITests` target is checked
   - Click `Add`

### Step 4: Configure Test Target Settings

#### For ManoTests (Unit Tests):
1. Select `ManoTests` target in project settings
2. Go to `Build Settings`
3. Ensure these settings:
   - **iOS Deployment Target:** Same as main app (iOS 26.0)
   - **Swift Language Version:** Latest
4. Go to `Build Phases` → `Link Binary With Libraries`
5. Add the same dependencies as the main app:
   - `Supabase` (from Swift Package Manager)
   - Any other frameworks the main app uses

#### For ManoUITests (UI Tests):
1. Select `ManoUITests` target in project settings
2. Configure similar to unit tests but UI test targets don't need most app dependencies

### Step 5: Configure Test Schemes

1. Go to `Product` → `Scheme` → `Edit Scheme...`
2. Select `Test` in the left sidebar
3. Click `+` to add test targets if they're not already there
4. Add both `ManoTests` and `ManoUITests`
5. Configure test execution order (Unit tests first, then UI tests)

### Step 6: Run Tests

**From Xcode:**
- `⌘+U` to run all tests
- `⌘+Shift+U` to run tests with code coverage

**From Command Line:**
```bash
# Run all tests
xcodebuild test -project Mano.xcodeproj -scheme Mano -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run only unit tests
xcodebuild test -project Mano.xcodeproj -scheme Mano -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:ManoTests

# Run only UI tests  
xcodebuild test -project Mano.xcodeproj -scheme Mano -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:ManoUITests
```

## Test Configuration Notes

### Mocking Network Calls
The current tests are structured to use mocks for network calls. To fully implement testing:

1. Create mock implementations of Supabase client
2. Inject dependencies through initializers for testability
3. Use protocols to abstract network dependencies

### Test Data
- Use the same test user credentials as backend: `dev@mano.local` / `dev123456`
- Create mock objects using the helper methods in test files
- Ensure tests are isolated and don't depend on external state

### Continuous Integration
Once test targets are added, they can be integrated into CI/CD:
- Tests will run automatically on every commit
- Code coverage reports can be generated
- Failed tests will block deployments

## Troubleshooting

### Common Issues:

1. **Build Errors:** Ensure test targets have the same deployment target as main app
2. **Import Errors:** Make sure `@testable import Mano` is used in test files
3. **Dependency Issues:** Add required frameworks to test target's "Link Binary With Libraries"
4. **Simulator Issues:** Use the same iOS version for tests as the main app targets

### File Organization:
```
Mano/
├── Mano.xcodeproj
├── Mano/ (main app source)
├── ManoTests/
│   ├── Models/
│   │   ├── PersonTests.swift
│   │   └── MessageTests.swift
│   └── Services/
│       ├── SupabasePeopleManagerTests.swift
│       └── SupabaseAuthManagerTests.swift
└── ManoUITests/
    └── ManoUITests.swift
```

Once these steps are complete, the iOS testing framework will be fully integrated with the project and you can run tests using `⌘+U` or the command line.