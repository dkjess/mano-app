# Quick Setup Guide - Automated Deployments

## 🎯 Goal
Enable fully automated deployments where you just review and merge PRs - CI/CD does the rest.

---

## One-Time Setup (5 minutes)

### Step 1: Add GitHub Secrets

Go to: https://github.com/dkjess/mano-app/settings/secrets/actions

Click **"New repository secret"** and add each of these:

#### 1. `SUPABASE_ACCESS_TOKEN`
- Go to: https://supabase.com/dashboard/account/tokens
- Click **"Generate new token"**
- Name: "GitHub Actions"
- Copy the token
- Paste into GitHub secret value

#### 2. `SUPABASE_DB_PASSWORD`
- This is your production database password
- The one you use to connect to PostgreSQL
- Get it from: https://supabase.com/dashboard/project/zfroutbzdkhivnpiezho/settings/database
- Copy and paste into GitHub secret value

#### 3. `SUPABASE_ANON_KEY` (optional - for smoke tests)
- Go to: https://supabase.com/dashboard/project/zfroutbzdkhivnpiezho/settings/api
- Copy the "anon" key
- Paste into GitHub secret value

---

### Step 2: Merge Infrastructure PRs

Merge these PRs in order:

1. **PR #3** - Git workflow safeguards and automation
   - https://github.com/dkjess/mano-app/pull/3
   - This adds the CI/CD workflows

2. **PR #4** - Hotfix for production 500 error
   - https://github.com/dkjess/mano-app/pull/4
   - This will AUTO-DEPLOY when merged (if secrets are set up)

---

## ✅ How It Works After Setup

### For Hotfixes (Critical Issues):

1. Create hotfix branch from main
2. Make fix + commit
3. Push and create PR to main
4. **You review PR on GitHub**
5. **You click "Merge"**
6. ✨ **CI/CD automatically:**
   - Links to production
   - Applies database migrations
   - Deploys Edge Functions
   - Runs smoke tests
   - Unlinks from production
   - Shows you the results

**You never touch the terminal!**

### For Regular Features:

1. Create feature branch
2. Make changes + commit
3. Push and create PR to main (or staging if set up)
4. **You review PR on GitHub**
5. **You click "Merge"**
6. ✨ **Same automated deployment**

---

## 🔍 Monitoring Deployments

After merging a PR:

1. Go to: https://github.com/dkjess/mano-app/actions
2. Click on the running "Deploy to Production" workflow
3. Watch it deploy in real-time
4. Check the summary at the end

If anything fails, the workflow stops and shows you the error.

---

## 🚨 Current Situation

**Hotfix PR #4** is ready but WAITING for secrets.

**To fix production now:**

### Option A: Set up secrets first (Recommended)
1. Add the 3 GitHub secrets above (takes 2 minutes)
2. Merge PR #3 (adds workflows)
3. Merge PR #4 (auto-deploys the fix)
4. ✅ Production fixed automatically

### Option B: Manual fix (Faster but one-time)
```bash
cd backend
supabase link --project-ref zfroutbzdkhivnpiezho
supabase db push
supabase unlink
```

Then still set up secrets for future deployments.

---

## 📊 What You Get

**Before (Manual):**
- Write code
- Commit locally
- Push branch
- Create PR
- Review PR
- Merge PR
- ⚠️ Open terminal
- ⚠️ Run supabase commands
- ⚠️ Apply migrations manually
- ⚠️ Deploy functions manually
- ⚠️ Test manually
- ⚠️ Hope nothing broke

**After (Automated):**
- Write code
- Commit locally
- Push branch
- Create PR
- Review PR
- Click "Merge"
- ✅ **Done! CI/CD handles everything**

---

## 🎯 Next Level (Optional)

After this works, you can add:
- Staging environment for testing before production
- Slack notifications on deploy
- Automated rollback on failure
- Performance monitoring
- Error tracking

But for now, this gets you professional automated deployments with minimal setup!
