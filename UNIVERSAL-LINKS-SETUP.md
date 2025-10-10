# Universal Links Setup Guide

Universal Links allow magic links to open the app directly without going through Safari.

## Step 1: Get Your Team ID

1. Go to https://developer.apple.com/account
2. Click "Membership" in the sidebar
3. Copy your **Team ID** (format: `ABC1234DEF`)

## Step 2: Update AASA File

1. Open `apple-app-site-association.json`
2. Replace `TEAM_ID` with your actual Team ID:
   ```json
   "appID": "ABC1234DEF.ai.supermano.Mano"
   ```

## Step 3: Host AASA File

The file must be hosted at:
```
https://supermano.ai/.well-known/apple-app-site-association
```

**Requirements:**
- Must be served over HTTPS
- Content-Type: `application/json` (some servers work without this)
- No redirect (direct 200 response)
- No file extension in the URL

**Hosting Options:**

### Option A: Static Site (Vercel/Netlify/Cloudflare Pages)
```bash
# Create .well-known directory in your site
mkdir -p public/.well-known
cp apple-app-site-association.json public/.well-known/apple-app-site-association
# Deploy site
```

### Option B: GitHub Pages
```bash
# In your website repo
mkdir -p .well-known
cp apple-app-site-association.json .well-known/apple-app-site-association
git add .well-known/
git commit -m "Add AASA file for iOS Universal Links"
git push
```

### Option C: Custom Server
```nginx
# Nginx config
location /.well-known/apple-app-site-association {
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    alias /path/to/apple-app-site-association;
}
```

## Step 4: Verify AASA File

Test that it's accessible:
```bash
curl https://supermano.ai/.well-known/apple-app-site-association
```

Or use Apple's validator:
https://search.developer.apple.com/appsearch-validation-tool/

## Step 5: Configure Xcode

1. Open `Mano.xcodeproj` in Xcode
2. Select the **Mano** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** button
5. Add **Associated Domains**
6. Add domain:
   ```
   applinks:supermano.ai
   ```

## Step 6: Update Supabase Configuration

In Supabase Dashboard → Authentication → URL Configuration:

**Site URL:**
```
https://supermano.ai
```

**Additional Redirect URLs:**
```
https://supermano.ai/auth/callback
https://supermano.ai/login-callback
mano://login-callback
```

## Step 7: Update Magic Link Code

Change the redirectTo URL in SupabaseAuthManager:

```swift
try await client.auth.signInWithOTP(
    email: actualEmail,
    redirectTo: URL(string: "https://supermano.ai/login-callback"),  // Changed from mano://
    shouldCreateUser: true
)
```

## Step 8: Update Deep Link Handler

Add universal link handling in ManoApp:

```swift
.onOpenURL { url in
    print("🔗 Received URL: \(url)")
    handleLink(url)
}
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
    guard let url = userActivity.webpageURL else { return }
    print("🌐 Received universal link: \(url)")
    handleLink(url)
}

private func handleLink(_ url: URL) {
    Task {
        do {
            try await SupabaseManager.shared.auth.handleDeepLink(url: url)
        } catch {
            print("❌ Failed to handle link: \(error)")
        }
    }
}
```

## Testing

1. **Build and install app on device** (must be real device, not simulator)
2. **Send magic link email**
3. **Open email on device**
4. **Tap link** - should open app directly

### Troubleshooting

**Link still opens in Safari:**
- AASA file not found or invalid JSON
- Team ID incorrect in AASA file
- Bundle ID mismatch
- Domain not added to Associated Domains in Xcode
- iOS cache issue - wait 24 hours or reset device

**Clear iOS cache:**
```bash
# Uninstall app
# Restart device
# Reinstall app
```

**Check AASA in iOS:**
```bash
# On Mac with device connected
xcrun simctl openurl booted https://supermano.ai/login-callback
```

## Fallback

Universal Links maintain backward compatibility:
- If app is not installed → opens in browser
- Custom URL scheme (`mano://`) still works as fallback

## Production Checklist

- [ ] Team ID added to AASA file
- [ ] AASA file hosted at correct URL with HTTPS
- [ ] AASA file returns 200 (not 404 or redirect)
- [ ] Associated Domains added in Xcode
- [ ] App built with updated entitlements
- [ ] Tested on real device
- [ ] Supabase redirect URLs configured
- [ ] Magic link tested end-to-end
