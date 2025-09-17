/**
 * Person-specific initial message generation
 * Creates contextual conversation starters when a new person is added
 */

export interface PersonContext {
  name: string
  role?: string
  relationship_type: 'direct_report' | 'manager' | 'peer' | 'stakeholder'
  team?: string
  context?: string // Why they're being added
  current_situation?: string // What's happening now
}

export interface ManagerContext {
  name?: string
  team_size: number
  has_other_directs: boolean
  management_style?: string
  recent_topics?: string[]
}

interface MessageTemplate {
  primary: string
  followUp?: string
  contextual?: string
}

/**
 * Generate an initial message when a person is added
 */
export function generatePersonInitialMessage(
  person: PersonContext,
  manager: ManagerContext
): string {
  const templates = getTemplatesByRelationship(person.relationship_type)
  
  // Select template based on context
  let template: MessageTemplate
  if (person.current_situation) {
    template = templates.situational
  } else if (person.context) {
    template = templates.contextual
  } else {
    template = templates.default
  }
  
  // Personalize the message
  let message = template.primary
    .replace('[name]', person.name)
    .replace('[role]', person.role || 'their role')
    .replace('[team]', person.team || 'the team')
    .replace('[context]', person.context || '')
    .replace('[situation]', person.current_situation || '')
  
  // Add follow-up if appropriate
  if (template.followUp && shouldAddFollowUp(person, manager)) {
    message += ' ' + template.followUp
      .replace('[name]', person.name)
      .replace('[pronoun]', 'them') // Could be enhanced with proper pronouns
  }
  
  // Add contextual addition if there's specific context
  if (template.contextual && person.context) {
    message += ' ' + template.contextual
      .replace('[context]', person.context)
  }
  
  return message
}

/**
 * Get conversation starters based on relationship type
 */
export function getConversationStarters(
  person: PersonContext,
  includeDeep: boolean = false
): string[] {
  const starters: string[] = []
  
  switch (person.relationship_type) {
    case 'direct_report':
      starters.push(
        `What's ${person.name}'s biggest priority right now?`,
        `How would you describe ${person.name}'s working style?`,
        `What growth opportunities are you considering for ${person.name}?`
      )
      if (includeDeep) {
        starters.push(
          `What motivates ${person.name} most at work?`,
          `What challenges is ${person.name} facing that I should know about?`,
          `How does ${person.name} prefer to receive feedback?`
        )
      }
      break
      
    case 'manager':
      starters.push(
        `What expectations does ${person.name} have for your team?`,
        `How often do you meet with ${person.name}?`,
        `What's the best way to communicate with ${person.name}?`
      )
      if (includeDeep) {
        starters.push(
          `What does ${person.name} value most in team members?`,
          `How can you better support ${person.name}'s objectives?`,
          `What feedback have you received from ${person.name} recently?`
        )
      }
      break
      
    case 'peer':
      starters.push(
        `How do you typically collaborate with ${person.name}?`,
        `What dependencies exist between your work and ${person.name}'s?`,
        `What's ${person.name}'s team focusing on right now?`
      )
      if (includeDeep) {
        starters.push(
          `What can you learn from ${person.name}'s approach?`,
          `How could you and ${person.name} better support each other?`,
          `What shared challenges do you and ${person.name} face?`
        )
      }
      break
      
    case 'stakeholder':
      starters.push(
        `What outcomes does ${person.name} care about most?`,
        `How does ${person.name} prefer to be kept informed?`,
        `What concerns might ${person.name} have about your project?`
      )
      if (includeDeep) {
        starters.push(
          `What success metrics matter most to ${person.name}?`,
          `How can you better align with ${person.name}'s priorities?`,
          `What risks should you discuss with ${person.name}?`
        )
      }
      break
  }
  
  // Add context-specific starters
  if (person.current_situation) {
    starters.unshift(getSituationalStarter(person))
  }
  
  return starters
}

/**
 * Generate profile-building questions
 */
export function getProfileBuildingQuestions(
  person: PersonContext,
  existingProfileFields: string[] = []
): string[] {
  const questions: string[] = []
  const allQuestions = getProfileQuestionsByRelationship(person.relationship_type)
  
  // Filter out questions for fields we already have
  Object.entries(allQuestions).forEach(([field, question]) => {
    if (!existingProfileFields.includes(field)) {
      questions.push(question.replace('[name]', person.name))
    }
  })
  
  return questions.slice(0, 3) // Return top 3 missing profile questions
}

// Private helper functions

