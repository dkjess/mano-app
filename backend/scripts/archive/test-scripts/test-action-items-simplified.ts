import puppeteer from 'puppeteer';

// Test configuration - try conversations page first
const BASE_URL = 'http://localhost:3001';
const PERSON_URL = `${BASE_URL}/people/43fe5254-805f-410d-a474-5dd7c9503f77`;

// Helper function to wait and log
const wait = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function testActionItemsSimplified() {
  console.log('🧪 Starting Simplified Action Items Feature Test...\n');
  
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
    console.log('📍 Step 1: Navigating to conversations page...');
    await page.goto(`${BASE_URL}/conversations`, { waitUntil: 'networkidle2', timeout: 60000 });
    await wait(5000);
    
    await page.screenshot({ path: 'test-results/01-conversations-page.png', fullPage: true });
    console.log('✅ Conversations page loaded\n');
    
    // Check page content
    const pageContent = await page.evaluate(() => {
      return {
        title: document.title,
        bodyText: document.body.innerText.substring(0, 1000),
        url: window.location.href
      };
    });
    
    console.log('Current page:', pageContent.url);
    console.log('Page title:', pageContent.title);
    console.log('Page content preview:', pageContent.bodyText.substring(0, 200) + '...\n');
    
    // Now try to navigate to specific person
    console.log('📍 Step 2: Navigating to specific person...');
    await page.goto(PERSON_URL, { waitUntil: 'networkidle2', timeout: 60000 });
    await wait(5000);
    
    await page.screenshot({ path: 'test-results/02-person-page.png', fullPage: true });
    
    // Check if we reached the person page
    const personPageContent = await page.evaluate(() => {
      return {
        url: window.location.href,
        title: document.title,
        hasEditor: !!document.querySelector('[contenteditable="true"], textarea, [data-testid="message-input"]'),
        allInputs: Array.from(document.querySelectorAll('input, textarea, [contenteditable]')).map(el => ({
          tagName: el.tagName,
          type: (el as any).type || 'unknown',
          className: el.className,
          id: el.id,
          contentEditable: (el as any).contentEditable
        }))
      };
    });
    
    console.log('Person page analysis:', personPageContent);
    
    // Test 3: Test /api/action-items endpoint directly
    console.log('\n📍 Step 3: Testing /api/action-items endpoint...');
    
    const apiResponse = await page.evaluate(async () => {
      try {
        const res = await fetch('/api/action-items', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            personId: '43fe5254-805f-410d-a474-5dd7c9503f77',
            content: 'Test action item from API',
            completed: false
          })
        });
        
        const text = await res.text();
        return {
          status: res.status,
          ok: res.ok,
          headers: Object.fromEntries(res.headers.entries()),
          data: text.substring(0, 500) // Limit response size
        };
      } catch (err: any) {
        return { error: err.message };
      }
    });
    
    console.log('API Response:', apiResponse);
    
    // Test 4: Check for action items functionality in the page
    console.log('\n📍 Step 4: Looking for action items functionality...');
    
    const actionItemsCheck = await page.evaluate(() => {
      // Look for action items related elements
      const checks = {
        hasCheckboxes: document.querySelectorAll('input[type="checkbox"]').length,
        hasTaskList: !!document.querySelector('[data-testid="task-list"], .task-list, ul li'),
        hasActionItemsAPI: typeof (window as any).actionItems !== 'undefined',
        scriptsLoaded: Array.from(document.scripts).map(s => s.src).filter(src => src.includes('action')),
        buttonElements: Array.from(document.querySelectorAll('button')).map(btn => btn.textContent?.trim()).filter(text => text && text.includes('task') || text?.includes('action'))
      };
      
      return checks;
    });
    
    console.log('Action items functionality check:', actionItemsCheck);
    
    // Test 5: Try creating action items manually if editor is found
    if (personPageContent.hasEditor) {
      console.log('\n📍 Step 5: Testing manual action item creation...');
      
      // Find the editor
      const editor = await page.$('[contenteditable="true"], textarea, [data-testid="message-input"]');
      
      if (editor) {
        await editor.click();
        await wait(500);
        
        // Try typing checkbox syntax
        await page.keyboard.type('Testing action items:');
        await page.keyboard.press('Enter');
        await page.keyboard.type('[ ] First task item');
        await page.keyboard.press('Enter');
        await page.keyboard.type('[x] Completed task');
        await page.keyboard.press('Enter');
        await page.keyboard.type('[ ] Another task');
        await wait(2000);
        
        await page.screenshot({ path: 'test-results/03-typed-action-items.png', fullPage: true });
        
        // Check if checkboxes appeared
        const checkboxCount = await page.$$eval('input[type="checkbox"]', boxes => boxes.length);
        console.log(`✅ Checkboxes found after typing: ${checkboxCount}`);
        
        if (checkboxCount > 0) {
          // Test clicking a checkbox
          const firstCheckbox = await page.$('input[type="checkbox"]');
          if (firstCheckbox) {
            const initialState = await firstCheckbox.evaluate((el: any) => el.checked);
            await firstCheckbox.click();
            await wait(1000);
            const newState = await firstCheckbox.evaluate((el: any) => el.checked);
            
            console.log(`Checkbox interaction: ${initialState} -> ${newState}`);
            await page.screenshot({ path: 'test-results/04-checkbox-clicked.png', fullPage: true });
          }
        }
      }
    } else {
      console.log('⚠️  No editor found - skipping manual creation test');
    }
    
    // Final screenshot
    await page.screenshot({ path: 'test-results/05-final-state.png', fullPage: true });
    
    console.log('\n✅ Simplified testing completed!');
    
  } catch (error) {
    console.error('\n❌ Test failed with error:', error);
    await page.screenshot({ path: 'test-results/error-state.png', fullPage: true });
  } finally {
    await browser.close();
  }
}

// Run the test
testActionItemsSimplified().catch(console.error);