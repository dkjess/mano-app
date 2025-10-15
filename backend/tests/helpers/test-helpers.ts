/**
 * Test utilities and helpers for Mano backend testing
 */

import { assertEquals, assertExists } from "@std/assert";

// Mock Anthropic API for testing
export class MockAnthropicAPI {
  private mockResponses: Map<string, any> = new Map();
  
  setMockResponse(prompt: string, response: any) {
    this.mockResponses.set(prompt, response);
  }
  
  get messages() {
    return {
      create: async (options: any) => {
        const mockResponse = this.mockResponses.get(options.messages[0]?.content || 'default');
        return mockResponse || {
          content: [{ type: 'text', text: 'Mock AI response' }]
        };
      }
    };
  }
}

// Mock Supabase client for isolated unit tests
export class MockSupabaseClient {
  private mockData: Map<string, any[]> = new Map();
  private mockUser: any = null;
  
  setMockUser(user: any) {
    this.mockUser = user;
  }
  
  setMockData(table: string, data: any[]) {
    this.mockData.set(table, data);
  }
  
  getMockData(table: string): any[] {
    return this.mockData.get(table) || [];
  }
  
  from(table: string) {
    const data = this.mockData.get(table) || [];
    
    return {
      insert: (record: any) => ({
        select: () => ({
          single: () => ({
            execute: async () => ({
              data: { ...record, id: crypto.randomUUID() },
              error: null
            })
          })
        })
      }),
      select: (columns?: string) => ({
        eq: (column: string, value: any) => ({
          single: () => ({
            execute: async () => {
              const filtered = data.filter(item => item[column] === value);
              return {
                data: filtered[0] || null,
                error: filtered.length === 0 ? { message: 'Not found' } : null
              };
            }
          })
        })
      })
    };
  }
  
  get auth() {
    return {
      getUser: async () => ({
        data: { user: this.mockUser },
        error: this.mockUser ? null : { message: 'No user' }
      })
    };
  }
}

// Test data factories
export const createTestUser = () => ({
  id: crypto.randomUUID(),
  email: 'test@example.com',
  aud: 'authenticated'
});

export const createTestPerson = (overrides: Partial<any> = {}) => ({
  id: crypto.randomUUID(),
  user_id: crypto.randomUUID(),
  name: 'Test Person',
  role: 'Software Engineer',
  relationship_type: 'direct_report',
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
  ...overrides
});

export const createTestMessage = (overrides: Partial<any> = {}) => ({
  id: crypto.randomUUID(),
  user_id: crypto.randomUUID(),
  person_id: crypto.randomUUID(),
  content: 'Test message',
  is_user: false,
  created_at: new Date().toISOString(),
  ...overrides
});

// HTTP request testing helper
export async function makeTestRequest(
  path: string, 
  method: string = 'GET', 
  body?: any,
  headers: Record<string, string> = {}
) {
  const url = `http://127.0.0.1:54321/functions/v1${path}`;
  
  const requestInit: RequestInit = {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...headers
    }
  };
  
  if (body) {
    requestInit.body = JSON.stringify(body);
  }
  
  const response = await fetch(url, requestInit);
  const text = await response.text();
  
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  
  return {
    status: response.status,
    ok: response.ok,
    data,
    headers: response.headers
  };
}

// Assertion helpers
export function assertValidPerson(person: any) {
  assertExists(person.id, 'Person should have an ID');
  assertExists(person.name, 'Person should have a name');
  assertExists(person.relationship_type, 'Person should have a relationship type');
  assertExists(person.created_at, 'Person should have created_at timestamp');
}

export function assertValidMessage(message: any) {
  assertExists(message.id, 'Message should have an ID');
  assertExists(message.content, 'Message should have content');
  assertEquals(typeof message.is_user, 'boolean', 'Message should have is_user boolean');
  assertExists(message.created_at, 'Message should have created_at timestamp');
}

// Test environment setup
export async function setupTestEnvironment() {
  // Ensure test database is clean
  console.log('🧪 Setting up test environment...');
}

export async function teardownTestEnvironment() {
  // Clean up after tests
  console.log('🧹 Cleaning up test environment...');
}