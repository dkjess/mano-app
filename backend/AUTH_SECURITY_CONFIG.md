# Auth Security Configuration

These security settings must be configured in the Supabase Dashboard (not via SQL migrations).

## 🔐 Required Configuration Changes

### 1. **OTP Expiry - Reduce to < 1 Hour**

**Current Issue:** OTP expiry exceeds recommended threshold
**Security Risk:** Long-lived OTPs increase the window for brute-force attacks

**Steps to Fix:**
1. Go to: https://supabase.com/dashboard/project/zfroutbzdkhivnpiezho/auth/providers
2. Navigate to: **Authentication** → **Providers** → **Email**
3. Find: **OTP Expiration Time**
4. Set to: **3600 seconds (1 hour)** or less (recommended: 600 seconds / 10 minutes)
5. Click: **Save**

**Recommended Values:**
- **Production:** 600 seconds (10 minutes)
- **Development:** 3600 seconds (1 hour)

**Documentation:** https://supabase.com/docs/guides/platform/going-into-prod#security

---

### 2. **Enable Leaked Password Protection**

**Current Issue:** Leaked password protection is disabled
**Security Risk:** Users can set passwords that have been compromised in data breaches

**Steps to Fix:**
1. Go to: https://supabase.com/dashboard/project/zfroutbzdkhivnpiezho/auth/policies
2. Navigate to: **Authentication** → **Policies**
3. Find: **Leaked Password Protection**
4. Toggle: **Enable leaked password protection**
5. Click: **Save**

**What it does:**
- Checks passwords against HaveIBeenPwned.org database
- Prevents users from setting compromised passwords
- Improves overall account security

**Documentation:** https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

---

## ✅ Verification Steps

After making these changes:

1. **Test OTP Expiry:**
   ```bash
   # Request an OTP
   curl -X POST 'https://zfroutbzdkhivnpiezho.supabase.co/auth/v1/otp' \
     -H "apikey: YOUR_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{"email": "test@example.com"}'

   # Wait for the configured expiry time + 1 minute
   # Try to use the OTP - should fail with "expired" error
   ```

2. **Test Leaked Password Protection:**
   ```bash
   # Try to sign up with a known leaked password (e.g., "password123")
   curl -X POST 'https://zfroutbzdkhivnpiezho.supabase.co/auth/v1/signup' \
     -H "apikey: YOUR_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{"email": "test@example.com", "password": "password123"}'

   # Should return error about compromised password
   ```

---

## 📊 Impact Assessment

**OTP Expiry:**
- ✅ **Minimal user impact** - Most users complete auth within 10 minutes
- ✅ **High security gain** - Reduces attack window by 83% (1 hour → 10 min)

**Leaked Password Protection:**
- ✅ **No impact to existing users** - Only affects new signups and password changes
- ✅ **High security gain** - Prevents use of 600M+ compromised passwords

---

## 🔄 Rollback Plan

If issues arise:

1. **OTP Expiry:** Increase back to previous value in dashboard
2. **Leaked Password Protection:** Toggle off in dashboard

Both changes are reversible without code deployment.

---

## 📝 Notes

- These settings apply to **production** only
- Local development uses default Supabase local settings
- Changes take effect immediately (no deployment required)
- Monitor auth metrics after changes for any signup/login issues