function getTemplatesByRelationship(type: string): Record<string, MessageTemplate> {
  const templates: Record<string, Record<string, MessageTemplate>> = {
    direct_report: {
      default: {
        primary: `I see you've added [name] to your team. What's the most important thing you'd like to work on with them right now?`,
        followUp: `Understanding their priorities will help me provide better coaching for your conversations.`
      },
      contextual: {
        primary: `You've added [name] to your team. Given that [context], what specific support do they need from you?`,
        followUp: `I can help you prepare for that conversation.`
      },
      situational: {
        primary: `I see [name] has joined your team and [situation]. How can I help you navigate this?`,
        followUp: `Let's make sure they get the support they need.`
      }
    },
    manager: {
      default: {
        primary: `You've added [name] as your manager. What's the most important thing you need from them right now?`,
        followUp: `Understanding your relationship will help me coach you on managing up effectively.`
      },
      contextual: {
        primary: `I see [name] is your manager. With [context] in mind, how can you best align with their expectations?`
      },
      situational: {
        primary: `You've added [name] as your manager while [situation]. What support do you need from them during this time?`
      }
    },
    peer: {
      default: {
        primary: `I notice you're working with [name]. What's your main collaboration point with them?`,
        followUp: `Understanding your working relationship will help me suggest better collaboration strategies.`
      },
      contextual: {
        primary: `You've added [name] as a peer collaborator. Regarding [context], how can you work together most effectively?`
      },
      situational: {
        primary: `I see you're collaborating with [name] while [situation]. What alignment do you need to establish?`
      }
    },
    stakeholder: {
      default: {
        primary: `You've added [name] as a stakeholder. What outcomes do you need to align on with them?`,
        followUp: `Knowing their priorities will help me coach you on stakeholder management.`
      },
      contextual: {
        primary: `I see [name] is a stakeholder for [context]. What's their main concern or priority?`
      },
      situational: {
        primary: `You've added [name] as a stakeholder during [situation]. How can you best keep them informed and engaged?`
      }
    }
  }
  
  return templates[type] || templates.direct_report
}

function shouldAddFollowUp(person: PersonContext, manager: ManagerContext): boolean {
  // Add follow-up for new relationships or when manager is new
  return !manager.has_other_directs || 
         manager.team_size < 3 ||
         !!person.current_situation
}

function getSituationalStarter(person: PersonContext): string {
  const situation = person.current_situation?.toLowerCase() || ''
  
  if (situation.includes('new') || situation.includes('just joined')) {
    return `What's your onboarding plan for ${person.name}?`
  }
  if (situation.includes('struggling') || situation.includes('challenge')) {
    return `What specific support does ${person.name} need right now?`
  }
  if (situation.includes('promotion') || situation.includes('new role')) {
    return `How is ${person.name} adjusting to their new responsibilities?`
  }
  if (situation.includes('project') || situation.includes('initiative')) {
    return `What's ${person.name}'s role in this initiative?`
  }
  
  return `Tell me more about what's happening with ${person.name} right now.`
}

function getProfileQuestionsByRelationship(type: string): Record<string, string> {
  const baseQuestions = {
    work_style: `How would you describe [name]'s working style?`,
    communication_preferences: `How does [name] prefer to communicate?`,
    strengths: `What are [name]'s key strengths?`,
    growth_areas: `What areas is [name] working to improve?`,
    motivations: `What motivates [name] most at work?`
  }
  
  const relationshipSpecific: Record<string, Record<string, string>> = {
    direct_report: {
      ...baseQuestions,
      career_goals: `What are [name]'s career aspirations?`,
      recent_achievements: `What has [name] accomplished recently?`,
      current_challenges: `What challenges is [name] facing?`,
      learning_style: `How does [name] best learn new skills?`,
      feedback_preferences: `How does [name] prefer to receive feedback?`
    },
    manager: {
      ...baseQuestions,
      expectations: `What does [name] expect from you?`,
      management_style: `How would you describe [name]'s management style?`,
      priorities: `What are [name]'s top priorities?`,
      decision_style: `How does [name] make decisions?`
    },
    peer: {
      ...baseQuestions,
      collaboration_style: `How does [name] approach collaboration?`,
      expertise: `What is [name]'s area of expertise?`,
      team_dynamics: `How does [name]'s team operate?`
    },
    stakeholder: {
      success_metrics: `What metrics does [name] care about?`,
      communication_preferences: `How does [name] prefer updates?`,
      concerns: `What concerns does [name] typically raise?`,
      influence_style: `How does [name] influence decisions?`
    }
  }
  
  return relationshipSpecific[type] || baseQuestions
}

/**
 * Generate a follow-up message after initial conversation
 */
export function generateFollowUpMessage(
  person: PersonContext,
  initialResponse: string,
  extractedInfo: any
): string {
  const hasUsefulInfo = extractedInfo && Object.keys(extractedInfo).length > 0
  
  if (!hasUsefulInfo) {
    return `Thanks for sharing about ${person.name}. Is there anything specific you'd like to prepare for your next conversation with them?`
  }
  
  // Build a response that acknowledges what we learned
  const insights = []
  if (extractedInfo.challenges) {
    insights.push(`the challenges they're facing`)
  }
  if (extractedInfo.strengths) {
    insights.push(`their strengths`)
  }
  if (extractedInfo.priorities) {
    insights.push(`their current priorities`)
  }
  
  let message = `I've noted what you've shared about ${person.name}`
  if (insights.length > 0) {
    message += `, particularly ${insights.join(' and ')}`
  }
  message += `. `
  
  // Add actionable next step
  switch (person.relationship_type) {
    case 'direct_report':
      message += `Would you like me to help you prepare for your next 1:1 with them?`
      break
    case 'manager':
      message += `How can I help you better align with their expectations?`
      break
    case 'peer':
      message += `What collaboration challenges should we work through?`
      break
    case 'stakeholder':
      message += `What's the next milestone you need to align on with them?`
      break
  }
  
  return message
}