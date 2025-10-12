/**
 * Profile Intelligence
 *
 * Extract actionable items and insights from AI responses to suggest adding to profiles.
 * This is part of Mano's intelligence - learning from conversations and suggesting follow-ups.
 */

export interface ProfileSuggestion {
  id: string;
  type: string;
  title?: string;
  content: string;
  confidence?: number;
  target_person?: string;
  preview?: string;
}

/**
 * Extract profile suggestions from AI response
 * Looks for action items, insights, and notes that should be saved to person profiles
 */
export function extractProfileSuggestions(
  assistantResponse: string,
  personName: string
): ProfileSuggestion[] {
  console.log('🔍 PROFILE SUGGESTIONS: Starting extraction');
  console.log('🔍 PROFILE SUGGESTIONS: Response preview:', assistantResponse.substring(0, 200));
  console.log('🔍 PROFILE SUGGESTIONS: Person name:', personName);

  const suggestions: ProfileSuggestion[] = [];

  // Simple approach: Find ALL list items in the response
  // Pattern for bullet points: - item
  const bulletPoints = assistantResponse.match(/^[\s]*[-•]\s+(.+)$/gm) || [];

  // Pattern for numbered lists: 1. item, 2. item, etc.
  const numberedItems = assistantResponse.match(/^[\s]*\d+\.\s+(.+)$/gm) || [];

  // Combine all list items
  const allListItems = [...bulletPoints, ...numberedItems];

  console.log('🔍 PROFILE SUGGESTIONS: Found list items:', {
    bulletPoints: bulletPoints.length,
    numberedItems: numberedItems.length,
    total: allListItems.length
  });

  // If we found any list items, create suggestions for them
  if (allListItems.length > 0) {
    // Group items by their position in the response to create logical groupings
    let currentGroup: string[] = [];
    let lastIndex = -1;

    allListItems.forEach((item, index) => {
      const itemIndex = assistantResponse.indexOf(item);

      // If this item is close to the previous one (within 200 chars), group them
      if (lastIndex === -1 || itemIndex - lastIndex < 200) {
        currentGroup.push(item);
      } else {
        // Start a new group
        if (currentGroup.length > 0) {
          const suggestion = createSuggestionFromItems(currentGroup, personName, suggestions.length);
          if (suggestion) suggestions.push(suggestion);
        }
        currentGroup = [item];
      }
      lastIndex = itemIndex;
    });

    // Don't forget the last group
    if (currentGroup.length > 0) {
      const suggestion = createSuggestionFromItems(currentGroup, personName, suggestions.length);
      if (suggestion) suggestions.push(suggestion);
    }
  }

  console.log('🔍 PROFILE SUGGESTIONS: Created suggestions:', suggestions.length);
  return suggestions;
}

/**
 * Create a profile suggestion from a group of related items
 */
export function createSuggestionFromItems(items: string[], personName: string, index: number): ProfileSuggestion | null {
  if (items.length === 0) return null;

  // Clean up the items (remove bullet/number markers)
  const cleanedItems = items.map(item => {
    return item
      .replace(/^[\s]*[-•]\s+/, '')  // Remove bullet points
      .replace(/^[\s]*\d+\.\s+/, '')  // Remove numbers
      .trim();
  });

  // Determine the type based on content
  let type: 'action_items' | 'schedule' | 'notes' | 'insights' = 'action_items';
  const firstItem = cleanedItems[0].toLowerCase();

  if (firstItem.includes('meeting') || firstItem.includes('1:1') || firstItem.includes('schedule')) {
    type = 'schedule';
  } else if (firstItem.includes('note') || firstItem.includes('remember')) {
    type = 'notes';
  } else if (firstItem.includes('insight') || firstItem.includes('observation')) {
    type = 'insights';
  }

  // Format as clean checkbox items (without extra markdown)
  const formattedItems = cleanedItems.map(item => `- [ ] ${item}`);

  // Create appropriate title based on type
  let title = 'Add to Profile';
  let heading = `## Items for ${personName}`;

  switch (type) {
    case 'action_items':
      title = 'Add Action Items';
      heading = `## Action Items for ${personName}`;
      break;
    case 'schedule':
      title = 'Add to Schedule';
      heading = `## Schedule for ${personName}`;
      break;
    case 'notes':
      title = 'Add Notes';
      heading = `## Notes about ${personName}`;
      break;
    case 'insights':
      title = 'Add Insights';
      heading = `## Insights about ${personName}`;
      break;
  }

  const content = `${heading}\n\n${formattedItems.join('\n')}`;
  const preview = items.length === 1
    ? cleanedItems[0].substring(0, 50) + (cleanedItems[0].length > 50 ? '...' : '')
    : `${items.length} items`;

  console.log('🔍 PROFILE SUGGESTIONS: Created suggestion content:', content);
  console.log('🔍 PROFILE SUGGESTIONS: Preview:', preview);

  return {
    id: `${type}_${index}`,
    type,
    title,
    content,
    preview
  };
}
