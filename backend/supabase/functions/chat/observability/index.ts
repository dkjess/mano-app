/**
 * Observability Module
 *
 * Provides analytics and performance tracking without cluttering business logic.
 * Export everything from here for easy imports.
 */

export { track, isEnabled as isAnalyticsEnabled } from './analytics.ts'
export { PerformanceTracker } from './performance.ts'

/**
 * Re-export for backward compatibility
 * This allows existing code to use: trackServerEvent(userId, event, props)
 */
export { track as trackServerEvent } from './analytics.ts'
