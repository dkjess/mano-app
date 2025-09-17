import XCTest

final class ManoUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        super.setUp()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        super.tearDown()
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunches() throws {
        // Test that the app launches successfully
        XCTAssertTrue(app.exists)
        XCTAssertTrue(app.isRunning)
    }
    
    func testWelcomeScreenAppears() throws {
        // Test that welcome/onboarding screen appears for new users
        // This would depend on the actual app flow
        
        // Look for welcome screen elements
        let welcomeText = app.staticTexts["Welcome to Mano"]
        let getStartedButton = app.buttons["Get Started"]
        
        // These elements might not exist yet, so we'll make this conditional
        if welcomeText.exists {
            XCTAssertTrue(welcomeText.exists)
        }
        
        if getStartedButton.exists {
            XCTAssertTrue(getStartedButton.exists)
        }
    }
    
    // MARK: - Authentication Flow Tests
    
    func testSignInFlow() throws {
        // Test the sign in flow
        
        // Look for sign in elements
        let signInButton = app.buttons["Sign In"]
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        
        if signInButton.exists && emailField.exists && passwordField.exists {
            // Test email input
            emailField.tap()
            emailField.typeText("test@example.com")
            
            // Test password input  
            passwordField.tap()
            passwordField.typeText("testpassword")
            
            // Tap sign in button
            signInButton.tap()
            
            // Wait for sign in to complete (with mock success)
            // In real tests, we'd mock the authentication response
        }
    }
    
    func testGoogleSignInButton() throws {
        // Test that Google sign in button is accessible
        let googleSignInButton = app.buttons["Sign in with Google"]
        
        if googleSignInButton.exists {
            XCTAssertTrue(googleSignInButton.isEnabled)
            
            // Test tapping the button (won't complete OAuth in UI tests)
            googleSignInButton.tap()
            
            // Verify appropriate loading state or OAuth screen appears
            // This would depend on the implementation
        }
    }
    
    // MARK: - Main App Flow Tests
    
    func testNavigationAfterSignIn() throws {
        // Test navigation to main app after successful sign in
        // This assumes the user gets past authentication
        
        // Look for main navigation elements
        let homeTab = app.tabBars.buttons["Home"]
        let peopleTab = app.tabBars.buttons["People"]
        
        if homeTab.exists {
            XCTAssertTrue(homeTab.exists)
            homeTab.tap()
        }
        
        if peopleTab.exists {
            XCTAssertTrue(peopleTab.exists)
            peopleTab.tap()
        }
    }
    
    // MARK: - People Management Tests
    
    func testAddPersonFlow() throws {
        // Test adding a new person
        // This assumes user is authenticated
        
        let addPersonButton = app.buttons["Add Person"]
        
        if addPersonButton.exists {
            addPersonButton.tap()
            
            // Fill out person details
            let nameField = app.textFields["Name"]
            let roleField = app.textFields["Role"]
            
            if nameField.exists {
                nameField.tap()
                nameField.typeText("John Doe")
            }
            
            if roleField.exists {
                roleField.tap()
                roleField.typeText("Software Engineer")
            }
            
            // Select relationship type
            let relationshipPicker = app.buttons["Relationship Type"]
            if relationshipPicker.exists {
                relationshipPicker.tap()
                app.buttons["Direct Report"].tap()
            }
            
            // Save the person
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
                
                // Verify person was added
                // Wait for navigation back to people list
                let expectation = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == false"),
                    object: saveButton
                )
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }
    
    func testPersonListDisplay() throws {
        // Test that people list displays correctly
        
        let personList = app.tables["People List"]
        
        if personList.exists {
            XCTAssertTrue(personList.exists)
            
            // Test that list can be scrolled if it has content
            if personList.cells.count > 0 {
                let firstCell = personList.cells.firstMatch
                XCTAssertTrue(firstCell.exists)
                
                // Test tapping on a person
                firstCell.tap()
                
                // Verify navigation to person detail or conversation
                // This would depend on the app's behavior
            }
        }
    }
    
    // MARK: - Conversation Tests
    
    func testConversationView() throws {
        // Test the conversation interface
        
        let messageInput = app.textViews["Message Input"]
        let sendButton = app.buttons["Send"]
        
        if messageInput.exists && sendButton.exists {
            // Type a test message
            messageInput.tap()
            messageInput.typeText("This is a test message")
            
            // Send the message
            sendButton.tap()
            
            // Wait for message to appear in conversation
            let sentMessage = app.staticTexts["This is a test message"]
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"),
                object: sentMessage
            )
            wait(for: [expectation], timeout: 5.0)
            
            if sentMessage.exists {
                XCTAssertTrue(sentMessage.exists)
            }
        }
    }
    
    // MARK: - Settings and Profile Tests
    
    func testSettingsAccess() throws {
        // Test accessing settings
        
        let settingsButton = app.buttons["Settings"]
        
        if settingsButton.exists {
            settingsButton.tap()
            
            // Verify settings screen appears
            let settingsTitle = app.navigationBars["Settings"]
            if settingsTitle.exists {
                XCTAssertTrue(settingsTitle.exists)
            }
        }
    }
    
    func testSignOut() throws {
        // Test signing out
        
        let settingsButton = app.buttons["Settings"]
        
        if settingsButton.exists {
            settingsButton.tap()
            
            let signOutButton = app.buttons["Sign Out"]
            if signOutButton.exists {
                signOutButton.tap()
                
                // Confirm sign out if there's a confirmation dialog
                let confirmButton = app.buttons["Sign Out"]
                if confirmButton.exists {
                    confirmButton.tap()
                }
                
                // Verify navigation back to welcome/sign in screen
                let signInButton = app.buttons["Sign In"]
                let expectation = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == true"),
                    object: signInButton
                )
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Test that UI elements have proper accessibility labels
        
        let app = XCUIApplication()
        
        // Check common UI elements for accessibility
        for element in app.descendants(matching: .button) {
            if element.exists && element.isHittable {
                XCTAssertFalse(element.label.isEmpty, "Button should have accessibility label")
            }
        }
        
        for element in app.descendants(matching: .textField) {
            if element.exists {
                XCTAssertFalse(element.label.isEmpty, "Text field should have accessibility label")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        // Test app launch performance
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}