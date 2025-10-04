# Deployment & Release Process

## 🎯 Goal
Ensure zero-downtime deployments with confidence that code works in production before real users see it.

## 🏗️ Environment Architecture

### Local Development
- **Purpose:** Feature development and testing
- **Supabase:** Local instance (`supabase start`)
- **Database:** Local PostgreSQL with migrations
- **Edge Functions:** Local (`supabase functions serve`)
- **Branch:** Feature branches (`feature/xxx`)

### Staging (Production Preview)
- **Purpose:** Pre-production validation with production-like data
- **Supabase:** Dedicated staging project
- **Database:** Separate staging database with anonymized production data
- **Edge Functions:** Deployed staging functions
- **Branch:** `staging` branch
- **URL:** `staging.mano.app` or Supabase staging project URL

### Production
- **Purpose:** Real users
- **Supabase:** Production project (`zfroutbzdkhivnpiezho`)
- **Database:** Production PostgreSQL
- **Edge Functions:** Production functions
- **Branch:** `main` branch (protected)
- **URL:** `app.mano.app`

---

## 📋 Development Workflow

### 1. Local Development
```bash
# Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/your-feature-name

# Start local environment
cd backend
supabase start
supabase functions serve --env-file .env.local

# Develop and test locally
# - Write code
# - Write tests
# - Run tests: npm run test
# - Manual testing in app

# Run build test before committing
cd ..
./scripts/build-test.sh  # For iOS changes

# Commit changes
git add .
git commit -m "Description"
```

### 2. Database Migrations
**CRITICAL:** Always create migrations for schema changes

```bash
# Create a new migration
cd backend
supabase migration new description_of_change

# Edit the migration file in backend/supabase/migrations/
# Test migration locally
supabase db reset  # Resets and applies all migrations

# Commit migration with your feature
git add backend/supabase/migrations/
git commit -m "Migration: description"
```

### 3. Push Feature Branch & Create PR
```bash
# Push feature branch
git push origin feature/your-feature-name

# Create PR targeting staging branch (NOT main)
gh pr create \
  --base staging \
  --title "Feature: Description" \
  --body "## Summary

What this PR does...

## Changes
- Change 1
- Change 2

## Testing
- [ ] Local tests pass
- [ ] Build succeeds
- [ ] Manually tested locally

## Database Changes
- [ ] Migration included (if schema changes)
- [ ] Migration tested locally
"
```

### 4. PR Review Checklist
Before merging any PR:

- [ ] **Code Review:** At least one approval
- [ ] **Tests Pass:** All automated tests green
- [ ] **Build Succeeds:** iOS build completes without errors
- [ ] **Migrations:** Database migrations included and tested
- [ ] **No Secrets:** No credentials or API keys committed
- [ ] **Breaking Changes:** Documented and communicated
- [ ] **Rollback Plan:** Known how to revert if issues occur

### 5. Deploy to Staging
```bash
# Merge PR to staging branch (via GitHub)
# This triggers automatic staging deployment

# CI/CD will:
# 1. Run all tests
# 2. Apply database migrations to staging DB
# 3. Deploy Edge Functions to staging
# 4. Run smoke tests against staging
```

### 6. Staging Validation
**MANDATORY:** Test in staging before production

```bash
# Test in staging environment
# - Run critical user flows
# - Verify new features work
# - Check database migrations applied correctly
# - Monitor staging logs for errors

# Access staging logs
supabase functions logs function-name --linked  # If linked to staging
```

**Validation Checklist:**
- [ ] Core user flows work (signup, login, create person, chat)
- [ ] New features function as expected
- [ ] No errors in Edge Function logs
- [ ] Database queries perform well
- [ ] iOS app connects and works with staging backend

### 7. Production Deployment
**Only after staging validation passes**

