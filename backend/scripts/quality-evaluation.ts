#!/usr/bin/env node
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321'
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'

interface QualityMetrics {
  relevance: number       // 1-10: How well does it address the question?
  actionability: number   // 1-10: How specific and actionable is the advice?
  contextUsage: number    // 1-10: How well does it use person/team context?
  completeness: number    // 1-10: How thoroughly does it cover the topic?
  naturalness: number     // 1-10: How conversational and natural is the tone?
  brevity: number         // 1-10: Is it appropriately concise (higher = better)?
}

interface ModelComparison {
  model: string
  response: string
  responseTime: number
  tokenCount: number
  metrics: QualityMetrics
  overallScore: number
}

class QualityEvaluator {
  private supabase: any
  private session: any
  private person: any
  
  private testQuestions = [
    "What are the key challenges Sarah is facing with her current project?",
    "How can I help Alice improve her communication skills?",
    "What management approach would work best for Mark's personality?",
    "How should I handle the team conflict between John and Lisa?",
    "What career development opportunities should I discuss with Emma?",
    "How can I better support the team's remote work challenges?",
    "What delegation strategies would help reduce my workload?",
    "How should I approach the upcoming performance review with David?"
  ]

  constructor() {
    this.supabase = createClient(supabaseUrl, supabaseKey)
  }

  async setup() {
    console.log('🔧 Setting up quality evaluation...\n')
    
    // Auth
    const { data: authData, error: authError } = await this.supabase.auth.signInWithPassword({
      email: 'dev@mano.local',
      password: 'dev123456'
    })
    
    if (authError) throw new Error(`Auth failed: ${authError.message}`)
    this.session = authData.session
    
    // Get person
    const { data: people } = await this.supabase.from('people').select('*').limit(1)
    this.person = people[0]
    
    console.log('✅ Setup complete\n')
  }

