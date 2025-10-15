import puppeteer from 'puppeteer';

async function testDynamicProfilesBrowser() {
  console.log('🧪 Starting Automated Browser Test for Dynamic Profiles...\n');
  
  const browser = await puppeteer.launch({
    headless: false, // Show browser for debugging
    args: ['--no-sandbox'],
    defaultViewport: { width: 1400, height: 900 }
  });

  const page = await browser.newPage();
  
  try {
    // Enable console logging from the page
    page.on('console', msg => {
      if (msg.type() === 'error') {
        console.log('🔴 Browser Error:', msg.text());
      } else if (msg.type() === 'warn') {
        console.log('🟡 Browser Warning:', msg.text());
      } else if (msg.text().includes('✅') || msg.text().includes('❌')) {
        console.log(msg.text());
      }
    });

    // Navigate to the test URL
    console.log('🔄 Navigating to person profile page...');
    await page.goto('http://localhost:3000/people/43fe5254-805f-410d-a474-5dd7c9503f77', {
      waitUntil: 'networkidle0',
      timeout: 30000
    });

    // Wait for the page to fully load
    await page.waitForTimeout(2000);

    // Test 1: Check if profile editor is present
    console.log('1️⃣ Testing profile editor presence...');
    const profileEditor = await page.$('.profile-editor');
    if (profileEditor) {
      console.log('✅ Profile editor found');
    } else {
      console.log('❌ Profile editor not found');
      return;
    }

    // Test 2: Check if TipTap editor is present and functional
    console.log('2️⃣ Testing TipTap editor...');
    const tipTapEditor = await page.$('.ProseMirror');
    if (tipTapEditor) {
      console.log('✅ TipTap editor found');
      
      // Test typing in the editor
      await page.click('.ProseMirror');
      await page.keyboard.down('Control');
      await page.keyboard.press('a');
      await page.keyboard.up('Control');
      
      const testContent = `Automated test content ${Date.now()}`;
      await page.type('.ProseMirror', testContent);
      
      // Wait for auto-save
      await page.waitForTimeout(2000);
      
      // Check if content was typed
      const editorContent = await page.$eval('.ProseMirror', el => el.textContent);
      if (editorContent?.includes(testContent.substring(0, 20))) {
        console.log('✅ Profile content editing works');
      } else {
        console.log('❌ Profile content editing failed');
      }
    } else {
      console.log('❌ TipTap editor not found');
    }

    // Test 3: Check if chat input is present
    console.log('3️⃣ Testing chat input...');
    const chatInput = await page.$('textarea[placeholder*="Type your message"]');
    if (chatInput) {
      console.log('✅ Chat input found');
    } else {
      console.log('❌ Chat input not found');
    }

    // Test 4: Test message sending
    console.log('4️⃣ Testing message sending...');
    if (chatInput) {
      const initialMessages = await page.$$('.message-bubble');
      const initialCount = initialMessages.length;
      
      const testMessage = `Test message ${Date.now()}`;
      await page.click('textarea[placeholder*="Type your message"]');
      await page.type('textarea[placeholder*="Type your message"]', testMessage);
      await page.keyboard.press('Enter');
      
      // Wait for user message to appear
      console.log('⏳ Waiting for user message...');
      await page.waitForTimeout(3000);
      
      const updatedMessages = await page.$$('.message-bubble');
      if (updatedMessages.length > initialCount) {
        console.log('✅ User message appeared');
        
        // Wait for AI response
        console.log('⏳ Waiting for AI response...');
        await page.waitForTimeout(8000);
        
        const finalMessages = await page.$$('.message-bubble');
        if (finalMessages.length > initialCount + 1) {
          console.log('✅ AI response appeared');
        } else {
          console.log('❌ AI response did not appear');
        }
      } else {
        console.log('❌ User message did not appear');
      }
    }

    // Test 5: Check for split pane layout
    console.log('5️⃣ Testing split pane layout...');
    const resizeHandle = await page.$('[role="separator"]');
    if (resizeHandle) {
      console.log('✅ Split pane resize handle found');
    } else {
      console.log('❌ Split pane resize handle not found');
    }

    // Test 6: Check for JavaScript errors
    console.log('6️⃣ Checking for JavaScript errors...');
    const errors = await page.evaluate(() => {
      return window.jsErrors || [];
    });
    
    if (errors.length === 0) {
      console.log('✅ No JavaScript errors detected');
    } else {
      console.log('❌ JavaScript errors found:', errors);
    }

    console.log('\n✅ Browser testing completed!');

  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await browser.close();
  }
}

// Run the test
testDynamicProfilesBrowser().catch(console.error);