```bash
# Create PR from staging -> main
gh pr create \
  --base main \
  --head staging \
  --title "Release: YYYY-MM-DD - Feature descriptions" \
  --body "## Release Summary

Features included:
- Feature 1
- Feature 2

## Staging Validation
- [x] All tests passed
- [x] Manual testing completed
- [x] No errors in staging logs

## Database Migrations
- Migration 1: description
- Migration 2: description

## Rollback Plan
Revert commits: [commit-hash]
"

# Merge PR to main (requires approval)
# This triggers production deployment

# CI/CD will:
# 1. Run all tests again
# 2. Apply database migrations to production DB
# 3. Deploy Edge Functions to production
# 4. Run smoke tests against production
# 5. Send deployment notification
```

### 8. Post-Deployment Monitoring
```bash
# Monitor production immediately after deployment
# - Check Edge Function logs for errors
# - Monitor error tracking (Sentry/similar)
# - Verify critical paths work

# If issues detected:
# 1. Assess severity
# 2. Roll back if critical
# 3. Fix forward if minor
```

---

## 🚨 Emergency Procedures

### Hotfix Process
For critical production bugs:

```bash
# Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug-description

# Fix the bug
# Write test that catches the bug
# Verify fix locally

# Push and create PR directly to main
git push origin hotfix/critical-bug-description
gh pr create \
  --base main \
  --title "Hotfix: Critical bug description" \
  --label "hotfix"

# Fast-track review and merge
# Deploy immediately
```

### Rollback Procedure
If deployment causes critical issues:

```bash
# Option 1: Revert via Git
git revert <commit-hash>
git push origin main
# CI/CD automatically deploys the revert

# Option 2: Manual rollback (emergency only)
# Revert database migration
supabase db reset --linked  # DANGEROUS - only if necessary
# Redeploy previous Edge Function version
git checkout <previous-commit>
supabase functions deploy --project-ref zfroutbzdkhivnpiezho
```

---

## 🔧 CI/CD Pipeline (GitHub Actions)

### Automated Checks on Every PR
`.github/workflows/pr-checks.yml`

```yaml
name: PR Checks
on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      # Backend tests
      - name: Setup Deno
        uses: denoland/setup-deno@v1

      - name: Run Backend Tests
        run: |
          cd backend
          deno test --allow-all

      # iOS build test
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest

      - name: Build iOS App
        run: ./scripts/build-test.sh

      # Prevent direct main pushes
      - name: Check Branch Protection
        if: github.base_ref == 'main' && github.head_ref != 'staging'
        run: |
          echo "ERROR: Only staging branch can merge to main"
          exit 1
```

### Deploy to Staging
`.github/workflows/deploy-staging.yml`

```yaml
name: Deploy to Staging
on:
  push:
    branches: [staging]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      # Run tests first
      - name: Run Tests
        run: cd backend && deno test --allow-all

      # Deploy to staging Supabase project
      - name: Deploy Edge Functions
        run: |
          cd backend
          supabase functions deploy --project-ref ${{ secrets.STAGING_PROJECT_REF }}
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      # Apply migrations
      - name: Apply Migrations
        run: |
          cd backend
          supabase db push --project-ref ${{ secrets.STAGING_PROJECT_REF }}
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      # Run smoke tests
      - name: Smoke Tests
        run: |
          cd backend
          deno run --allow-net scripts/smoke-tests.ts ${{ secrets.STAGING_API_URL }}
```

### Deploy to Production
`.github/workflows/deploy-production.yml`

```yaml
name: Deploy to Production
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Requires approval
    steps:
      - uses: actions/checkout@v3

      # Run all tests
      - name: Run Tests
        run: cd backend && deno test --allow-all

      # Apply migrations FIRST (before code deploy)
      - name: Apply Database Migrations
        run: |
          cd backend
          supabase db push --project-ref zfroutbzdkhivnpiezho
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      # Deploy Edge Functions
      - name: Deploy Edge Functions
        run: |
          cd backend
          supabase functions deploy --project-ref zfroutbzdkhivnpiezho
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      # Smoke tests
      - name: Production Smoke Tests
        run: |
          cd backend
          deno run --allow-net scripts/smoke-tests.ts https://zfroutbzdkhivnpiezho.supabase.co

      # Notify team
      - name: Deployment Notification
        run: echo "Production deployment complete"
```

