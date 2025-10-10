# Future Work: Foundational Coaching/Therapist Prompts

## Context
During onboarding refactor (Oct 2025), we identified that the current approach was too focused on "how users process" rather than creating immediate likeability. We simplified onboarding to focus on tone/personality match first.

## Problem to Solve Later
Early versions of Mano were **too quick to advise** - too eager to solve problems. But effective coaching/therapy works differently:

> "In my experience with mental therapy and coaching, the most sticky behavioral change has come from me finding my own path. Even if it was probably totally planned out by my therapist. They made me come to my own realizations."
> — Product direction from @dkjess

## Key Insight
- **Bad**: Mano jumping to advice and solutions
- **Good**: Using Socratic method to help users discover their own realizations
- **Critical**: The approach depends on the situation - sometimes directive, sometimes exploratory

## Work to Do (Future Branch)

### 1. Foundational Coaching Prompts
- Research and implement Socratic questioning techniques
- Build system prompts that guide toward self-discovery rather than prescriptive advice
- Study effective therapeutic conversation patterns

### 2. Context-Specific Approaches
- Determine when to ask vs. when to advise
- Recognize situations that need different coaching styles
- Adapt approach based on:
  - User's emotional state
  - Type of problem (tactical vs. strategic vs. interpersonal)
  - Stage of problem-solving (exploring vs. deciding vs. executing)

### 3. User Agency
- Always let users maintain control of their own path
- Make insights feel discovered, not prescribed
- Build confidence through guided self-discovery

### 4. Research & Resources
- Study therapeutic conversation models (CBT, motivational interviewing, etc.)
- Review coaching frameworks
- Analyze what makes advice "sticky" vs. forgotten

## Current State (Baseline)
- Onboarding captures: Name, Role/Experience, Tone Preference
- Tone preferences: direct, warm, conversational, analytical
- No explicit coaching methodology implemented yet
- communication_style field exists in DB but set to "balanced" placeholder

## Success Metrics (To Define)
- [ ] User reports feeling heard rather than lectured
- [ ] User experiences "aha moments" in conversations
- [ ] Behavioral change sticks over time
- [ ] User returns to Mano for coaching (not just quick answers)

## Notes
- This is foundational work that affects ALL Mano conversations
- Should be a dedicated branch with research phase
- Consider user testing different prompt approaches
- May want to pilot with subset of users first
