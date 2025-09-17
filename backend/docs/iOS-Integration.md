# iOS Client Integration Guide

This guide covers how the iOS SwiftUI client integrates with the Mano backend services.

## Architecture Overview

The iOS app follows a **thin client architecture** - all AI processing, business logic, and data management happens in the backend. The iOS client focuses on:

- **UI/UX presentation**
- **Real-time updates via subscriptions** 
- **Authentication management**
- **File uploads and attachments**
- **Offline-first data caching**

## Client Configuration

### Supabase Client Setup

The iOS client uses the Supabase Swift SDK to connect to the backend:

```swift
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "http://127.0.0.1:54321")!,  // Local dev
    supabaseKey: "your_anon_key"
)
```

### Authentication Flow

```swift
// Google OAuth Sign-in
let result = try await supabase.auth.signInWithIdToken(
    credentials: GoogleAuthCredentials(
        idToken: idToken,
        accessToken: accessToken
    )
)

// Email/Password Authentication (fallback)
let result = try await supabase.auth.signIn(
    email: email,
    password: password
)
```

### Test User Credentials
- **Email:** `dev@mano.local`
- **Password:** `dev123456`

## Core Integration Points

### 1. Chat API Integration

**Endpoint:** `POST /functions/v1/chat`

```swift
struct ChatRequest: Codable {
    let person_id: UUID?     // Optional - for person conversations
    let message: String      // User's message content
    let topicId: UUID?      // Optional - for topic conversations
    let files: [FileUpload]? // Optional - for attachments
}

// Usage example
let response = try await supabase.functions.invoke(
    "chat",
    options: FunctionInvokeOptions(
        headers: ["Authorization": "Bearer \(accessToken)"],
        body: ChatRequest(
            person_id: personId,
            message: userMessage,
            topicId: nil,
            files: nil
        )
    )
)
```

**Streaming Support:**
The chat API supports streaming responses using AI SDK format. Handle chunked responses for real-time message display.

### 2. People Management

**Create Person:**
```swift
struct CreatePersonData: Codable, Sendable {
    let name: String
    let role: String?
    let relationship_type: String  // "manager", "direct_report", "peer", "stakeholder"
    let team: String?
    let notes: String?
}

let person = try await supabase.from("people").insert(personData).execute()
```

**Get People List:**
```swift
let people: [Person] = try await supabase
    .from("people")
    .select("*")
    .eq("user_id", value: userId)
    .order("name")
    .execute()
    .value
```

### 3. Real-time Subscriptions

**Subscribe to Message Updates:**
```swift
let messageSubscription = supabase
    .channel("messages")
    .on(.insert) { payload in
        // Handle new message
        if let newMessage = try? payload.decodeRecord(as: Message.self) {
            DispatchQueue.main.async {
                self.messages.append(newMessage)
            }
        }
    }
    .subscribe()
```

**Subscribe to People Updates:**
```swift
let peopleSubscription = supabase
    .channel("people")
    .on(.update) { payload in
        // Handle person profile updates
        if let updatedPerson = try? payload.decodeRecord(as: Person.self) {
            DispatchQueue.main.async {
                self.updatePersonInList(updatedPerson)
            }
        }
    }
    .subscribe()
```

### 4. File Uploads

**Upload Message Attachments:**
```swift
let fileData = try Data(contentsOf: fileURL)
let fileName = "attachment_\(UUID().uuidString).\(fileExtension)"

let uploadResult = try await supabase.storage
    .from("message-attachments")
    .upload(
        path: "\(userId)/\(fileName)",
        file: fileData,
        options: FileOptions(contentType: mimeType)
    )

// Include file reference in chat message
let chatRequest = ChatRequest(
    person_id: personId,
    message: userMessage,
    files: [FileUpload(
        name: fileName,
        path: uploadResult.path,
        type: mimeType
    )]
)
```

## Data Models

### Core Models

```swift
struct Person: Codable, Identifiable {
    let id: UUID
    let name: String
    let role: String?
    let relationshipType: String
    let team: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}

struct Message: Codable, Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let personId: UUID?
    let topicId: UUID?
    let createdAt: Date
    let attachments: [MessageAttachment]?
}

struct MessageAttachment: Codable, Identifiable {
    let id: UUID
    let fileName: String
    let filePath: String
    let mimeType: String
    let fileSize: Int64
}
```

### Relationship Types

The client should use these standard relationship types:

- **`"manager"`** - Your manager/supervisor
- **`"direct_report"`** - People who report to you  
- **`"peer"`** - Colleagues at same level
- **`"stakeholder"`** - External stakeholders/partners

## Backend Automation Features

### Welcome Messages

When creating a new person, the backend automatically:

1. **Generates welcome message** using AI based on person's profile
2. **Creates conversation thread** with the welcome message
3. **Sends real-time notification** to client via subscriptions

**Client Handling:**
```swift
// After creating person, navigate to conversation
let newPerson = try await createPerson(personData)

// The welcome message will appear automatically via subscription
NavigationLink(destination: ConversationView(personId: newPerson.id)) {
    Text("Start Conversation")
}
```

### Profile Intelligence

The backend continuously analyzes conversations to:

- **Update person profiles** with new information discovered
- **Generate profile suggestions** for missing fields
- **Detect mentioned people** and suggest adding them

**Client Integration:**
Subscribe to profile update notifications and refresh UI accordingly.

## Development Workflow

### 1. Start Backend Services

```bash
cd /Users/jess/code/Mano/backend
npm run setup    # Automated setup script
npm run seed:dev # Create test data
```

### 2. iOS Development

```bash
cd /Users/jess/code/Mano
open Mano.xcodeproj
# Build and run in Xcode simulator
```

### 3. Testing Integration

- **Backend logs:** `supabase functions logs chat`
- **Database studio:** http://127.0.0.1:54323
- **API testing:** Use test user `dev@mano.local` / `dev123456`

## Error Handling

### Common Integration Issues

**1. Authentication Errors (401)**
```swift
// Check if user session is valid
if supabase.auth.session == nil {
    // Redirect to login
    await signIn()
}
```

**2. Network Connectivity**
```swift
// Handle offline scenarios
do {
    let response = try await apiCall()
} catch {
    if error.localizedDescription.contains("network") {
        // Show offline indicator
        showOfflineMessage()
    }
}
```

**3. File Upload Limits**
- Max file size: 25MB per attachment
- Supported types: Images, PDFs, documents, text files
- Storage bucket: `message-attachments`

## Performance Considerations

### Caching Strategy

- **Cache recent conversations** locally using Core Data
- **Lazy load older messages** when scrolling
- **Prefetch person profiles** for better UX

### Real-time Optimization

- **Limit subscriptions** to active conversation threads
- **Unsubscribe** when views are dismissed
- **Batch UI updates** to prevent excessive redraws

### Memory Management

- **Image attachments** should be loaded asynchronously
- **Large file previews** should be generated server-side
- **Message history** should be paginated (50 messages per page)

## Security Best Practices

### Data Protection

- **Never log sensitive information** (API keys, tokens, personal data)
- **Use Keychain** for storing authentication tokens
- **Validate file uploads** before sending to backend
- **Sanitize user inputs** before API calls

### Authentication Security

- **Token refresh handling** - implement automatic refresh
- **Biometric authentication** - use Face ID/Touch ID when available
- **Session timeout** - respect backend JWT expiry times

## Next Steps

1. **Implement conversation UI** with real-time message streaming
2. **Add person creation flow** with relationship type selector  
3. **Test welcome message automation** with new person creation
4. **Implement file upload UI** for message attachments
5. **Add offline support** with local data synchronization