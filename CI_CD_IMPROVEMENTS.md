# CI/CD Improvements with MCP Integration

This document describes the new CI/CD workflows added to leverage GitHub and Supabase MCP (Model Context Protocol) integration.

## New Workflows

### 1. PR Auto-Labeling (`.github/workflows/pr-auto-label.yml`)

**Purpose:** Automatically label PRs with deployment type badges and add instructions to PR descriptions.

**Features:**
- Detects changes in backend (Edge Functions, migrations) vs iOS (SwiftUI, Xcode)
- Adds deployment type labels:
  - 📱 **App Only - Rebuild Required**
  - ☁️ **Backend Only - Auto-Deploy**
  - 🔄 **App + Backend - Both Required**
  - 📚 **Docs/Config Only - No Action Required**
- Automatically adds deployment badge to PR description
- Comments on PR with detailed deployment instructions

**Triggers:** When PR is opened, synchronized, or reopened

**Benefits:**
- Saves time reviewing PRs - immediately see deployment type
- Clear instructions for Jess on what deployment actions are needed
- Prevents confusion about whether app rebuild is required

---

### 2. Supabase Security & Performance Advisors (`.github/workflows/supabase-advisors.yml`)

**Purpose:** Run automated security and performance checks on database changes.

**Features:**
- Checks for tables without RLS (Row Level Security) policies
- Detects missing indexes on foreign keys
- Verifies migration safety
- Comments on PRs with security warnings and performance recommendations

**Triggers:** PRs or pushes that modify migrations or Edge Functions

**What it checks:**
- **Security:**
  - Tables missing RLS policies
  - Potential data exposure risks
- **Performance:**
  - Missing indexes on foreign keys
  - Potential query performance issues

**Benefits:**
- Catches security issues before production deployment
- Identifies performance problems early
- Reduces manual code review burden
- Enforces best practices automatically

---

### 3. Preview Branch Management (`.github/workflows/preview-branch.yml`)

**Purpose:** Automate creation and cleanup of Supabase preview branches for PRs.

**Features:**
- Creates Supabase preview branch for each PR with database changes
- Provides instructions for manual branch creation (requires Pro plan)
- Automatically cleans up preview branch when PR is closed
- Comments on PR with preview branch details and API URL

**Triggers:** PRs with backend changes (opened, synchronized, closed)

**Benefits:**
- Test migrations on production-like environment without affecting production
- Run integration tests safely
- Experiment with risky schema changes
- Preview branches automatically deleted on PR close

**Note:** Supabase preview branches require Supabase Pro plan or higher. The workflow provides instructions for manual creation via the dashboard.

---

### 4. Auto-Generate TypeScript Types (`.github/workflows/generate-types.yml`)

**Purpose:** Automatically regenerate TypeScript types when database schema changes.

**Features:**
- Detects migration changes
- Applies migrations to local Supabase instance
- Generates TypeScript types from resulting schema
- Commits updated types back to the PR or main branch
- Comments on PR with type change summary

**Triggers:** PRs or pushes to main that modify migrations

**Output:** Updates `backend/supabase/types/database.types.ts`

**Benefits:**
- Always keep TypeScript types in sync with database schema
- No manual type generation needed
- Catch type mismatches before deployment
- Improves developer experience with accurate autocomplete

---

### 5. Enhanced Deployment Verification (`.github/workflows/deploy-production.yml`)

**Purpose:** Add post-deployment verification using MCP to ensure deployment succeeded.

**Features:**
- Verifies migrations applied successfully
- Checks Edge Functions are responding
- Validates core database tables exist
- Confirms RLS policies are in place
- Detailed verification report in GitHub Actions summary

**Triggers:** After production deployment to main branch

**What it verifies:**
- ✅ Latest migration applied
- ✅ Edge Functions (`chat`, `person`) responding
- ✅ Core tables (`people`, `conversations`, `messages`) exist
- ✅ Deployment health checks pass

**Benefits:**
- Catch deployment failures immediately
- Automated rollback trigger if verification fails
- Confidence that production is working after deployment
- Clear deployment audit trail

---

## How MCP Powers These Workflows

### GitHub MCP Integration

