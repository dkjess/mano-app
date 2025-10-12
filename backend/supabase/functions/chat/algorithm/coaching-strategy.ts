/**
 * Coaching Strategy
 *
 * This is THE ALGORITHM for how Mano coaches managers.
 * All the logic for adapting coaching style, tone, and approach lives here.
 *
 * This is where you iterate and experiment. Keep this code readable and clear.
 */

/**
 * Determine coaching guidance based on manager's experience level
 */
export function getExperienceLevelGuidance(level: string | null): string {
  switch(level) {
    case 'new':
      return '(New manager - provide foundational context, explain management concepts when relevant, be extra supportive)'
    case 'experienced':
      return '(Experienced manager - assume management fundamentals, focus on nuanced situations and deeper insights)'
    case 'veteran':
      return '(Veteran manager - skip basics, engage with complex organizational dynamics and strategic thinking)'
    default:
      return '(Management experience level unknown - adapt to their questions)'
  }
}

/**
 * Determine tone guidance based on user preference
 */
export function getToneGuidance(tone: string | null): string {
  switch(tone) {
    case 'direct':
      return '(User prefers DIRECT tone - be concise and straightforward, prioritize actionable advice, minimize pleasantries)'
    case 'warm':
      return '(User prefers WARM tone - be encouraging and supportive, acknowledge emotions and challenges, celebrate wins)'
    case 'conversational':
      return '(User prefers CONVERSATIONAL tone - be casual and friendly like a peer advisor, use natural language)'
    case 'analytical':
      return '(User prefers ANALYTICAL tone - be structured and data-driven, use frameworks and logical reasoning)'
    default:
      return '(Tone preference unknown - use balanced conversational style)'
  }
}

/**
 * Detect the type of problem/situation the manager is facing
 * Returns guidance for how to approach this type of situation
 */
export function detectProblemType(userMessage: string): string {
  const tactical = /\b(meeting|deadline|task|project plan|schedule|agenda|1:1|one.on.one)\b/i.test(userMessage)
  const interpersonal = /\b(conflict|relationship|trust|communication|feedback|difficult conversation|tension|upset|frustrated|angry)\b/i.test(userMessage)
  const strategic = /\b(vision|strategy|direction|roadmap|long.?term|organization|culture|transformation|goals)\b/i.test(userMessage)
  const selfReflection = /\b(i feel|my own|myself|my leadership|my approach|i'm worried|i'm concerned|should i)\b/i.test(userMessage)
  const performance = /\b(performance|underperforming|pip|performance review|not meeting expectations|struggling)\b/i.test(userMessage)

  if (selfReflection) {
    return `\n\nSITUATION TYPE: Self-reflection - Use coaching questions to deepen self-awareness. Help them see patterns in their behavior. Celebrate growth areas while acknowledging challenges. Guide them to their own insights.`
  } else if (interpersonal) {
    return `\n\nSITUATION TYPE: Interpersonal challenge - Explore multiple perspectives. Ask about the other person's motivations and context. Consider what might be driving their behavior. Guide toward empathetic problem-solving.`
  } else if (performance) {
    return `\n\nSITUATION TYPE: Performance management - Balance support and accountability. Help them identify root causes. Discuss both documentation needs and coaching approaches. Be direct but compassionate.`
  } else if (strategic) {
    return `\n\nSITUATION TYPE: Strategic thinking - Ask about goals, stakeholders, and tradeoffs. Connect to team context and organizational impact. Encourage systems thinking and long-term planning.`
  } else if (tactical) {
    return `\n\nSITUATION TYPE: Tactical execution - Provide concrete frameworks and next steps. Focus on action over exploration. Be practical and specific.`
  }

  return '' // No special situation detected
}

/**
 * Determine how long the response should be based on query complexity
 */
export function determineResponseLengthGuidance(
  userMessage: string,
  experienceLevel: string | null,
  conversationHistory: any[]
): string {
  const isComplexQuery = userMessage.length > 200 || /\b(how|why|explain|tell me about|help me understand)\b/i.test(userMessage)
  const isNewManager = experienceLevel === 'new'
  const isQuickQuestion = userMessage.length < 50 && /\b(should i|can i|what about|quick question)\b/i.test(userMessage)

  if (isQuickQuestion) {
    return '1-2 sentences, direct answer'
  } else if (isNewManager && isComplexQuery) {
    return '3-5 sentences with brief context/explanation to support learning'
  } else if (isComplexQuery) {
    return '3-4 sentences with key context'
  } else {
    return '2-3 sentences, concise and actionable'
  }
}

/**
 * Determine whether to use Socratic questioning or direct advice
 * This is a core part of Mano's coaching philosophy
 */
export function determineCoachingApproach(
  userMessage: string,
  conversationHistory: any[],
  experienceLevel: string | null
): string {
  // Detect if user is asking for direct advice vs exploring a problem
  const isSeekingAdvice = /\b(how do i|what should i|give me|tell me|help me|recommend|suggest)\b/i.test(userMessage)
  const isExploring = /\b(thinking about|wondering|not sure|considering|debating|torn between)\b/i.test(userMessage)
  const isUrgent = /\b(urgent|asap|today|right now|immediately|emergency)\b/i.test(userMessage)
  const messageCount = conversationHistory.length

  if (isUrgent) {
    return `\n\nCOACHING APPROACH: Urgent situation - Provide direct, actionable guidance immediately. You can explore nuances after addressing the immediate need.`
  } else if (messageCount < 3 && !isSeekingAdvice && isExploring) {
    // Early in conversation and exploring - use Socratic method
    return `\n\nCOACHING APPROACH: Use Socratic questioning to help the manager articulate their thinking. Ask 1-2 clarifying questions before offering advice. Help them discover insights through reflection. What are they already considering? What assumptions might they examine?`
  } else if (isSeekingAdvice) {
    // Direct advice requested
    return `\n\nCOACHING APPROACH: The manager is seeking direct guidance. Provide actionable advice while still encouraging their critical thinking with one brief follow-up question.`
  } else if (isExploring) {
    // Problem exploration mode
    return `\n\nCOACHING APPROACH: The manager is thinking through a problem. Guide discovery with questions that surface assumptions, stakeholder perspectives, and potential approaches. Ask what they've already considered.`
  }

  return `\n\nCOACHING APPROACH: Balance inquiry and advice. Use questions to deepen understanding when helpful, then provide targeted recommendations.`
}
