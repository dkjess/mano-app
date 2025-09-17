import puppeteer from 'puppeteer';

(async () => {
  const browser = await puppeteer.launch({
    headless: false, // Show browser for debugging
    devtools: true   // Open DevTools automatically
  });

  try {
    const page = await browser.newPage();
    
    // Collect all console messages
    const consoleMessages = [];
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      const location = msg.location();
      consoleMessages.push({
        type,
        text,
        location,
        timestamp: new Date().toISOString()
      });
      console.log(`[${type.toUpperCase()}] ${text}`);
      if (location.url) {
        console.log(`  at ${location.url}:${location.lineNumber}:${location.columnNumber}`);
      }
    });

    // Collect page errors
    const pageErrors = [];
    page.on('pageerror', error => {
      pageErrors.push({
        message: error.message,
        stack: error.stack,
        timestamp: new Date().toISOString()
      });
      console.error('PAGE ERROR:', error.message);
      if (error.stack) {
        console.error('Stack:', error.stack);
      }
    });

    // Collect failed requests
    const failedRequests = [];
    page.on('requestfailed', request => {
      failedRequests.push({
        url: request.url(),
        method: request.method(),
        failure: request.failure(),
        timestamp: new Date().toISOString()
      });
      console.error('Request failed:', request.url(), request.failure().errorText);
    });

    // Navigate to the page
    console.log('Navigating to http://localhost:3000/people/43fe5254-805f-410d-a474-5dd7c9503f77...');
    
    try {
      await page.goto('http://localhost:3000/people/43fe5254-805f-410d-a474-5dd7c9503f77', {
        waitUntil: 'networkidle0',
        timeout: 30000
      });
    } catch (navError) {
      console.error('Navigation error:', navError.message);
    }

    // Wait a bit for any async errors
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Take screenshot
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const screenshotPath = `/Users/jess/code/mano/debug-enhanced-chat-input-${timestamp}.png`;
    await page.screenshot({ 
      path: screenshotPath,
      fullPage: true 
    });
    console.log(`Screenshot saved to: ${screenshotPath}`);

    // Check for EnhancedChatInput component
    const chatInputExists = await page.evaluate(() => {
      // Look for the component by various methods
      const byClassName = document.querySelector('.enhanced-chat-input');
      const byDataTestId = document.querySelector('[data-testid="enhanced-chat-input"]');
      const byComponentName = document.querySelector('[data-component="EnhancedChatInput"]');
      
      // Also check for any chat input related elements
      const anyTextarea = document.querySelector('textarea');
      const anyChatInput = document.querySelector('[class*="chat-input"], [class*="ChatInput"], [id*="chat-input"]');
      
      return {
        byClassName: !!byClassName,
        byDataTestId: !!byDataTestId,
        byComponentName: !!byComponentName,
        anyTextarea: !!anyTextarea,
        anyChatInput: !!anyChatInput,
        // Get the actual HTML of any chat-related elements found
        chatElements: Array.from(document.querySelectorAll('[class*="chat"], [id*="chat"], textarea')).map(el => ({
          tagName: el.tagName,
          className: el.className,
          id: el.id,
          outerHTML: el.outerHTML.substring(0, 200) + '...'
        }))
      };
    });

    // Look for React errors in the DOM
    const reactErrors = await page.evaluate(() => {
      const errorOverlay = document.querySelector('#webpack-dev-server-client-overlay');
      const nextErrorOverlay = document.querySelector('nextjs-portal');
      const reactErrorBoundary = document.querySelector('[data-reactroot] [class*="error"], [data-reactroot] [class*="Error"]');
      
      return {
        webpackError: errorOverlay?.innerText || null,
        nextError: nextErrorOverlay?.innerText || null,
        reactErrorBoundary: reactErrorBoundary?.innerText || null
      };
    });

    // Summary report
    console.log('\n=== SUMMARY REPORT ===');
    console.log(`Total console messages: ${consoleMessages.length}`);
    console.log(`  Errors: ${consoleMessages.filter(m => m.type === 'error').length}`);
    console.log(`  Warnings: ${consoleMessages.filter(m => m.type === 'warning').length}`);
    console.log(`Page errors: ${pageErrors.length}`);
    console.log(`Failed requests: ${failedRequests.length}`);
    console.log('\nEnhancedChatInput detection:', chatInputExists);
    console.log('\nReact errors:', reactErrors);

    // Detailed error report
    if (consoleMessages.filter(m => m.type === 'error').length > 0) {
      console.log('\n=== CONSOLE ERRORS ===');
      consoleMessages.filter(m => m.type === 'error').forEach(msg => {
        console.log(`[${msg.timestamp}] ${msg.text}`);
        if (msg.location.url) {
          console.log(`  Location: ${msg.location.url}:${msg.location.lineNumber}:${msg.location.columnNumber}`);
        }
      });
    }

    if (pageErrors.length > 0) {
      console.log('\n=== PAGE ERRORS ===');
      pageErrors.forEach(error => {
        console.log(`[${error.timestamp}] ${error.message}`);
        if (error.stack) {
          console.log('Stack trace:', error.stack);
        }
      });
    }

    if (failedRequests.length > 0) {
      console.log('\n=== FAILED REQUESTS ===');
      failedRequests.forEach(req => {
        console.log(`[${req.timestamp}] ${req.method} ${req.url}`);
        console.log(`  Failure: ${req.failure.errorText}`);
      });
    }

    // Look for specific parsing errors
    const parsingErrors = consoleMessages.filter(m => 
      m.text.includes('Unexpected token') || 
      m.text.includes('parsing') || 
      m.text.includes('SyntaxError') ||
      m.text.includes('div')
    );
    
    if (parsingErrors.length > 0) {
      console.log('\n=== PARSING ERRORS FOUND ===');
      parsingErrors.forEach(error => {
        console.log(error.text);
        if (error.location.url) {
          console.log(`  at ${error.location.url}:${error.location.lineNumber}`);
        }
      });
    }

    // Keep browser open for 10 seconds for manual inspection
    console.log('\nKeeping browser open for 10 seconds for manual inspection...');
    await new Promise(resolve => setTimeout(resolve, 10000));

  } catch (error) {
    console.error('Script error:', error);
  } finally {
    await browser.close();
  }
})();