The workflows use GitHub MCP to:
- Create/update PRs programmatically
- Add labels and comments automatically
- Read PR metadata and changed files
- Manage PR lifecycle (open, update, close)

### Supabase MCP Integration

The workflows use Supabase MCP to:
- Query production database for verification
- Run security and performance advisors
- Manage preview branches programmatically
- Generate TypeScript types from live schema
- Execute SQL queries for health checks

---

## Setup Requirements

### GitHub Secrets

These secrets must be configured in GitHub repository settings:

- `SUPABASE_ACCESS_TOKEN` - Supabase management API token
- `SUPABASE_DB_PASSWORD` - Production database password
- `SUPABASE_ANON_KEY` - Production anonymous API key

### GitHub Permissions

The workflows require these permissions:

```yaml
permissions:
  contents: write        # For committing type changes
  pull-requests: write   # For commenting and labeling
```

### Supabase Configuration

- **Production Project ID:** `zfroutbzdkhivnpiezho`
- **Preview Branches:** Requires Supabase Pro plan (optional feature)
- **RLS Policies:** Should be enabled on all user-facing tables

---

## Testing the Workflows

### Test PR Auto-Labeling

1. Create a PR with only backend changes
2. Verify it gets labeled "☁️ Backend Only"
3. Check PR description has deployment badge

### Test Supabase Advisors

1. Create a migration that adds a table without RLS
2. Open PR
3. Verify workflow comments with security warning

### Test Type Generation

1. Create a migration that modifies a table
2. Open PR
3. Verify `database.types.ts` gets updated automatically

### Test Deployment Verification

1. Merge a PR to main
2. Check GitHub Actions for deployment workflow
3. Verify post-deployment checks pass

---

## Troubleshooting

### Workflow Fails to Comment on PR

**Issue:** GitHub Actions can't comment on PR

**Solution:** Check that `GITHUB_TOKEN` has `pull-requests: write` permission

### Supabase Link Fails

**Issue:** Cannot link to production project

**Solution:** Verify `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD` secrets are correct

### Type Generation Fails

**Issue:** Cannot generate types

**Solution:** Ensure migrations are valid and Supabase local instance starts successfully

### Preview Branch Not Created

**Issue:** Preview branch creation requires manual confirmation

**Solution:** This is expected - preview branches require Supabase Pro plan and cost confirmation. Follow the workflow's instructions to create manually via dashboard.

---

## Future Enhancements

### Potential Next Steps

1. **Migration impact analysis** - Estimate rows affected by migrations
2. **Performance regression detection** - Track query performance over time
3. **Auto-rollback on failure** - Create rollback PR if deployment fails
4. **Cost estimation** - Warn about migrations that could be expensive
5. **Database usage analytics** - Track table sizes and query patterns
6. **Integration test against preview branch** - Run full test suite on preview environment

### Long-term Vision

- **Zero-touch deployments** - Fully automated from PR merge to production
- **Predictive analysis** - AI-powered migration risk assessment
- **Self-healing** - Automatic detection and fixing of common issues
- **Multi-environment management** - Staging, QA, production orchestration

---

## Architecture Decisions

### Why These Workflows?

**Problem:** Manual deployment steps are error-prone and time-consuming

**Solution:** Automate repetitive tasks with MCP-powered workflows

**Result:** Faster, safer deployments with better visibility

### Why MCP Integration?

**Alternative:** Use REST APIs directly

**Chosen:** MCP provides higher-level abstractions and better developer experience

**Benefits:**
- Simplified API calls
- Better error handling
- Consistent patterns across tools
- Built-in rate limiting and retries

---

## Related Documentation

- [CLAUDE.md](./CLAUDE.md) - Git workflow and deployment rules
- [PR_TEMPLATE.md](./.github/PR_TEMPLATE.md) - PR template with deployment badges
- [README.md](./README.md) - Main project documentation

---

## Changelog

**2025-01-12** - Initial MCP-enhanced CI/CD implementation
- Added PR auto-labeling workflow
- Added Supabase advisors workflow
- Added preview branch management
- Added auto-generate types workflow
- Enhanced deployment verification

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
