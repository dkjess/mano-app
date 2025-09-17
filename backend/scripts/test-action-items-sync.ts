import puppeteer from 'puppeteer';

async function testActionItemsSync() {
  console.log('Starting action items sync test...');
  
  const browser = await puppeteer.launch({
    headless: false, // Run in headed mode to see what's happening
    devtools: true, // Open DevTools automatically
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  
  // Enable console logging
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    console.log(`[CONSOLE.${type.toUpperCase()}]`, text);
  });

  // Log network requests related to sync
  page.on('request', request => {
    const url = request.url();
    if (url.includes('sync') || url.includes('action') || url.includes('task')) {
      console.log('[NETWORK REQUEST]', request.method(), url);
    }
  });

  page.on('response', response => {
    const url = response.url();
    if (url.includes('sync') || url.includes('action') || url.includes('task')) {
      console.log('[NETWORK RESPONSE]', response.status(), url);
    }
  });

  // Log page errors
  page.on('pageerror', error => {
    console.error('[PAGE ERROR]', error.message);
  });

  try {
    // 1. Navigate to localhost:3000
    console.log('\n1. Navigating to http://localhost:3000...');
    await page.goto('http://localhost:3000', { waitUntil: 'networkidle2' });
    
    // 2. Log in
    console.log('\n2. Logging in as dev@mano.local...');
    
    // Wait for and click sign in button using XPath
    await page.waitForSelector('button', { timeout: 10000 });
    const [signInButton] = await page.$x("//button[contains(text(), 'Sign in')]");
    if (signInButton) {
      await signInButton.click();
    }
    
    // Fill in email and password
    await page.waitForSelector('input[type="email"]', { timeout: 10000 });
    await page.type('input[type="email"]', 'dev@mano.local');
    await page.type('input[type="password"]', 'dev123456');
    
    // Submit login form
    await page.click('button[type="submit"]');
    
    // Wait for navigation after login
    await page.waitForNavigation({ waitUntil: 'networkidle2' });
    console.log('Login successful');
    
    // 3. Handle onboarding if needed
    console.log('\n3. Checking for onboarding...');
    
    // Check if we're on the onboarding page
    const isOnboarding = await page.evaluate(() => {
      return window.location.pathname.includes('onboarding');
    });
    
    if (isOnboarding) {
      console.log('Onboarding detected, completing it...');
      
      // Look for "Get Started" button using XPath
      const [getStartedButton] = await page.$x("//button[contains(text(), 'Get Started')]");
      if (getStartedButton) {
        await getStartedButton.click();
        await page.waitForTimeout(1000);
      }
      
      // Skip or complete onboarding steps
      const [skipButton] = await page.$x("//button[contains(text(), 'Skip')]");
      if (skipButton) {
        await skipButton.click();
      } else {
        // Try to click through any Continue buttons
        const continueButtons = await page.$x("//button[contains(text(), 'Continue')]");
        for (const button of continueButtons) {
          await button.click();
          await page.waitForTimeout(1000);
        }
      }
      
      await page.waitForNavigation({ waitUntil: 'networkidle2' });
    }
    
    // Navigate to people page
    console.log('\n4. Navigating to people page...');
    
    // Try to find a person link or navigate to the people section
    const peopleLink = await page.$('a[href*="/people"]');
    if (peopleLink) {
      await peopleLink.click();
      await page.waitForNavigation({ waitUntil: 'networkidle2' });
    } else {
      // Navigate directly
      await page.goto('http://localhost:3000/people', { waitUntil: 'networkidle2' });
    }
    
    // Wait for people list to load
    await page.waitForTimeout(2000);
    
    // Click on the first person or create a new one
    const personLinks = await page.$$('a[href^="/people/"][href$="/profile"]');
    
    if (personLinks.length > 0) {
      console.log('Found existing person, clicking on profile...');
      await personLinks[0].click();
    } else {
      console.log('No people found, creating a new person...');
      
      // Look for new person button using XPath
      const [newPersonButton] = await page.$x("//button[contains(text(), 'New Person') or contains(text(), 'Add Person')]");
      if (newPersonButton) {
        await newPersonButton.click();
        await page.waitForTimeout(1000);
        
        // Fill in person details
        const nameInput = await page.$('input[name="name"], input[placeholder*="name" i]');
        if (nameInput) {
          await nameInput.type('Test Person');
        }
        
        // Submit form
        const submitBtn = await page.$('button[type="submit"]');
        if (submitBtn) {
          await submitBtn.click();
        } else {
          const [createButton] = await page.$x("//button[contains(text(), 'Create') or contains(text(), 'Save')]");
          if (createButton) {
            await createButton.click();
          }
        }
      }
    }
    
    // Wait for profile page to load
    await page.waitForTimeout(3000);
    
    // 5. Create task items
    console.log('\n5. Creating task items...');
    
    // First, let's check if we're on a profile page and look for the editor
    const currentUrl = await page.url();
    console.log('Current URL:', currentUrl);
    
    // Try to find the main content editor
    const editor = await page.$('[contenteditable="true"], .editor, .prose, [data-testid="profile-editor"]');
    
    if (editor) {
      console.log('Found editor, adding tasks...');
      await editor.click();
      await page.waitForTimeout(500);
      
      // Clear any existing content and add task list
      await page.keyboard.down('Control');
      await page.keyboard.press('A');
      await page.keyboard.up('Control');
      
      // Type task list using markdown
      await page.keyboard.type('## Action Items\n\n');
      await page.keyboard.type('- [ ] Test Action Item 1 - Sync Test\n');
      await page.keyboard.type('- [ ] Test Action Item 2 - Monitoring Console\n');
      await page.keyboard.type('- [ ] Test Action Item 3 - Check Database Sync\n');
      
      // Trigger save by clicking outside
      await page.mouse.click(100, 100);
      
      console.log('Tasks added to editor');
    } else {
      console.log('Editor not found, trying alternative approach...');
      
      // Look for task-specific UI elements
      const [addTaskButton] = await page.$x("//button[contains(text(), 'Add Task') or contains(text(), 'New Task') or text()='+']");
      
      if (addTaskButton) {
        console.log('Found add task button, creating tasks...');
        
        // Create 3 test tasks
        for (let i = 1; i <= 3; i++) {
          console.log(`Creating task ${i}...`);
          await addTaskButton.click();
          await page.waitForTimeout(500);
          
          // Type task content
          const taskInput = await page.$('input[placeholder*="task" i], textarea[placeholder*="task" i]');
          if (taskInput) {
            await taskInput.type(`Test Task ${i} - Created at ${new Date().toLocaleTimeString()}`);
            
            // Press Enter or find save button
            await page.keyboard.press('Enter');
            await page.waitForTimeout(1000);
          }
        }
      }
    }
    
    // 6. Monitor for sync operations
    console.log('\n6. Monitoring for sync operations...');
    console.log('Waiting 10 seconds to capture any sync activity...');
    
    // Wait and capture any sync operations
    await page.waitForTimeout(10000);
    
    // 7. Check for sync indicators
    console.log('\n7. Checking for sync indicators...');
    
    // Evaluate page for any sync-related elements or messages
    const syncStatus = await page.evaluate(() => {
      // Look for sync indicators
      const syncIndicators = document.querySelectorAll('[class*="sync"], [class*="saving"], [class*="saved"]');
      const statusMessages = [];
      
      syncIndicators.forEach(indicator => {
        statusMessages.push({
          text: indicator.textContent,
          className: indicator.className
        });
      });
      
      // Check for any toast messages
      const toasts = document.querySelectorAll('[role="alert"], .toast, [class*="notification"]');
      toasts.forEach(toast => {
        statusMessages.push({
          text: toast.textContent,
          type: 'toast'
        });
      });
      
      // Check localStorage for any sync-related data
      const localStorageKeys = Object.keys(localStorage);
      const syncRelatedKeys = localStorageKeys.filter(key => 
        key.includes('sync') || key.includes('action') || key.includes('task')
      );
      
      return {
        statusMessages,
        syncRelatedKeys
      };
    });
    
    if (syncStatus.statusMessages.length > 0) {
      console.log('\nSync status indicators found:');
      syncStatus.statusMessages.forEach(status => {
        console.log(`- ${status.type || 'indicator'}: ${status.text}`);
      });
    }
    
    if (syncStatus.syncRelatedKeys.length > 0) {
      console.log('\nSync-related localStorage keys:');
      syncStatus.syncRelatedKeys.forEach(key => {
        console.log(`- ${key}`);
      });
    }
    
    // Take a screenshot for reference
    await page.screenshot({ path: 'action-items-sync-test.png', fullPage: true });
    console.log('\nScreenshot saved as action-items-sync-test.png');
    
    // Check network tab for any action-items-sync calls
    console.log('\n8. Summary:');
    console.log('- Check the console output above for any sync-related logs');
    console.log('- Look for [NETWORK REQUEST/RESPONSE] entries containing "sync", "action", or "task"');
    console.log('- Any errors would be logged with [PAGE ERROR] prefix');
    console.log('- Review the screenshot to see the current state of the page');
    
    // Keep browser open for manual inspection
    console.log('\nBrowser will remain open for manual inspection. Press Ctrl+C to close.');
    
  } catch (error) {
    console.error('\n[TEST ERROR]', error);
  }
}

// Run the test
testActionItemsSync();