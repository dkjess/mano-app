/**
 * Integration tests for action-items-sync Edge Function
 *
 * Tests syncing action items to iOS Reminders app via CloudKit.
 */

import { assertEquals, assertExists } from "@std/assert";
import { makeTestRequest } from "@test-helpers";

const FUNCTION_URL = '/action-items-sync';

Deno.test("Action Items Sync API", async (t) => {

  await t.step("should handle CORS preflight", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'OPTIONS');

    assertEquals(response.status, 200);
    assertExists(response.headers.get('Access-Control-Allow-Origin'));
  });

  await t.step("should reject requests without authorization", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      items: []
    });

    assertEquals(response.status, 401);
    assertExists(response.data.error);
  });

  await t.step("should validate request body", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {}, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 400);
    assertExists(response.data.error);
  });

  await t.step("should handle empty items array", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      items: []
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.synced, 0);
  });

  await t.step("should sync action items to database", async () => {
    const testItems = [
      {
        id: crypto.randomUUID(),
        content: 'Follow up with Alice about project timeline',
        person_id: crypto.randomUUID(),
        due_date: new Date(Date.now() + 86400000).toISOString(), // Tomorrow
        priority: 'high',
        status: 'pending'
      },
      {
        id: crypto.randomUUID(),
        content: 'Schedule 1:1 with Bob',
        person_id: crypto.randomUUID(),
        due_date: null,
        priority: 'medium',
        status: 'pending'
      }
    ];

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      items: testItems
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.synced, 2);
  });

  await t.step("should handle different priority levels", async () => {
    const priorities = ['low', 'medium', 'high', 'urgent'];
    const testItems = priorities.map(priority => ({
      id: crypto.randomUUID(),
      content: `Test item with ${priority} priority`,
      person_id: crypto.randomUUID(),
      priority,
      status: 'pending'
    }));

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      items: testItems
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.synced, 4);
  });

  await t.step("should handle different statuses", async () => {
    const statuses = ['pending', 'completed', 'cancelled'];
    const testItems = statuses.map(status => ({
      id: crypto.randomUUID(),
      content: `Test item with ${status} status`,
      person_id: crypto.randomUUID(),
      status
    }));

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      items: testItems
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.synced, 3);
  });

  await t.step("should handle items with metadata", async () => {
    const testItems = [{
      id: crypto.randomUUID(),
      content: 'Test item with metadata',
      person_id: crypto.randomUUID(),
      status: 'pending',
      metadata: {
        source: 'chat',
        message_id: crypto.randomUUID(),
        extracted_at: new Date().toISOString()
      }
    }];

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      items: testItems
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.synced, 1);
  });
});
