import puppeteer from 'puppeteer';

// Test configuration
const BASE_URL = 'http://localhost:3001';
const PERSON_URL = `${BASE_URL}/people/43fe5254-805f-410d-a474-5dd7c9503f77`;

// Helper function to wait and log
const wait = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function testActionItemsWithLogin() {
  console.log('🧪 Starting Action Items Test with Login...\n');
  
  // Launch browser
  const browser = await puppeteer.launch({
    headless: false,
    devtools: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const page = await browser.newPage();
  
  // Enable console logging
  page.on('console', msg => {
    const type = msg.type();
    if (type === 'error' || type === 'warning') {
      console.log(`[${type.toUpperCase()}]`, msg.text());
    }
  });
  
  try {
    console.log('📍 Step 1: Logging in...');
    await page.goto(`${BASE_URL}/auth/login`, { waitUntil: 'networkidle2' });
    await wait(2000);
    
    // Fill login form
    await page.type('#email', 'dev@mano.local');
    await page.type('#password', 'dev123456');
    
    // Click login button
    const loginButton = await page.$('button[type="submit"]');
    if (loginButton) {
      await loginButton.click();
      await wait(5000); // Wait for login to complete
    }
    
    await page.screenshot({ path: 'test-results/01-after-login.png', fullPage: true });
    
    // Check current URL after login
    let currentUrl = page.url();
    console.log('After login URL:', currentUrl);
    
    // Handle onboarding if redirected there
    if (currentUrl.includes('/onboarding')) {
      console.log('🎯 Completing onboarding...');
      const nameInput = await page.$('input');
      if (nameInput) {
        await nameInput.type('Test User');
        const continueButton = await page.$('button');
        if (continueButton) {
          await continueButton.click();
          await wait(3000);
        }
      }
      await page.screenshot({ path: 'test-results/02-after-onboarding.png', fullPage: true });
    }
    
    console.log('📍 Step 2: Navigating to person page...');
    await page.goto(PERSON_URL, { waitUntil: 'networkidle2' });
    await wait(5000);
    
    currentUrl = page.url();
    console.log('Person page URL:', currentUrl);
    
    await page.screenshot({ path: 'test-results/03-person-page.png', fullPage: true });
    
    // Analyze the person page
    const pageAnalysis = await page.evaluate(() => {
      return {
        title: document.title,
        url: window.location.href,
        hasEditor: !!document.querySelector('[contenteditable="true"], textarea, [data-testid="message-input"]'),
        editorSelectors: [
          '[contenteditable="true"]',
          'textarea',
          '[data-testid="message-input"]',
          '.message-input',
          '.chat-input',
          '[role="textbox"]'
        ].map(selector => ({
          selector,
          found: !!document.querySelector(selector),
          count: document.querySelectorAll(selector).length
        })),
        allInteractiveElements: Array.from(document.querySelectorAll('input, textarea, button, [contenteditable], [role="textbox"]')).map(el => ({
          tagName: el.tagName,
          type: (el as any).type || 'unknown',
          className: el.className,
          id: el.id,
          textContent: el.textContent?.trim().substring(0, 50),
          contentEditable: (el as any).contentEditable
        })).slice(0, 10) // Limit to first 10 elements
      };
    });
    
    console.log('Page analysis:', JSON.stringify(pageAnalysis, null, 2));
    
    // Test 3: Test action items API when authenticated
    console.log('📍 Step 3: Testing action items API...');
    
    const apiTest = await page.evaluate(async () => {
      try {
        const response = await fetch('/api/action-items', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            personId: '43fe5254-805f-410d-a474-5dd7c9503f77',
            content: 'Test action item from authenticated request',
            completed: false
          })
        });
        
        const text = await response.text();
        return {
          status: response.status,
          ok: response.ok,
          data: text.substring(0, 200)
        };
      } catch (err: any) {
        return { error: err.message };
      }
    });
    
    console.log('API Test Result:', apiTest);
    
    // Test 4: Try to find and interact with editor
    console.log('📍 Step 4: Looking for editor and testing action items...');
    
    if (pageAnalysis.hasEditor) {
      // Try different editor selectors
      let editor = null;
      for (const selectorInfo of pageAnalysis.editorSelectors) {
        if (selectorInfo.found) {
          editor = await page.$(selectorInfo.selector);
          if (editor) {
            console.log(`Found editor with selector: ${selectorInfo.selector}`);
            break;
          }
        }
      }
      
      if (editor) {
        console.log('Testing action item creation...');
        await editor.click();
        await wait(500);
        
        // Clear any existing content
        await page.keyboard.down('Control');
        await page.keyboard.press('a');
        await page.keyboard.up('Control');
        await page.keyboard.press('Backspace');
        await wait(500);
        
        // Type action items
        await page.keyboard.type('Testing action items feature:');
        await page.keyboard.press('Enter');
        await page.keyboard.type('[ ] First uncompleted task');
        await page.keyboard.press('Enter');
        await page.keyboard.type('[x] Completed task');
        await page.keyboard.press('Enter');
        await page.keyboard.type('[ ] Another uncompleted task');
        await wait(2000);
        
        await page.screenshot({ path: 'test-results/04-typed-action-items.png', fullPage: true });
        
        // Check for checkboxes
        const checkboxes = await page.$$('input[type="checkbox"]');
        console.log(`Found ${checkboxes.length} checkboxes after typing`);
        
        if (checkboxes.length > 0) {
          // Test checkbox interaction
          const firstCheckbox = checkboxes[0];
          const initialState = await firstCheckbox.evaluate((el: any) => el.checked);
          console.log(`First checkbox initial state: ${initialState}`);
          
          await firstCheckbox.click();
          await wait(1000);
          
          const newState = await firstCheckbox.evaluate((el: any) => el.checked);
          console.log(`First checkbox after click: ${newState}`);
          
          await page.screenshot({ path: 'test-results/05-checkbox-interaction.png', fullPage: true });
          
          // Check for visual feedback (strikethrough, etc.)
          const visualCheck = await page.evaluate(() => {
            const checkedCheckboxes = Array.from(document.querySelectorAll('input[type="checkbox"]:checked'));
            return checkedCheckboxes.map(checkbox => {
              const parent = checkbox.closest('li, div, span');
              if (parent) {
                const styles = window.getComputedStyle(parent);
                return {
                  hasStrikethrough: styles.textDecoration.includes('line-through'),
                  opacity: styles.opacity,
                  textDecoration: styles.textDecoration
                };
              }
              return null;
            }).filter(Boolean);
          });
          
          console.log('Visual styling check:', visualCheck);
          
          // Test persistence by saving and reloading
          console.log('📍 Step 5: Testing persistence...');
          
          // Look for save button or send message
          const sendButton = await page.$('button[type="submit"], button[data-testid="send"], button:has-text("Send")');
          if (sendButton) {
            await sendButton.click();
            await wait(2000);
            console.log('Message sent');
          } else {
            // Try pressing Enter to send
            await page.keyboard.press('Enter');
            await wait(2000);
            console.log('Pressed Enter to send');
          }
          
          await page.screenshot({ path: 'test-results/06-after-save.png', fullPage: true });
          
          // Reload page to test persistence
          await page.reload({ waitUntil: 'networkidle2' });
          await wait(3000);
          
          const checkboxesAfterReload = await page.$$('input[type="checkbox"]');
          console.log(`Checkboxes after reload: ${checkboxesAfterReload.length}`);
          
          await page.screenshot({ path: 'test-results/07-after-reload.png', fullPage: true });
        }
      } else {
        console.log('⚠️  Could not find working editor element');
      }
    } else {
      console.log('⚠️  No editor found on the page');
    }
    
    console.log('\n✅ Testing completed!');
    
  } catch (error) {
    console.error('\n❌ Test failed with error:', error);
    await page.screenshot({ path: 'test-results/error-final.png', fullPage: true });
  } finally {
    await browser.close();
  }
}

// Run the test
testActionItemsWithLogin().catch(console.error);