/**
 * Analytics - PostHog server-side tracking
 *
 * This module provides a clean interface for tracking events without cluttering
 * business logic. PostHog can be disabled by not setting POSTHOG_KEY env var.
 */

const POSTHOG_KEY = Deno.env.get('POSTHOG_KEY')
const POSTHOG_HOST = Deno.env.get('POSTHOG_HOST') || 'https://eu.posthog.com'

export interface AnalyticsEvent {
  distinctId: string
  event: string
  properties?: Record<string, any>
}

/**
 * Track a server-side event to PostHog
 * Silently fails if PostHog is not configured or if tracking fails
 */
export async function track(distinctId: string, event: string, properties: Record<string, any> = {}): Promise<void> {
  if (!POSTHOG_KEY) return // Skip if no key configured

  try {
    await fetch(`${POSTHOG_HOST}/capture/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        api_key: POSTHOG_KEY,
        event,
        distinct_id: distinctId,
        properties: {
          ...properties,
          environment: 'edge_function',
          timestamp: new Date().toISOString(),
        }
      })
    })
  } catch (error) {
    console.warn('PostHog tracking failed:', error)
  }
}

/**
 * Check if analytics is enabled
 */
export function isEnabled(): boolean {
  return !!POSTHOG_KEY
}
