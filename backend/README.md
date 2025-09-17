# Mano Backend

Unified backend services for the Mano AI-powered management assistant.

## Architecture

This backend provides:
- **Supabase Edge Functions** - AI chat, profile management, welcome messages
- **PostgreSQL Database** - User data, conversations, people profiles
- **Real-time subscriptions** - Live updates for conversations
- **Vector search** - Semantic search across conversations and profiles
- **Self-Reflection Support** - Auto-created self person for personal growth conversations

## Quick Start

### Prerequisites
- Supabase CLI installed
- Node.js 18+ 
- PostgreSQL (via Supabase)

### Development Setup

```bash
# 1. Start Supabase services
cd backend
supabase start

# 2. Run database migrations
supabase migration up

# 3. Serve Edge Functions with environment variables
supabase functions serve --env-file .env.local

# 4. Seed test data
npm run seed:dev
```

### Test User Credentials
- Email: `dev@mano.local`
- Password: `dev123456`

## Project Structure

```
backend/
├── supabase/
│   ├── functions/           # Edge Functions (AI chat, profile APIs)
│   ├── migrations/          # Database schema migrations
│   └── config.toml         # Supabase configuration
├── scripts/
│   ├── dev-setup.sh        # Automated development setup
│   ├── seed-test-user.ts   # Create test user and data
│   ├── test-is-self.ts     # Test self-reflection functionality
│   └── test-*.ts          # Various test scripts
├── docs/                   # API documentation
└── tests/                  # Integration tests
```

## Key APIs

### Chat API
- **Endpoint:** `POST /functions/v1/chat`
- **Purpose:** AI conversations, welcome message generation
- **Features:** Streaming responses, context awareness, person detection

### Profile APIs
- **Get Profile:** `GET /functions/v1/profile-get`
- **Update Profile:** `POST /functions/v1/profile-update`

## Database Schema

Key tables:
- `people` - Person profiles and relationships (includes `is_self` flag for self-reflection)
- `messages` - Conversation history
- `topics` - Strategic discussion topics
- `embeddings` - Vector search data

### Self Person Feature
Each user automatically gets a "self" person created on signup:
- **Trigger**: `create_self_person_on_user_creation` database trigger
- **Constraint**: Unique index ensures only one self person per user
- **Purpose**: Enables self-reflection and personal growth conversations
- **Prompt**: Uses dedicated `SELF_SYSTEM_PROMPT` for coaching-style interactions

## Environment Variables

Copy `.env.local.example` to `.env.local` and configure:

```bash
# Supabase
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# AI Services
ANTHROPIC_API_KEY=your_anthropic_key
OPENAI_API_KEY=your_openai_key

# OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
```

## Development Commands

```bash
# Start all services
npm run dev

# Reset database with fresh test data
npm run reset

# Run tests
npm run test

# Deploy functions
npm run deploy
```

## Deployment

The backend is deployed as Supabase Edge Functions. See deployment scripts in `/scripts/` directory.

## Integration

### iOS Client Integration
The iOS SwiftUI client connects to this backend via:
1. **Authentication** - Supabase Auth with Google OAuth
2. **Real-time** - WebSocket subscriptions for live updates
3. **REST APIs** - HTTP calls to Edge Functions
4. **File uploads** - Supabase Storage for attachments

### Welcome Message Flow
When a new person is created:
1. iOS calls person creation API
2. Backend automatically generates welcome message
3. Welcome message is inserted into conversation
4. iOS navigates to conversation (welcome message ready)

### Self-Reflection Flow
1. User signup triggers automatic self person creation
2. Self person appears in people list with `is_self=true`
3. Conversations with self person use reflection-focused prompts
4. Topics include personal growth, management style, and self-awareness

## Contributing

1. Make changes to functions in `supabase/functions/`
2. Test locally with `supabase functions serve`
3. Run integration tests with `npm run test`
4. Deploy with deployment scripts