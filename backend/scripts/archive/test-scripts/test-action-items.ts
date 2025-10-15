import puppeteer from 'puppeteer';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

// Test configuration
const TEST_URL = 'http://localhost:3001/people/43fe5254-805f-410d-a474-5dd7c9503f77';
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://localhost:54321';
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

// Helper function to wait and log
const wait = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function testActionItems() {
  console.log('🧪 Starting Action Items Feature Test...\n');
  
  // Initialize Supabase client for backend verification
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
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
  
  // Capture page errors
  page.on('pageerror', err => {
    console.error('❌ Page Error:', err.message);
  });
  
  // Capture failed requests
  page.on('requestfailed', request => {
    console.error('❌ Request Failed:', request.url(), request.failure()?.errorText);
  });
  
  try {
    console.log('📍 Step 1: Navigating to person page...');
    await page.goto(TEST_URL, { waitUntil: 'networkidle2' });
    await wait(3000);
    
    // Check if we're on onboarding page and complete it
    let currentUrl = page.url();
    if (currentUrl.includes('/onboarding')) {
      console.log('🎯 Completing onboarding process...');
      
      // Fill in the name field
      const nameInput = await page.$('input.onboarding-input');
      if (nameInput) {
        await nameInput.type('Test User');
        await wait(500);
        
        // Click continue button
        const continueButton = await page.$('button');
        if (continueButton) {
          await continueButton.click();
          await wait(3000);
          
          // Navigate to person page after onboarding
          await page.goto(TEST_URL, { waitUntil: 'networkidle2' });
          await wait(3000);
        }
      }
    }
    
    // Check if we need to login
    currentUrl = page.url();
    if (currentUrl.includes('/login') || currentUrl.includes('/auth')) {
      console.log('🔐 Login required, attempting to login...');
      
      // Look for email/password fields
      const emailField = await page.$('input[type="email"], input[name="email"]');
      const passwordField = await page.$('input[type="password"], input[name="password"]');
      
      if (emailField && passwordField) {
        await emailField.type('dev@mano.local');
        await passwordField.type('dev123456');
        
        // Look for login button
        let loginButton = await page.$('button[type="submit"]');
        if (!loginButton) {
          loginButton = await page.$('button');
        }
        
        if (loginButton) {
          await loginButton.click();
          await wait(3000);
          
          // Navigate to person page after login
          await page.goto(TEST_URL, { waitUntil: 'networkidle2' });
          await wait(3000);
        }
      }
    }
    
    // Take initial screenshot
    await page.screenshot({ path: 'test-results/01-initial-page.png', fullPage: true });
    console.log('✅ Page loaded successfully\n');
    
    // Test 2: Check for task list button in bubble menu
    console.log('📍 Step 2: Testing task list button in bubble menu...');
    
    // First, let's look for any possible editor selectors
    await wait(5000); // Wait for page to fully load
    
    // Check what's on the page
    const pageContent = await page.evaluate(() => {
      return {
        title: document.title,
        bodyText: document.body.innerText.substring(0, 500),
        hasContentEditable: !!document.querySelector('[contenteditable="true"]'),
        hasTextarea: !!document.querySelector('textarea'),
        hasInput: !!document.querySelector('input[type="text"]'),
        allEditableElements: Array.from(document.querySelectorAll('[contenteditable], textarea, input')).map(el => ({
          tagName: el.tagName,
          className: el.className,
          id: el.id,
          contentEditable: (el as any).contentEditable
        }))
      };
    });
    
    console.log('Page analysis:', pageContent);
    
    // Try to find editor with multiple selector strategies
    let editor = null;
    try {
      editor = await page.waitForSelector('[contenteditable="true"]', { timeout: 5000 });
    } catch (e) {
      try {
        editor = await page.waitForSelector('textarea', { timeout: 5000 });
      } catch (e2) {
        try {
          editor = await page.waitForSelector('[data-testid="message-input"], .message-input, .chat-input', { timeout: 5000 });
        } catch (e3) {
          console.log('⚠️  Could not find any editor element');
        }
      }
    }
    
    if (editor) {
      // Click in the editor to focus
      await editor.click();
      await wait(500);
      
      // Type some text
      await page.keyboard.type('Test text for bubble menu ');
      await wait(500);
      
      // Select the text by triple-clicking
      await editor.click({ clickCount: 3 });
      await wait(1000);
      
      // Look for bubble menu
      const bubbleMenu = await page.$('[data-testid="bubble-menu"], .bubble-menu, [role="toolbar"]');
      if (bubbleMenu) {
        await page.screenshot({ path: 'test-results/02-bubble-menu.png' });
        
        // Look for task list button
        const taskButton = await page.$('[data-testid="task-list-button"], button[title*="task"], button[aria-label*="task"]');
        if (taskButton) {
          console.log('✅ Task list button found in bubble menu');
          await taskButton.click();
          await wait(1000);
          await page.screenshot({ path: 'test-results/03-after-task-button.png' });
        } else {
          console.log('⚠️  Task list button not found in bubble menu');
        }
      } else {
        console.log('⚠️  Bubble menu not appearing on text selection');
      }
    } else {
      console.log('⚠️  No editor found - skipping bubble menu test');
    }
    
    // Test 3: Manual checkbox creation
    console.log('\n📍 Step 3: Testing manual checkbox creation with [ ]...');
    
    if (editor) {
      // Clear editor and start fresh
      await editor.click();
      await page.keyboard.down('Control');
      await page.keyboard.press('A');
      await page.keyboard.up('Control');
      await page.keyboard.press('Backspace');
      await wait(500);
      
      // Type checkbox syntax
      await page.keyboard.type('[ ] First task item');
      await page.keyboard.press('Enter');
      await page.keyboard.type('[ ] Second task item');
      await page.keyboard.press('Enter');
      await page.keyboard.type('[x] Completed task item');
      await wait(1000);
      
      await page.screenshot({ path: 'test-results/04-manual-checkboxes.png' });
      
      // Check if checkboxes were created
      const checkboxes = await page.$$('input[type="checkbox"]');
      console.log(`✅ Found ${checkboxes.length} checkboxes created\n`);
    } else {
      console.log('⚠️  No editor found - skipping manual checkbox creation test\n');
    }
    
    // Test 4: Checking/Unchecking
    console.log('📍 Step 4: Testing checkbox interaction...');
    
    // Check if checkboxes were created
    const checkboxes = await page.$$('input[type="checkbox"]');
    
    if (checkboxes.length > 0) {
      // Click first checkbox
      const firstCheckbox = checkboxes[0];
      const isCheckedBefore = await firstCheckbox.evaluate((el: any) => el.checked);
      console.log(`First checkbox initial state: ${isCheckedBefore ? 'checked' : 'unchecked'}`);
      
      await firstCheckbox.click();
      await wait(1000);
      
      const isCheckedAfter = await firstCheckbox.evaluate((el: any) => el.checked);
      console.log(`First checkbox after click: ${isCheckedAfter ? 'checked' : 'unchecked'}`);
      
      await page.screenshot({ path: 'test-results/05-after-checkbox-click.png' });
      
      // Check for visual feedback (strikethrough)
      const taskText = await page.$('li:has(input[type="checkbox"]:checked) span, li:has(input[type="checkbox"]:checked)');
      if (taskText) {
        const hasStrikethrough = await taskText.evaluate(el => {
          const styles = window.getComputedStyle(el);
          return styles.textDecoration.includes('line-through') || 
                 styles.textDecorationLine === 'line-through';
        });
        console.log(`✅ Strikethrough effect: ${hasStrikethrough ? 'Applied' : 'Not applied'}\n`);
      }
    }
    
    // Test 5: Database sync
    console.log('📍 Step 5: Testing database persistence...');
    
    // Save current content
    const contentBefore = await page.evaluate(() => {
      const editor = document.querySelector('[contenteditable="true"]');
      return editor?.textContent || '';
    });
    
    // Reload page
    await page.reload({ waitUntil: 'networkidle2' });
    await wait(3000);
    
    const contentAfter = await page.evaluate(() => {
      const editor = document.querySelector('[contenteditable="true"]');
      return editor?.textContent || '';
    });
    
    console.log(`Content persisted after reload: ${contentBefore.trim() === contentAfter.trim() ? '✅ Yes' : '❌ No'}`);
    
    // Check if checkboxes persisted
    const checkboxesAfterReload = await page.$$('input[type="checkbox"]');
    console.log(`Checkboxes after reload: ${checkboxesAfterReload.length}\n`);
    
    await page.screenshot({ path: 'test-results/06-after-reload.png' });
    
    // Test 6: Edge function
    console.log('📍 Step 6: Testing /api/action-items endpoint...');
    
    // Test the endpoint directly
    const response = await page.evaluate(async () => {
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
        return {
          status: res.status,
          ok: res.ok,
          data: await res.text()
        };
      } catch (err: any) {
        return { error: err.message };
      }
    });
    
    console.log('API Response:', response);
    
    // Test 7: Error handling
    console.log('\n📍 Step 7: Testing error handling with invalid data...');
    
    const errorResponse = await page.evaluate(async () => {
      try {
        const res = await fetch('/api/action-items', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            // Missing required fields
            completed: false
          })
        });
        return {
          status: res.status,
          ok: res.ok,
          data: await res.text()
        };
      } catch (err: any) {
        return { error: err.message };
      }
    });
    
    console.log('Error handling test:', errorResponse);
    
    // Test 8: Check console for errors
    console.log('\n📍 Step 8: Checking for console errors...');
    const logs = await page.evaluate(() => {
      return {
        errors: (window as any).__errors || [],
        warnings: (window as any).__warnings || []
      };
    });
    
    if (logs.errors.length > 0) {
      console.log('❌ Console errors found:', logs.errors);
    } else {
      console.log('✅ No console errors detected');
    }
    
    // Test 9: Visual styling verification
    console.log('\n📍 Step 9: Verifying visual styling...');
    
    const styleChecks = await page.evaluate(() => {
      const checks: any = {};
      
      // Check checkbox styling
      const checkbox = document.querySelector('input[type="checkbox"]');
      if (checkbox) {
        const styles = window.getComputedStyle(checkbox);
        checks.checkboxStyling = {
          cursor: styles.cursor,
          marginRight: styles.marginRight
        };
      }
      
      // Check completed task styling
      const completedTask = document.querySelector('li:has(input[type="checkbox"]:checked)');
      if (completedTask) {
        const styles = window.getComputedStyle(completedTask);
        checks.completedTaskStyling = {
          textDecoration: styles.textDecoration,
          opacity: styles.opacity
        };
      }
      
      return checks;
    });
    
    console.log('Visual styling checks:', styleChecks);
    
    // Final screenshot
    await page.screenshot({ path: 'test-results/10-final-state.png', fullPage: true });
    
    console.log('\n✅ Testing completed!');
    
  } catch (error) {
    console.error('\n❌ Test failed with error:', error);
    await page.screenshot({ path: 'test-results/error-state.png', fullPage: true });
  } finally {
    await browser.close();
  }
}

// Run the test
testActionItems().catch(console.error);