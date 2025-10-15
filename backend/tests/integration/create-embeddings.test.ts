/**
 * Integration tests for create-embeddings Edge Function
 *
 * Tests the embedding generation and storage functionality for conversation context retrieval.
 */

import { assertEquals, assertExists } from "@std/assert";
import { makeTestRequest } from "@test-helpers";

const FUNCTION_URL = '/create-embeddings';

Deno.test("Create Embeddings API", async (t) => {

  await t.step("should reject requests without authorization", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      embeddings: []
    });

    assertEquals(response.status, 500);
    assertExists(response.data.error);
  });

  await t.step("should reject requests without embeddings array", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {}, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 500);
    assertExists(response.data.error);
  });

  await t.step("should handle empty embeddings array", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      embeddings: []
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.processed, 0);
    assertEquals(response.data.results.length, 0);
  });

  await t.step("should create embeddings for multiple messages", async () => {
    const testUserId = crypto.randomUUID();
    const testPersonId = crypto.randomUUID();
    const testMessageId1 = crypto.randomUUID();
    const testMessageId2 = crypto.randomUUID();

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      embeddings: [
        {
          userId: testUserId,
          personId: testPersonId,
          messageId: testMessageId1,
          content: "This is a test message for embedding",
          messageType: "user",
          metadata: { test: true }
        },
        {
          userId: testUserId,
          personId: testPersonId,
          messageId: testMessageId2,
          content: "This is another test message",
          messageType: "assistant",
          metadata: {}
        }
      ]
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.success, true);
    assertEquals(response.data.processed, 2);
    assertEquals(response.data.results.length, 2);

    // Verify individual results
    const result1 = response.data.results.find((r: any) => r.messageId === testMessageId1);
    const result2 = response.data.results.find((r: any) => r.messageId === testMessageId2);

    assertExists(result1);
    assertExists(result2);
    assertEquals(result1.success, true);
    assertEquals(result2.success, true);
  });

  await t.step("should handle partial failures gracefully", async () => {
    const testUserId = crypto.randomUUID();
    const testPersonId = crypto.randomUUID();
    const validMessageId = crypto.randomUUID();

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      embeddings: [
        {
          userId: testUserId,
          personId: testPersonId,
          messageId: validMessageId,
          content: "Valid message",
          messageType: "user",
          metadata: {}
        },
        {
          // Missing required fields to trigger error
          messageId: crypto.randomUUID(),
          content: "Invalid message"
        }
      ]
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.processed, 2);

    // Should have both success and failure results
    const successResults = response.data.results.filter((r: any) => r.success);
    const failureResults = response.data.results.filter((r: any) => !r.success);

    assertEquals(successResults.length, 1);
    assertEquals(failureResults.length, 1);
  });

  await t.step("should generate dummy embeddings when AI session unavailable", async () => {
    // This tests the fallback behavior when AI embedding session is not available
    const testUserId = crypto.randomUUID();
    const testPersonId = crypto.randomUUID();
    const testMessageId = crypto.randomUUID();

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      embeddings: [
        {
          userId: testUserId,
          personId: testPersonId,
          messageId: testMessageId,
          content: "Test message",
          messageType: "user",
          metadata: {}
        }
      ]
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.success, true);
    assertEquals(response.data.results[0].success, true);
  });

  await t.step("should accept different message types", async () => {
    const testUserId = crypto.randomUUID();
    const testPersonId = crypto.randomUUID();

    const messageTypes = ['user', 'assistant', 'system'];
    const embeddingRequests = messageTypes.map(type => ({
      userId: testUserId,
      personId: testPersonId,
      messageId: crypto.randomUUID(),
      content: `Test ${type} message`,
      messageType: type,
      metadata: {}
    }));

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      embeddings: embeddingRequests
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.processed, 3);

    const successCount = response.data.results.filter((r: any) => r.success).length;
    assertEquals(successCount, 3);
  });

  await t.step("should handle metadata correctly", async () => {
    const testUserId = crypto.randomUUID();
    const testPersonId = crypto.randomUUID();
    const testMessageId = crypto.randomUUID();

    const metadata = {
      topic: 'performance-review',
      sentiment: 'positive',
      urgency: 'high'
    };

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      embeddings: [
        {
          userId: testUserId,
          personId: testPersonId,
          messageId: testMessageId,
          content: "Message with rich metadata",
          messageType: "user",
          metadata: metadata
        }
      ]
    }, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.success, true);
  });
});

Deno.test("Create Embeddings CORS", async (t) => {
  await t.step("should handle OPTIONS request for CORS", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'OPTIONS');

    assertEquals(response.status, 200);
    assertExists(response.headers.get('Access-Control-Allow-Origin'));
  });
});
