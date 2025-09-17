#!/usr/bin/env node

/**
 * Debug File-Only Upload 
 * Detailed network monitoring to see exactly what's being sent
 */

import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';

async function debugFileOnly() {
  console.log('🔬 Debug File-Only Upload - Network Analysis');
  console.log('============================================');
  
  const browser = await puppeteer.launch({
    headless: false,
    devtools: true,
    args: ['--start-maximized'],
    defaultViewport: null
  });

  const page = await browser.newPage();
  
  let chatRequests = [];
  
  // Intercept ALL network requests
  await page.setRequestInterception(true);
  
  page.on('request', request => {
    if (request.url().includes('/api/chat')) {
      console.log('\n🌐 INTERCEPTED REQUEST TO /api/chat');
      console.log('📤 Method:', request.method());
      console.log('📤 Headers:', JSON.stringify(request.headers(), null, 2));
      console.log('📤 Post Data:', request.postData());
      
      chatRequests.push({
        method: request.method(),
        headers: request.headers(),
        postData: request.postData(),
        timestamp: new Date().toISOString()
      });
    }
    request.continue();
  });
  
  page.on('response', async response => {
    if (response.url().includes('/api/chat')) {
      const status = response.status();
      console.log(`\n📥 RESPONSE FROM /api/chat - Status: ${status}`);
      
      try {
        const responseHeaders = response.headers();
        console.log('📥 Response Headers:', JSON.stringify(responseHeaders, null, 2));
        
        if (status >= 400) {
          const errorText = await response.text();
          console.log('📥 Error Response:', errorText);
        }
      } catch (e) {
        console.log('📥 Could not read response details');
      }
    }
  });

  const outputDir = './test-outputs';
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  try {
    console.log('\n🔐 Login');
    await page.goto('http://localhost:3000/auth/login');
    await page.type('input[type="email"]', 'dev@mano.local');
    await page.type('input[type="password"]', 'dev123456');
    await page.click('button[type="submit"]');
    await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 });
    
    console.log('\n📁 Navigate to person chat');
    await page.goto('http://localhost:3000/people/3d144990-628f-4f86-86c2-587ebdc47661');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    console.log('\n📄 Create test file');
    const testFilePath = path.join(outputDir, 'debug-test.txt');
    fs.writeFileSync(testFilePath, 'Debug test file content for file-only upload.');
    
    console.log('\n📎 Upload file');
    // Click attachment button
    await page.evaluate(() => {
      const button = Array.from(document.querySelectorAll('button')).find(btn => btn.textContent.includes('📎'));
      if (button) button.click();
    });
    
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Upload file
    const fileInput = await page.$('input[type="file"]');
    await fileInput.uploadFile(testFilePath);
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    console.log('\n🔍 Check form state before send');
    const formState = await page.evaluate(() => {
      const input = document.querySelector('input[value], textarea, [contenteditable]');
      const sendButton = document.querySelector('button[type="submit"]');
      
      return {
        inputValue: input ? (input.value || input.textContent || '') : 'NO INPUT FOUND',
        inputPlaceholder: input ? input.placeholder : 'NO PLACEHOLDER',
        sendButtonDisabled: sendButton ? sendButton.disabled : 'NO BUTTON FOUND',
        sendButtonText: sendButton ? sendButton.textContent : 'NO BUTTON TEXT'
      };
    });
    
    console.log('📋 Form State:', JSON.stringify(formState, null, 2));
    
    console.log('\n🚀 Click send button');
    const sendButton = await page.$('button[type="submit"]');
    await sendButton.click();
    
    console.log('\n⏳ Wait for request/response');
    await new Promise(resolve => setTimeout(resolve, 10000));
    
    // Clean up
    fs.unlinkSync(testFilePath);
    
    console.log('\n📊 ANALYSIS SUMMARY:');
    console.log('===================');
    console.log(`Chat API requests made: ${chatRequests.length}`);
    
    if (chatRequests.length === 0) {
      console.log('❌ NO API REQUESTS DETECTED - Frontend issue');
    } else {
      chatRequests.forEach((req, i) => {
        console.log(`\nRequest ${i + 1}:`);
        console.log(`  Method: ${req.method}`);
        console.log(`  Data: ${req.postData ? req.postData.substring(0, 200) + '...' : 'No data'}`);
      });
    }
    
    const resultsFile = path.join(outputDir, `debug-results-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
    fs.writeFileSync(resultsFile, JSON.stringify({
      formState,
      chatRequests,
      timestamp: new Date().toISOString()
    }, null, 2));
    
    console.log(`\n📄 Debug results saved: ${resultsFile}`);
    
  } catch (error) {
    console.error('🔴 Debug test failed:', error.message);
  }
  
  console.log('\n🔍 Browser left open. Check Network tab in DevTools for more details.');
}

debugFileOnly().catch(console.error);