---

## 📝 Required Setup

### 1. Create Staging Environment
```bash
# Create new Supabase project for staging
# - Name: mano-staging
# - Region: Same as production
# - Plan: Free tier is fine for staging

# Save staging project ref as GitHub secret:
# STAGING_PROJECT_REF = your-staging-project-ref
```

### 2. Protect Branches
In GitHub repository settings:

**Main Branch:**
- ✅ Require pull request reviews (1 approval)
- ✅ Require status checks to pass
- ✅ Require branches to be up to date
- ✅ Restrict who can push (Admins only)
- ✅ Only allow staging branch to merge

**Staging Branch:**
- ✅ Require pull request reviews
- ✅ Require status checks to pass
- ✅ Allow feature branches to merge

### 3. GitHub Secrets
Add to repository secrets:
- `SUPABASE_ACCESS_TOKEN` - For deploying functions
- `STAGING_PROJECT_REF` - Staging project reference
- `ANTHROPIC_API_KEY` - For running tests
- `SUPABASE_DB_PASSWORD` - For migrations

### 4. Create Smoke Test Script
`backend/scripts/smoke-tests.ts`

```typescript
#!/usr/bin/env -S deno run --allow-net

const BASE_URL = Deno.args[0] || 'http://localhost:54321';

async function smokeTest() {
  console.log('🧪 Running smoke tests against:', BASE_URL);

  // Test 1: Health check
  const health = await fetch(`${BASE_URL}/functions/v1/health`);
  if (!health.ok) throw new Error('Health check failed');

  // Test 2: Person creation (with test user)
  // Add more critical path tests

  console.log('✅ All smoke tests passed');
}

smokeTest().catch(err => {
  console.error('❌ Smoke tests failed:', err);
  Deno.exit(1);
});
```

---

## 🎯 Migration Strategy for Current State

### Immediate Actions (This Week)

1. **Fix Production Now:**
   ```bash
   # Apply the missing migration to production
   cd backend
   supabase db push --project-ref zfroutbzdkhivnpiezho
   ```

2. **Create Staging Environment:**
   - Create new Supabase project for staging
   - Configure with same schema as production

3. **Set Up Branch Protection:**
   - Protect `main` branch
   - Protect `staging` branch
   - Create staging branch from current main

4. **Create Basic CI/CD:**
   - Add PR checks workflow
   - Add staging deployment workflow
   - Add production deployment workflow

### This Month (Before Real Users)

1. **Implement All CI/CD Pipelines**
2. **Document Runbooks for Common Issues**
3. **Set Up Monitoring & Alerting**
4. **Create Staging → Production Checklist**
5. **Train Team on New Process**

---

## 📚 Best Practices

### Database Migrations
- **Always** create migrations for schema changes
- **Never** modify existing migrations that have run in production
- **Test** migrations work both up and down
- **Apply** migrations before deploying code that depends on them

### Testing
- **Write tests** for all new features
- **Run tests** locally before pushing
- **Validate** in staging before production
- **Monitor** production after deployment

### Communication
- **Document** what each release includes
- **Announce** deployments in team channel
- **Post** in #incidents if issues occur
- **Update** status page during incidents

### Monitoring
- **Check logs** after every deployment
- **Set up alerts** for error rates
- **Monitor performance** metrics
- **Track** user-facing errors

---

## 🔗 Quick Reference

**Deployment Checklist:**
- [ ] Tests pass locally
- [ ] Build succeeds
- [ ] Migrations created (if needed)
- [ ] PR reviewed and approved
- [ ] Deployed to staging
- [ ] Validated in staging
- [ ] PR to main created
- [ ] Production deployment approved
- [ ] Monitoring after deployment
- [ ] No errors in production logs

**Emergency Contacts:**
- Production issues: [your contact]
- Database issues: [your contact]
- CI/CD issues: [your contact]
