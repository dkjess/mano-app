# PR Template

<!-- DELETE THIS COMMENT BLOCK AFTER READING:
Choose ONE deployment type badge below and delete the others.
This tells the reviewer exactly what they need to do after merging.
-->

## 🚀 Deployment Type

<!-- Keep only ONE of these badges: -->

### 📱 **App Only** - Rebuild Required
> **After merging:** Rebuild app in Xcode (⇧⌘K then ⌘R) to see changes on your device.
> No backend deployment happens.

<!-- OR -->

### ☁️ **Backend Only** - Auto-Deploy
> **After merging:** Changes automatically deploy to production via CI/CD.
> No app rebuild needed - works immediately.

<!-- OR -->

### 🔄 **App + Backend** - Both Required
> **After merging:**
> 1. Backend auto-deploys to production
> 2. Rebuild app in Xcode (⇧⌘K then ⌘R) to see changes

<!-- OR -->

### 📚 **Docs/Config Only** - No Action Required
> **After merging:** No deployment or rebuild needed.
> Documentation/configuration only.

---

## What's this?

Brief description of what this PR does...

## What changed

- Change 1
- Change 2
- Change 3

## Why this matters

Explain the impact...

## Testing

- [ ] Tested locally
- [ ] Build succeeds
- [ ] Works as expected

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
