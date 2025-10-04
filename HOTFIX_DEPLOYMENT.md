# HOTFIX: Fix Production Person Creation 500 Error

## 🚨 Issue
Production person creation is failing with 500 error because the database is missing the `started_working_together` column.

## 🔍 Root Cause
- Migration `20250929000001_add_started_working_together.sql` was created
- Edge Functions were deployed to production with code expecting this column
- Database migration was NEVER applied to production
- Result: Production database missing column → 500 error

## ✅ Fix
Apply the missing migration to production database.

---

## 📋 Deployment Instructions

### Prerequisites
- Supabase CLI installed
- Access to production Supabase project (`zfroutbzdkhivnpiezho`)
- Production database password

### Step 1: Link to Production
```bash
cd /Users/jess/code/Mano/backend
supabase link --project-ref zfroutbzdkhivnpiezho
# Enter database password when prompted
```

### Step 2: Verify Migration Status
```bash
# Check what migrations are currently applied
supabase db remote list

# You should see that 20250929000001_add_started_working_together.sql is NOT applied
```

### Step 3: Apply Migration
```bash
# This will apply the missing migration to production
supabase db push

# Confirm when prompted
```

### Step 4: Verify Fix
```bash
# Run smoke tests against production
deno run --allow-net --allow-env scripts/smoke-tests.ts https://zfroutbzdkhivnpiezho.supabase.co

# Test person creation manually (if smoke tests pass)
```

### Step 5: Unlink from Production
```bash
# IMPORTANT: Always unlink after production operations
supabase unlink

# This prevents accidental production operations
```

---

## 🧪 Testing the Fix

After applying migration, test person creation:

1. **Via API:**
   ```bash
   # Test creating a person with started_working_together field
   # (Use production credentials)
   ```

2. **Via iOS App:**
   - Try creating a new person
   - Should succeed without 500 error
   - Initial message should appear

---

## 📊 Expected Outcome

**Before Fix:**
- ❌ Person creation returns 500 error
- ❌ Error in logs: "column started_working_together does not exist"

**After Fix:**
- ✅ Person creation succeeds
- ✅ `started_working_together` field saved correctly
- ✅ Initial message generated
- ✅ No errors in production logs

---

## 🔒 Post-Fix Actions

1. **Verify production is working:**
   - Create a test person in production
   - Verify no 500 errors
   - Check production logs are clean

2. **Unlink from production:**
   - Run `supabase unlink` immediately after

3. **Merge this hotfix PR:**
   - Confirms migration is tracked in git
   - Documents the fix for future reference

4. **Never let this happen again:**
   - Always include migrations in PRs
   - Always test in staging first
   - Always use the new deployment workflow

---

## 📝 Migration Details

**File:** `backend/supabase/migrations/20250929000001_add_started_working_together.sql`

**Changes:**
- Adds `started_working_together DATE` column to `people` table
- Adds comment explaining the field
- Creates index for potential duration queries

**Safe to run:** Yes - additive change only (no data loss)

---

## ⚠️ Important Notes

- This is a **one-time fix** for a migration that should have been applied earlier
- Going forward, ALL migrations MUST go through staging first
- The new CI/CD pipeline will automatically apply migrations
- This hotfix demonstrates why we need the new workflow
