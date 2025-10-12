/**
 * Algorithm Module - Mano's Core Intelligence
 *
 * This is THE ALGORITHM - how Mano coaches, what prompts it uses, and how it learns.
 * Everything exported here is part of Mano's personality and coaching approach.
 *
 * Import from here to keep the main chat handler clean.
 */

// Coaching Strategy
export {
  getExperienceLevelGuidance,
  getToneGuidance,
  detectProblemType,
  determineResponseLengthGuidance,
  determineCoachingApproach
} from './coaching-strategy.ts'

// Prompt Composition
export {
  SYSTEM_PROMPT,
  SELF_SYSTEM_PROMPT,
  GENERAL_SYSTEM_PROMPT,
  PROFILE_SETUP_PROMPT,
  buildSystemPrompt,
  buildPersonSystemPrompt,
  buildGeneralSystemPrompt
} from './prompt-composer.ts'

// Profile Intelligence
export {
  extractProfileSuggestions,
  createSuggestionFromItems,
  type ProfileSuggestion
} from './profile-intelligence.ts'
