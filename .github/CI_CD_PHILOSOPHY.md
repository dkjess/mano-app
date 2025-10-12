# CI/CD Philosophy & Check Guidelines

## Core Principle

**CI/CD checks should either reliably pass OR be clearly non-blocking.** If a check frequently fails but you merge anyway, it's just noise and should be removed or fixed.

## Check Categories

### 🚫 BLOCKING Checks (Required to Merge)

These checks **must pass** before merging. They catch real problems that will break production or the codebase.

**Examples:**
- Backend unit tests
- iOS build tests
- TypeScript compilation errors
- Critical security vulnerabilities

**Criteria for blocking checks:**
- **High reliability** - Fails only when there's a real problem
- **Clear failure reasons** - Easy to understand what went wrong
- **Quick to fix** - Developer can fix in minutes, not hours
- **Critical impact** - Failure means broken production or corrupted code

**Current blocking checks:**
- `Backend Tests / Run Backend Unit Tests` - Ensures backend logic works
- `iOS Build Test` - Ensures iOS app compiles

---

### ⚠️ NON-BLOCKING Checks (Advisory Only)

These checks provide helpful information but **don't block merges**. They may have false positives or require manual configuration.

**Examples:**
- Security advisors (may need RLS policy review)
- Performance recommendations (may be intentional design choices)
- Preview branch creation (requires Pro plan)
- Type generation (helpful but not critical)
- Commit message linting (too subjective)

**Criteria for non-blocking checks:**
- **May have false positives** - Sometimes warns when there's no real problem
- **Requires human judgment** - Not a binary pass/fail
- **Requires external setup** - Needs API keys, paid plans, or manual config
- **Nice to have** - Improves quality but not critical

**Current non-blocking checks:**
- `Supabase Security & Performance Advisors` - Advisory recommendations
- `Preview Branch Management` - Requires Pro plan, optional
- `Generate Database Types` - Helpful but not critical
- `Validate Commit Messages` - Too strict, advisory only

---

## When to Add a New Check

### ✅ Add a BLOCKING check if:

1. It catches **critical bugs** that break production
2. It has **<5% false positive rate**
3. Developers can **fix failures in <10 minutes**
4. Failure means **code cannot safely deploy**

### ⚠️ Add a NON-BLOCKING check if:

1. It provides **helpful warnings** but requires human judgment
2. It has **occasional false positives**
3. It requires **external setup** or paid plans
4. It's **informational** rather than critical

### ❌ Don't add a check if:

1. It fails **frequently for non-issues** (too noisy)
2. Failures are **ignored most of the time** (wastes resources)
3. It's **slow** and blocks PRs for >5 minutes
4. You can't clearly explain **why it matters**

---

## Examples of Good vs Bad Checks

### ❌ Bad Check: Strict Commit Message Linting

**Problem:**
- Fails on valid commits (e.g., "fix typo" is fine!)
- Too subjective - blocks PRs for style, not substance
- Developers ignore it and merge anyway

**Solution:**
- Make it non-blocking with `continue-on-error: true`
- OR remove it entirely if no one reads it

### ✅ Good Check: Backend Unit Tests

**Strengths:**
- Catches real bugs before production
- Low false positive rate
- Quick to fix (usually minutes)
- Clear failure messages

**Result:** Keep as blocking check

### ⚠️ Good Non-Blocking Check: Supabase Advisors

**Strengths:**
- Catches missing RLS policies (important!)
- Suggests performance improvements
- Provides helpful context

**Limitations:**
- May require database configuration
- Requires human judgment (is this RLS policy needed?)
- May fail on external API issues

**Result:** Keep as non-blocking advisory check

---

## Configuring Check Behavior

### Make a Check Non-Blocking

Add `continue-on-error: true` at the **job level**:

```yaml
jobs:
  advisory-check:
    name: Advisory Security Check
    runs-on: ubuntu-latest
    continue-on-error: true  # Don't block PRs
    steps:
      - name: Run check
        run: ./check.sh
```

### Make a Check Blocking

Remove `continue-on-error` and ensure it **only fails on real issues**:

```yaml
jobs:
  critical-check:
    name: Critical Test Suite
    runs-on: ubuntu-latest
    steps:
      - name: Run tests
        run: npm test  # Will block if tests fail
```

---

## Workflow Design Patterns

### Pattern 1: Advisory with Comments

For checks that provide helpful information but shouldn't block:

```yaml
jobs:
  advisor:
    name: Security Advisor
    runs-on: ubuntu-latest
    continue-on-error: true
    steps:
      - name: Run security scan
        run: ./scan.sh

      - name: Comment on PR with findings
        if: always()  # Comment even if scan fails
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.createComment({
              body: "⚠️ Security findings: ..."
            });
```

### Pattern 2: Required with Clear Errors

For checks that must pass before merging:

```yaml
jobs:
  tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - name: Run tests
        run: npm test

      - name: Upload test results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: test-results/
```

---

## Decision Tree: Should This Be a CI/CD Check?

```
Is this critical for production safety?
├─ YES → Will it fail often for non-issues?
│         ├─ YES → DON'T ADD (too noisy)
│         └─ NO → ADD AS BLOCKING CHECK ✅
│
└─ NO → Is it helpful advisory information?
          ├─ YES → ADD AS NON-BLOCKING CHECK ⚠️
          └─ NO → DON'T ADD ❌
```

---

## Monitoring Check Health

### Red Flags (Check Needs Fixing):

- ❌ Fails on >50% of PRs
- ❌ Developer merges despite failure >80% of the time
- ❌ Takes >5 minutes to run
- ❌ Failure reason is unclear ("something went wrong")
- ❌ Requires external service that's often down

### Healthy Check Signs:

- ✅ Fails rarely (<10% of PRs)
- ✅ When it fails, developer fixes before merging
- ✅ Runs in <2 minutes
- ✅ Clear, actionable failure messages
- ✅ Reliable and consistent results

---

## Current Workflow Status

### Blocking Checks ✅
- **Backend Tests** - Unit tests for Edge Functions
- **iOS Build Test** - Ensures app compiles

### Non-Blocking Checks ⚠️
- **Supabase Advisors** - Security and performance recommendations
- **Preview Branch Management** - Optional preview environment creation
- **Generate TypeScript Types** - Auto-sync database types
- **Validate Commit Messages** - Advisory commit hygiene

### Removed Checks ❌
- None currently - all checks serve a purpose

---

## Further Reading

- [GitHub Actions: `continue-on-error`](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions#jobsjob_idcontinue-on-error)
- [Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [CI/CD Best Practices](https://docs.github.com/en/actions/deployment/deploying-to-your-cloud-provider)

---

**Last Updated:** 2025-10-12
**Maintainer:** Claude (CTO)