  async testModelResponse(question: string, model: string): Promise<ModelComparison> {
    console.log(`🧪 Testing ${model} with: "${question.substring(0, 50)}..."`)
    
    const startTime = Date.now()
    
    // Make request with specific model
    const response = await fetch(`${supabaseUrl}/functions/v1/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.session.access_token}`
      },
      body: JSON.stringify({
        action: 'streaming_chat',
        messages: [{ role: 'user', content: question }],
        person_id: this.person.id,
        model: model // We'll need to add this parameter
      })
    })

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${await response.text()}`)
    }

    // Read response
    const reader = response.body?.getReader()
    let fullResponse = ''
    
    if (reader) {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        fullResponse += new TextDecoder().decode(value)
      }
    }

    const responseTime = Date.now() - startTime
    
    // Extract actual response content (remove AI SDK formatting)
    const cleanResponse = this.cleanResponse(fullResponse)
    
    // Calculate metrics
    const metrics = this.calculateMetrics(question, cleanResponse)
    const overallScore = this.calculateOverallScore(metrics)

    console.log(`   ⏱️  ${responseTime}ms | Score: ${overallScore.toFixed(1)}/10`)
    
    return {
      model,
      response: cleanResponse,
      responseTime,
      tokenCount: this.estimateTokens(cleanResponse),
      metrics,
      overallScore
    }
  }

  private cleanResponse(rawResponse: string): string {
    // Remove AI SDK formatting and extract actual content
    const lines = rawResponse.split('\n')
    let content = ''
    
    for (const line of lines) {
      if (line.startsWith('0:')) {
        try {
          const parsed = JSON.parse(line.substring(2))
          content += parsed
        } catch (e) {
          // Skip malformed lines
        }
      }
    }
    
    return content || rawResponse
  }

  private calculateMetrics(question: string, response: string): QualityMetrics {
    // Simple heuristic-based scoring (could be enhanced with AI evaluation)
    
    const relevance = this.scoreRelevance(question, response)
    const actionability = this.scoreActionability(response)
    const contextUsage = this.scoreContextUsage(response)
    const completeness = this.scoreCompleteness(question, response)
    const naturalness = this.scoreNaturalness(response)
    const brevity = this.scoreBrevity(response)

    return {
      relevance,
      actionability,
      contextUsage,
      completeness,
      naturalness,
      brevity
    }
  }

  private scoreRelevance(question: string, response: string): number {
    // Check if response addresses key terms from question
    const questionTerms = question.toLowerCase().split(/\s+/)
    const responseText = response.toLowerCase()
    
    let matches = 0
    for (const term of questionTerms) {
      if (term.length > 3 && responseText.includes(term)) {
        matches++
      }
    }
    
    return Math.min(10, (matches / questionTerms.length) * 15)
  }

  private scoreActionability(response: string): number {
    // Look for actionable language
    const actionWords = ['try', 'consider', 'start', 'focus', 'schedule', 'ask', 'discuss', 'implement', 'create', 'set up']
    const responseText = response.toLowerCase()
    
    let score = 0
    for (const word of actionWords) {
      if (responseText.includes(word)) score += 1
    }
    
    // Bonus for specific suggestions
    if (responseText.includes('specific') || responseText.includes('concrete')) score += 2
    if (responseText.includes('next step') || responseText.includes('follow up')) score += 2
    
    return Math.min(10, score)
  }

  private scoreContextUsage(response: string): number {
    // Check for person name and context references
    const responseText = response.toLowerCase()
    let score = 0
    
    if (responseText.includes(this.person.name.toLowerCase())) score += 3
    if (responseText.includes('team') || responseText.includes('relationship')) score += 2
    if (responseText.includes('previous') || responseText.includes('mentioned')) score += 2
    if (responseText.includes('role') || responseText.includes('position')) score += 2
    
    return Math.min(10, score)
  }

  private scoreCompleteness(question: string, response: string): number {
    // Basic completeness check
    const responseLength = response.length
    
    if (responseLength < 50) return 2
    if (responseLength < 100) return 4
    if (responseLength < 200) return 6
    if (responseLength < 300) return 8
    return 10
  }

  private scoreNaturalness(response: string): number {
    // Check for conversational tone
    const responseText = response.toLowerCase()
    let score = 5 // baseline
    
    // Good indicators
    if (responseText.includes('?')) score += 1 // asks questions
    if (responseText.includes('you')) score += 1 // direct address
    if (responseText.includes('let\'s') || responseText.includes('we\'ll')) score += 1 // collaborative
    
    // Bad indicators
    if (responseText.includes('furthermore') || responseText.includes('additionally')) score -= 1
    if (responseText.includes('in conclusion') || responseText.includes('to summarize')) score -= 1
    
    return Math.min(10, Math.max(1, score))
  }

  private scoreBrevity(response: string): number {
    // Mano should be concise (2-4 sentences ideal)
    const sentences = response.split(/[.!?]+/).filter(s => s.trim().length > 0)
    const sentenceCount = sentences.length
    
    if (sentenceCount <= 2) return 6 // too short
    if (sentenceCount <= 4) return 10 // perfect
    if (sentenceCount <= 6) return 8 // good
    if (sentenceCount <= 8) return 6 // okay
    return 4 // too long
  }

  private calculateOverallScore(metrics: QualityMetrics): number {
    // Weighted average based on importance
    const weights = {
      relevance: 0.25,
      actionability: 0.25,
      contextUsage: 0.20,
      completeness: 0.15,
      naturalness: 0.10,
      brevity: 0.05
    }
    
    return (
      metrics.relevance * weights.relevance +
      metrics.actionability * weights.actionability +
      metrics.contextUsage * weights.contextUsage +
      metrics.completeness * weights.completeness +
      metrics.naturalness * weights.naturalness +
      metrics.brevity * weights.brevity
    )
  }

  private estimateTokens(text: string): number {
    // Rough token estimation (4 chars ≈ 1 token)
    return Math.ceil(text.length / 4)
  }

  async runComparison() {
    console.log('🎯 Starting Model Quality Comparison\n')
    console.log('='*60 + '\n')
    
    const results: ModelComparison[] = []
    
    for (const question of this.testQuestions.slice(0, 3)) { // Test first 3 questions
      console.log(`📝 Question: "${question}"\n`)
      
      try {
        // Test both models
        const sonnetResult = await this.testModelResponse(question, 'claude-sonnet-4-20250514')
        await new Promise(resolve => setTimeout(resolve, 1000)) // Brief pause
        
        const haikuResult = await this.testModelResponse(question, 'claude-3-haiku-20240307')
        
        results.push(sonnetResult, haikuResult)
        
        // Show comparison
        console.log(`\n📊 Comparison for this question:`)
        console.table([
          {
            Model: 'Sonnet 4',
            'Time (ms)': sonnetResult.responseTime,
            'Score': sonnetResult.overallScore.toFixed(1),
            'Tokens': sonnetResult.tokenCount
          },
          {
            Model: 'Haiku',
            'Time (ms)': haikuResult.responseTime,
            'Score': haikuResult.overallScore.toFixed(1),
            'Tokens': haikuResult.tokenCount
          }
        ])
        
        console.log(`\n🏆 Winner: ${sonnetResult.overallScore > haikuResult.overallScore ? 'Sonnet 4' : 'Haiku'} (${Math.abs(sonnetResult.overallScore - haikuResult.overallScore).toFixed(1)} point difference)\n`)
        console.log('-'.repeat(60) + '\n')
        
      } catch (error) {
        console.error(`❌ Error testing question: ${error.message}`)
      }
    }
    
    this.printOverallSummary(results)
  }

  private printOverallSummary(results: ModelComparison[]) {
    console.log('='*60)
    console.log('📊 OVERALL MODEL COMPARISON SUMMARY\n')
    
    const sonnetResults = results.filter(r => r.model === 'claude-sonnet-4-20250514')
    const haikuResults = results.filter(r => r.model === 'claude-3-haiku-20240307')
    
    if (sonnetResults.length === 0 || haikuResults.length === 0) {
      console.log('❌ Insufficient data for comparison')
      return
    }
    
    const sonnetAvg = {
      time: sonnetResults.reduce((sum, r) => sum + r.responseTime, 0) / sonnetResults.length,
      score: sonnetResults.reduce((sum, r) => sum + r.overallScore, 0) / sonnetResults.length,
      tokens: sonnetResults.reduce((sum, r) => sum + r.tokenCount, 0) / sonnetResults.length
    }
    
    const haikuAvg = {
      time: haikuResults.reduce((sum, r) => sum + r.responseTime, 0) / haikuResults.length,
      score: haikuResults.reduce((sum, r) => sum + r.overallScore, 0) / haikuResults.length,
      tokens: haikuResults.reduce((sum, r) => sum + r.tokenCount, 0) / haikuResults.length
    }
    
    console.table([
      {
        Model: 'Sonnet 4',
        'Avg Time (ms)': Math.round(sonnetAvg.time),
        'Avg Score': sonnetAvg.score.toFixed(1),
        'Avg Tokens': Math.round(sonnetAvg.tokens)
      },
      {
        Model: 'Haiku',
        'Avg Time (ms)': Math.round(haikuAvg.time),
        'Avg Score': haikuAvg.score.toFixed(1),
        'Avg Tokens': Math.round(haikuAvg.tokens)
      }
    ])
    
    const speedImprovement = ((sonnetAvg.time - haikuAvg.time) / sonnetAvg.time) * 100
    const qualityDifference = sonnetAvg.score - haikuAvg.score
    
    console.log(`\n🚀 Speed Improvement: ${speedImprovement.toFixed(1)}% faster with Haiku`)
    console.log(`🎯 Quality Difference: ${qualityDifference > 0 ? 'Sonnet' : 'Haiku'} is ${Math.abs(qualityDifference).toFixed(1)} points better`)
    
    console.log('\n💡 Recommendation:')
    if (speedImprovement > 30 && Math.abs(qualityDifference) < 1.5) {
      console.log('✅ Switch to Haiku - significant speed gain with minimal quality loss')
    } else if (speedImprovement > 50 && Math.abs(qualityDifference) < 2.5) {
      console.log('⚡ Consider Haiku - major speed improvement, acceptable quality trade-off')
    } else {
      console.log('🎯 Keep Sonnet - quality difference too significant')
    }
  }
}

// Run the evaluation
async function main() {
  const evaluator = new QualityEvaluator()
  
  try {
    await evaluator.setup()
    await evaluator.runComparison()
  } catch (error) {
    console.error('❌ Evaluation failed:', error.message)
    process.exit(1)
  }
}

main()