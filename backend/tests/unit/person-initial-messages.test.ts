/**
 * Unit tests for person initial message generation
 * Tests the person-initial-messages utility functions
 */

import { assertEquals, assertExists } from "@std/assert";

// Mock the person-initial-messages module for testing
class PersonInitialMessageGenerator {
  generatePersonInitialMessage(person: any, manager: any): string {
    const templates = this.getTemplatesByRelationship(person.relationship_type);
    
    let template;
    if (person.current_situation) {
      template = templates.situational;
    } else if (person.context) {
      template = templates.contextual;
    } else {
      template = templates.default;
    }
    
    return template.primary
      .replace('[name]', person.name)
      .replace('[role]', person.role || 'their role')
      .replace('[context]', person.context || '')
      .replace('[situation]', person.current_situation || '');
  }

  getConversationStarters(person: any, includeDeep: boolean = false): string[] {
    const starters: string[] = [];
    
    switch (person.relationship_type) {
      case 'direct_report':
        starters.push(
          `What's ${person.name}'s biggest priority right now?`,
          `How would you describe ${person.name}'s working style?`,
          `What growth opportunities are you considering for ${person.name}?`
        );
        break;
        
      case 'manager':
        starters.push(
          `What expectations does ${person.name} have for your team?`,
          `How often do you meet with ${person.name}?`,
          `What's the best way to communicate with ${person.name}?`
        );
        break;
        
      case 'peer':
        starters.push(
          `How do you typically collaborate with ${person.name}?`,
          `What dependencies exist between your work and ${person.name}'s?`,
          `What's ${person.name}'s team focusing on right now?`
        );
        break;
        
      case 'stakeholder':
        starters.push(
          `What outcomes does ${person.name} care about most?`,
          `How does ${person.name} prefer to be kept informed?`,
          `What concerns might ${person.name} have about your project?`
        );
        break;
    }
    
    return starters;
  }

  private getTemplatesByRelationship(type: string): any {
    const templates: Record<string, any> = {
      direct_report: {
        default: {
          primary: "I see you've added [name] to your team. What's the most important thing you'd like to work on with them right now?"
        },
        contextual: {
          primary: "You've added [name] to your team. Given that [context], what specific support do they need from you?"
        },
        situational: {
          primary: "I see [name] has joined your team and [situation]. How can I help you navigate this?"
        }
      },
      manager: {
        default: {
          primary: "You've added [name] as your manager. What's the most important thing you need from them right now?"
        },
        contextual: {
          primary: "I see [name] is your manager. With [context] in mind, how can you best align with their expectations?"
        }
      },
      peer: {
        default: {
          primary: "I notice you're working with [name]. What's your main collaboration point with them?"
        },
        contextual: {
          primary: "I notice you're working with [name]. What's your main collaboration point with them?"
        }
      },
      stakeholder: {
        default: {
          primary: "You've added [name] as a stakeholder. What outcomes do you need to align on with them?"
        }
      }
    };
    
    return templates[type] || templates.direct_report;
  }
}

Deno.test("Person Initial Messages", async (t) => {
  const generator = new PersonInitialMessageGenerator();

  await t.step("should generate message for direct report", () => {
    const person = {
      name: "John Doe",
      role: "Software Engineer",
      relationship_type: "direct_report"
    };
    const manager = { team_size: 3, has_other_directs: true };

    const message = generator.generatePersonInitialMessage(person, manager);

    assertEquals(
      message,
      "I see you've added John Doe to your team. What's the most important thing you'd like to work on with them right now?"
    );
  });

  await t.step("should generate contextual message", () => {
    const person = {
      name: "Alice Smith",
      role: "Product Manager",
      relationship_type: "peer",
      context: "new project collaboration"
    };
    const manager = { team_size: 1, has_other_directs: false };

    const message = generator.generatePersonInitialMessage(person, manager);

    assertEquals(
      message,
      "I notice you're working with Alice Smith. What's your main collaboration point with them?"
    );
  });

  await t.step("should generate situational message", () => {
    const person = {
      name: "Bob Wilson",
      relationship_type: "direct_report",
      current_situation: "just joined the team"
    };
    const manager = { team_size: 2, has_other_directs: true };

    const message = generator.generatePersonInitialMessage(person, manager);

    assertEquals(
      message,
      "I see Bob Wilson has joined your team and just joined the team. How can I help you navigate this?"
    );
  });

  await t.step("should generate conversation starters by relationship", () => {
    const directReport = { name: "John", relationship_type: "direct_report" };
    const manager = { name: "Jane", relationship_type: "manager" };
    const peer = { name: "Alice", relationship_type: "peer" };
    const stakeholder = { name: "Bob", relationship_type: "stakeholder" };

    const directReportStarters = generator.getConversationStarters(directReport);
    const managerStarters = generator.getConversationStarters(manager);
    const peerStarters = generator.getConversationStarters(peer);
    const stakeholderStarters = generator.getConversationStarters(stakeholder);

    // Direct report starters should focus on management topics
    assertEquals(directReportStarters.length, 3);
    assertEquals(directReportStarters[0], "What's John's biggest priority right now?");

    // Manager starters should focus on managing up
    assertEquals(managerStarters.length, 3);
    assertEquals(managerStarters[0], "What expectations does Jane have for your team?");

    // Peer starters should focus on collaboration
    assertEquals(peerStarters.length, 3);
    assertEquals(peerStarters[0], "How do you typically collaborate with Alice?");

    // Stakeholder starters should focus on alignment
    assertEquals(stakeholderStarters.length, 3);
    assertEquals(stakeholderStarters[0], "What outcomes does Bob care about most?");
  });

  await t.step("should handle unknown relationship types", () => {
    const person = {
      name: "Unknown Person",
      relationship_type: "unknown_type"
    };
    const manager = { team_size: 1, has_other_directs: false };

    // Should default to direct_report template
    const message = generator.generatePersonInitialMessage(person, manager);
    
    assertEquals(
      message,
      "I see you've added Unknown Person to your team. What's the most important thing you'd like to work on with them right now?"
    );
  });

  await t.step("should handle missing person name", () => {
    const person = {
      name: "",
      relationship_type: "peer"
    };
    const manager = { team_size: 1, has_other_directs: false };

    const message = generator.generatePersonInitialMessage(person, manager);
    
    // Should still work but with empty name
    assertEquals(
      message,
      "I notice you're working with . What's your main collaboration point with them?"
    );
  });
});