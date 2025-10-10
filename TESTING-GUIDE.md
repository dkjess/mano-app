# Testing Guide - Enhanced Prompt Personalization

## Environment Setup ✅

Your local environment is ready to test!

```
Supabase API: http://127.0.0.1:54321
Supabase Studio: http://127.0.0.1:54323
Chat Function: http://127.0.0.1:54321/functions/v1/chat

Test User:
  Email: dev@mano.local
  Password: dev123456
```

## Quick Test Scenarios

### 1. Test Experience Level Personalization

**Setup:** Update test user's experience level in Supabase Studio:
- Go to http://127.0.0.1:54323
- Navigate to Table Editor → user_profiles
- Find dev@mano.local user
- Edit `experience_level` field

**Test Cases:**

| Experience Level | Test Message | Expected Behavior |
|-----------------|--------------|-------------------|
| `new` | "How do I give feedback?" | Should provide foundational context, explain concepts, be extra supportive |
| `experienced` | "How do I give feedback?" | Should assume fundamentals, focus on nuanced situations |
| `veteran` | "How do I give feedback?" | Should skip basics, engage with complex organizational dynamics |

### 2. Test Tone Preference

**Setup:** Update `tone_preference` in user_profiles table

**Test Cases:**

| Tone Preference | Test Message | Expected Behavior |
|----------------|--------------|-------------------|
| `direct` | "I'm struggling with a team member" | Concise, straightforward, actionable advice |
| `warm` | "I'm struggling with a team member" | Encouraging, supportive, acknowledges emotions |
| `conversational` | "I'm struggling with a team member" | Casual, friendly, peer advisor style |
| `analytical` | "I'm struggling with a team member" | Structured, framework-based, logical |

### 3. Test Situational Coaching

**No setup needed - just send these messages:**

| Message Type | Test Message | Expected Coaching Approach |
|-------------|--------------|---------------------------|
| Self-reflection | "I feel worried about my leadership style" | Should ask coaching questions to deepen self-awareness |
| Interpersonal | "I have a conflict with my team member Alice" | Should explore multiple perspectives, ask about motivations |
| Performance | "Alice is underperforming on her tasks" | Should balance support and accountability, discuss root causes |
| Strategic | "I'm thinking about our long-term product roadmap" | Should ask about goals, stakeholders, tradeoffs |
| Tactical | "How do I structure my 1:1 meeting agenda?" | Should provide concrete frameworks and next steps |

### 4. Test Socratic Method

**Send messages in sequence to the same conversation:**

1. **First message (exploring):** "I'm thinking about changing my team's sprint format"
   - Expected: Should ask 1-2 clarifying questions before offering advice
   - Example: "What's making you consider this change?" or "What's not working with the current format?"

2. **Second message (seeking advice):** "Tell me how to run better sprint planning"
   - Expected: Should provide direct advice with one follow-up question

3. **Third message (urgent):** "I need to fix this today - urgent issue"
   - Expected: Should provide direct, actionable guidance immediately

### 5. Test Response Length Adaptation

| Message | Expected Length | Why |
|---------|----------------|-----|
| "Should I do daily standups?" | 1-2 sentences | Simple, quick question |
| "How should I approach organizational restructuring and what factors should I consider?" | 3-4 sentences | Complex query |
| "Why is delegation important?" (as new manager) | 3-5 sentences | New manager + complex concept |

### 6. Test Enhanced Challenge Detection

**Setup:** Have several conversations about similar challenges

**Test:**
1. Send 5+ messages about being overwhelmed: "My team is overwhelmed", "Too much work", "Everyone is burning out"
2. Check the context in next response - should include in "CURRENT CHALLENGES DETECTED":
   - Workload Management (or similar)

**Note:** This requires ANTHROPIC_API_KEY in .env.local for LLM-based detection. Without it, falls back to keyword matching.

### 7. Test Cross-Person Mentions

**Setup:** Create multiple people in your team

**Test:**
1. In a conversation about Alice, say: "I think Bob could help mentor Alice"
2. In a conversation about Bob, check if context includes:
   ```
   TEAM CONNECTIONS (Recent cross-person mentions):
   - Alice mentioned Bob: "I think Bob could help mentor Alice"
   ```

## How to View Prompt Context

To see the actual system prompt being sent to Claude:

1. Open browser DevTools (Network tab)
2. Send a chat message
3. Look for request to `/functions/v1/chat`
4. View request payload - the system prompt is in the `messages` array

Or check function logs:
```bash
tail -f /tmp/supabase-functions.log
```

## Verifying Changes Work

### Check User Profile Data
```sql
SELECT call_name, job_role, experience_level, tone_preference
FROM user_profiles
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'dev@mano.local');
```

### Update Test User Profile
```sql
UPDATE user_profiles
SET
  experience_level = 'veteran',
  tone_preference = 'analytical'
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'dev@mano.local');
```

Run this in Supabase Studio → SQL Editor: http://127.0.0.1:54323

## Common Issues

### Functions not updating
```bash
# Restart Edge Functions
pkill -f "supabase functions serve"
supabase functions serve --env-file .env.local > /tmp/supabase-functions.log 2>&1 &
```

### Need fresh test data
```bash
npm run seed:dev reset
npm run seed:dev
```

### Check function logs
```bash
tail -f /tmp/supabase-functions.log
```

## Success Criteria

✅ Experience level changes response depth and complexity
✅ Tone preference changes response style (direct vs warm vs analytical)
✅ Situational detection triggers appropriate coaching approach
✅ Socratic method asks questions vs gives advice based on context
✅ Response length adapts to query complexity
✅ Challenges are detected semantically (with API key) or via keywords
✅ Cross-person mentions appear in team connections

## Next: iOS Testing

Once backend is validated, test in iOS app:
1. Build iOS app: `./scripts/build-test.sh`
2. Run in simulator
3. Sign in as dev@mano.local
4. Test same scenarios in the app
5. Verify responses match expectations

Happy testing! 🎉
