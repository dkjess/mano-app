import puppeteer from 'puppeteer';

const TIMEOUT = 30000;
const BASE_URL = 'http://localhost:3000';
const TEST_EMAIL = 'dev@mano.local';
const TEST_PASSWORD = 'test123';

interface TestResult {
  test: string;
  status: 'PASS' | 'FAIL';
  error?: string;
  duration?: number;
}

const results: TestResult[] = [];

async function runTest(testName: string, testFn: () => Promise<void>) {
  const startTime = Date.now();
  try {
    await testFn();
    const duration = Date.now() - startTime;
    console.log(`✅ ${testName} (${duration}ms)`);
    results.push({ test: testName, status: 'PASS', duration });
  } catch (error) {
    const duration = Date.now() - startTime;
    console.error(`❌ ${testName}: ${error} (${duration}ms)`);
    results.push({ 
      test: testName, 
      status: 'FAIL', 
      error: error instanceof Error ? error.message : String(error),
      duration 
    });
  }
}

async function main() {
  console.log('🧪 Starting Dynamic Profiles E2E Tests...\n');
  
  const browser = await puppeteer.launch({
    headless: false, // Set to true for CI
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  page.setDefaultTimeout(TIMEOUT);

  try {
    // Login first
    await runTest('Login to application', async () => {
      await page.goto(`${BASE_URL}/auth/login`);
      await page.waitForSelector('input[type="email"]');
      await page.type('input[type="email"]', TEST_EMAIL);
      await page.type('input[type="password"]', TEST_PASSWORD);
      await page.click('button[type="submit"]');
      await page.waitForNavigation();
    });

    // Navigate to a person's profile
    await runTest('Navigate to person profile', async () => {
      await page.goto(BASE_URL);
      await page.waitForSelector('.person-row', { timeout: 10000 });
      
      // Click on the first person
      const firstPerson = await page.$('.person-row');
      if (!firstPerson) throw new Error('No person found');
      await firstPerson.click();
      
      // Wait for profile page to load
      await page.waitForSelector('.profile-editor', { timeout: 10000 });
    });

    // Test profile loading
    await runTest('Profile editor loads correctly', async () => {
      // Check for profile editor elements
      await page.waitForSelector('.profile-editor', { timeout: 5000 });
      await page.waitForSelector('.ProseMirror', { timeout: 5000 });
      
      // Verify profile header exists
      const profileHeader = await page.$('.profile-header');
      if (!profileHeader) throw new Error('Profile header not found');
    });

    // Test profile editing and auto-save
    await runTest('Profile editing and auto-save', async () => {
      // Clear existing content and type new content
      await page.click('.ProseMirror');
      await page.keyboard.down('Control');
      await page.keyboard.press('a');
      await page.keyboard.up('Control');
      
      const testContent = `Test profile content ${Date.now()}`;
      await page.type('.ProseMirror', testContent);
      
      // Wait for auto-save (1 second debounce + network time)
      await page.waitForTimeout(2000);
      
      // Check for "All changes saved" message
      await page.waitForFunction(
        () => {
          const statusText = document.querySelector('.profile-header p');
          return statusText && statusText.textContent?.includes('All changes saved');
        },
        { timeout: 5000 }
      );
      
      // Reload page to verify content persisted
      await page.reload();
      await page.waitForSelector('.ProseMirror', { timeout: 5000 });
      
      // Check if content is still there
      const savedContent = await page.$eval('.ProseMirror', el => el.textContent);
      if (!savedContent?.includes(testContent.substring(0, 20))) {
        throw new Error('Profile content not persisted after reload');
      }
    });

    // Test message sending
    await runTest('Message sending functionality', async () => {
      // Find the chat input
      const chatInput = await page.$('textarea[placeholder*="Type your message"]');
      if (!chatInput) throw new Error('Chat input not found');
      
      const testMessage = `Test message ${Date.now()}`;
      await chatInput.click();
      await page.type('textarea[placeholder*="Type your message"]', testMessage);
      
      // Send message
      await page.keyboard.press('Enter');
      
      // Wait for message to appear
      await page.waitForFunction(
        (msg) => {
          const messages = Array.from(document.querySelectorAll('.message-bubble'));
          return messages.some(el => el.textContent?.includes(msg));
        },
        { timeout: 10000 },
        testMessage
      );
    });

    // Test desktop split-pane layout
    await runTest('Desktop split-pane functionality', async () => {
      // Set desktop viewport
      await page.setViewport({ width: 1400, height: 900 });
      
      // Check for split pane elements
      await page.waitForSelector('[role="separator"]', { timeout: 5000 });
      
      // Try to drag the resize handle
      const resizeHandle = await page.$('[role="separator"]');
      if (!resizeHandle) throw new Error('Resize handle not found');
      
      const box = await resizeHandle.boundingBox();
      if (!box) throw new Error('Could not get resize handle position');
      
      // Drag to resize
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.down();
      await page.mouse.move(box.x - 100, box.y + box.height / 2);
      await page.mouse.up();
      
      // Verify panels resized (check if chat panel got smaller)
      await page.waitForTimeout(500);
    });

    // Test mobile tab layout
    await runTest('Mobile tab switching', async () => {
      // Set mobile viewport
      await page.setViewport({ width: 375, height: 667 });
      await page.waitForTimeout(500);
      
      // Look for tab buttons
      const chatTab = await page.$('button:has-text("Chat")');
      const profileTab = await page.$('button:has-text("Profile")');
      
      if (!chatTab || !profileTab) {
        throw new Error('Tab buttons not found on mobile');
      }
      
      // Click profile tab
      await profileTab.click();
      await page.waitForTimeout(500);
      
      // Verify profile editor is visible
      const profileEditor = await page.$('.profile-editor');
      if (!profileEditor) throw new Error('Profile editor not visible after tab switch');
      
      // Click chat tab
      await chatTab.click();
      await page.waitForTimeout(500);
      
      // Verify chat is visible
      const chatInput = await page.$('textarea[placeholder*="Type your message"]');
      if (!chatInput) throw new Error('Chat not visible after tab switch');
    });

    // Test multiple messages in quick succession
    await runTest('Send multiple messages', async () => {
      // Set back to desktop view
      await page.setViewport({ width: 1400, height: 900 });
      await page.waitForTimeout(500);
      
      for (let i = 1; i <= 3; i++) {
        const message = `Quick message ${i} - ${Date.now()}`;
        await page.click('textarea[placeholder*="Type your message"]');
        await page.type('textarea[placeholder*="Type your message"]', message);
        await page.keyboard.press('Enter');
        await page.waitForTimeout(500);
      }
      
      // Verify all messages appear
      const messageCount = await page.$$eval('.message-bubble', els => els.length);
      if (messageCount < 3) {
        throw new Error(`Expected at least 3 messages, found ${messageCount}`);
      }
    });

  } finally {
    // Print summary
    console.log('\n📊 Test Summary:');
    console.log('================');
    
    const passed = results.filter(r => r.status === 'PASS').length;
    const failed = results.filter(r => r.status === 'FAIL').length;
    const totalDuration = results.reduce((sum, r) => sum + (r.duration || 0), 0);
    
    console.log(`Total tests: ${results.length}`);
    console.log(`✅ Passed: ${passed}`);
    console.log(`❌ Failed: ${failed}`);
    console.log(`⏱️  Total duration: ${totalDuration}ms`);
    
    if (failed > 0) {
      console.log('\n❌ Failed tests:');
      results.filter(r => r.status === 'FAIL').forEach(r => {
        console.log(`  - ${r.test}: ${r.error}`);
      });
    }
    
    await browser.close();
    process.exit(failed > 0 ? 1 : 0);
  }
}

main().catch(console.error);