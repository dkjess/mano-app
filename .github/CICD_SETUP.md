# CI/CD Setup Instructions

## Required GitHub Secrets

To enable automatic deployment to Supabase, you need to add these secrets to your GitHub repository:

### 1. Get Supabase Access Token

**Method 1: Supabase Dashboard**
1. Go to https://supabase.com/dashboard/account/tokens
2. Create a new access token
3. Copy the token value

**Method 2: CLI (if available)**
```bash
supabase auth token
```

### 2. Add GitHub Repository Secrets

Go to your GitHub repository: https://github.com/dkjess/mano-app/settings/secrets/actions

Add these secrets:

#### `SUPABASE_ACCESS_TOKEN`
- **Value**: Your Supabase access token from step 1
- **Description**: Used for authenticating with Supabase CLI in GitHub Actions

#### `SUPABASE_DB_PASSWORD`
- **Value**: Your Supabase database password
- **Description**: Used for database migrations (if required)

#### `ANTHROPIC_API_KEY` (for functions)
- **Value**: Your Anthropic API key
- **Description**: Used by Edge Functions for AI processing

## How the CI/CD Pipeline Works

### On Pull Request:
1. **Run Tests**: Executes backend tests with Deno
2. **Type Checking**: Validates TypeScript compilation
3. **Lint Checking**: Ensures code quality

### On Push to Main:
1. **Run Tests**: Same as PR validation
2. **Deploy Database**: Runs `supabase db push` to apply migrations
3. **Deploy Functions**: Runs `supabase functions deploy` to update Edge Functions
4. **Verify**: Lists deployed functions to confirm success

## Testing the Pipeline

1. **Add the secrets** to your GitHub repository
2. **Make a small change** to trigger the pipeline
3. **Push to main branch** or merge a PR
4. **Monitor the Actions tab** in GitHub to see deployment progress

## Pipeline Features

✅ **Automatic Testing**: Runs on every PR and push
✅ **Safe Deployment**: Only deploys on main branch pushes
✅ **Database Migrations**: Automatically applies schema changes
✅ **Function Deployment**: Updates all Edge Functions
✅ **Verification**: Confirms successful deployment
✅ **Rollback Protection**: Tests pass before deployment

## Manual Deployment (Backup)

If you need to deploy manually:
```bash
cd backend
supabase db push
supabase functions deploy
```

## Environment Variables in Functions

Functions will automatically have access to Supabase environment variables. For custom environment variables like `ANTHROPIC_API_KEY`, add them in the Supabase Dashboard under Project Settings > Edge Functions.