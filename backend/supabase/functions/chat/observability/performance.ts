/**
 * Performance Tracking
 *
 * Tracks timing checkpoints throughout request lifecycle and reports
 * performance metrics to analytics.
 */

import { track } from './analytics.ts'

export class PerformanceTracker {
  private startTime: number
  private checkpoints: { [key: string]: number } = {}
  private userId: string
  private requestId: string

  constructor(userId: string, requestId: string) {
    this.startTime = Date.now()
    this.userId = userId
    this.requestId = requestId
    this.checkpoints.request_start = this.startTime
  }

  /**
   * Record a timing checkpoint
   */
  checkpoint(name: string): void {
    this.checkpoints[name] = Date.now()
  }

  /**
   * Get duration between two checkpoints in milliseconds
   */
  getDuration(from: string, to?: string): number {
    const fromTime = this.checkpoints[from] || this.startTime
    const toTime = to ? this.checkpoints[to] : Date.now()
    return toTime - fromTime
  }

  /**
   * Track completion and send performance metrics to analytics
   */
  async trackCompletion(eventData: Record<string, any> = {}): Promise<void> {
    const totalDuration = Date.now() - this.startTime

    await track(this.userId, 'edge_function_performance', {
      request_id: this.requestId,
      total_duration_ms: totalDuration,
      context_build_duration_ms: this.getDuration('request_start', 'context_complete'),
      anthropic_duration_ms: this.getDuration('anthropic_start', 'anthropic_complete'),
      intelligence_duration_ms: this.getDuration('intelligence_start', 'intelligence_complete'),
      streaming_duration_ms: this.getDuration('streaming_start', 'streaming_complete'),
      ...eventData
    })
  }

  /**
   * Get total duration since tracker creation
   */
  getTotalDuration(): number {
    return Date.now() - this.startTime
  }

  /**
   * Get all checkpoint names
   */
  getCheckpoints(): string[] {
    return Object.keys(this.checkpoints)
  }
}
