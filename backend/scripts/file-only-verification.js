#!/usr/bin/env node

/**
 * File-Only Upload Verification Test
 * Tests if file-only uploads actually work end-to-end
 */

import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';

async function fileOnlyVerification() {
  console.log('🔬 File-Only Upload Verification Test');
  console.log('====================================');
  
  const browser = await puppeteer.launch({
    headless: false,
    devtools: true,
    args: ['--start-maximized'],
    defaultViewport: null
  });

  const page = await browser.newPage();
  
  let messagesSent = [];
  let errors = [];
  
  // Monitor network requests to catch API calls
  page.on('response', async response => {
    if (response.url().includes('/api/chat')) {
      const status = response.status();
      console.log(`🌐 API Call: POST /api/chat - Status: ${status}`);
      
      if (status === 200) {
        try {
          const responseData = await response.text();
          console.log(`✅ Chat API success: ${responseData.substring(0, 100)}...`);
        } catch (e) {
          console.log(`✅ Chat API success (couldn't read response)`);
        }
      } else {
        console.log(`❌ Chat API failed with status ${status}`);
      }
    }
  });

  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.log(`🔴 Console Error: ${msg.text()}`);
      errors.push(msg.text());
    }
  });

  const outputDir = './test-outputs';
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  async function takeScreenshot(name) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `verify-${timestamp}-${name}.png`;
    const filepath = path.join(outputDir, filename);
    await page.screenshot({ path: filepath, fullPage: true });
    console.log(`📸 Screenshot: ${filename}`);
  }

  try {
    console.log('\n🔐 Step 1: Login');
    await page.goto('http://localhost:3000/auth/login');
    await page.type('input[type="email"]', 'dev@mano.local');
    await page.type('input[type="password"]', 'dev123456');
    await page.click('button[type="submit"]');
    await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 });
    
    console.log('\n📁 Step 2: Navigate to person chat');
    await page.goto('http://localhost:3000/people/3d144990-628f-4f86-86c2-587ebdc47661');
    await new Promise(resolve => setTimeout(resolve, 3000));
    await takeScreenshot('person-page-loaded');
    
    console.log('\n📊 Step 3: Count initial messages');
    const initialMessages = await page.$$('.message, [data-message], [class*="message"]');
    const initialCount = initialMessages.length;
    console.log(`📌 Initial message count: ${initialCount}`);
    
    console.log('\n📄 Step 4: Create and upload test file');
    const testFilePath = path.join(outputDir, 'verification-test.txt');
    const fileContent = 'This is a file-only upload verification test. No text message should accompany this file.';
    fs.writeFileSync(testFilePath, fileContent);
    
    // Find attachment button (look for the 📎 emoji)
    const attachButton = await page.evaluateHandle(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      return buttons.find(btn => btn.textContent.includes('📎'));
    });
    
    if (attachButton && attachButton.asElement()) {
      console.log('📌 Found attachment button, clicking...');
      await attachButton.asElement().click();
      await new Promise(resolve => setTimeout(resolve, 500));
    } else {
      console.log('📌 No attachment button found, looking for file input directly');
    }
    
    // Upload file
    const fileInput = await page.$('input[type="file"]');
    if (!fileInput) {
      throw new Error('File input not found');
    }
    
    await fileInput.uploadFile(testFilePath);
    await new Promise(resolve => setTimeout(resolve, 2000));
    await takeScreenshot('file-uploaded');
    
    console.log('\n🔍 Step 5: Verify send button state');
    const sendButton = await page.$('button[type="submit"]');
    if (!sendButton) {
      throw new Error('Send button not found');
    }
    
    const isDisabled = await sendButton.evaluate(btn => btn.disabled);
    console.log(`📌 Send button disabled: ${isDisabled}`);
    
    if (isDisabled) {
      console.log('❌ FAILED: Send button is disabled with file upload');
      await takeScreenshot('send-button-disabled');
      return;
    }
    
    console.log('\n🚀 Step 6: Send file-only message');
    await sendButton.click();
    console.log('📌 Send button clicked');
    
    // Wait for response
    await new Promise(resolve => setTimeout(resolve, 8000));
    await takeScreenshot('after-send');
    
    console.log('\n📊 Step 7: Verify message was sent');
    const finalMessages = await page.$$('.message, [data-message], [class*="message"]');
    const finalCount = finalMessages.length;
    console.log(`📌 Final message count: ${finalCount}`);
    console.log(`📌 Messages added: ${finalCount - initialCount}`);
    
    if (finalCount > initialCount) {
      console.log('✅ SUCCESS: File-only message appears to have been sent!');
      
      // Try to find the newest message
      const lastMessage = await page.$('div[class*="message"]:last-child, .message:last-child');
      if (lastMessage) {
        const messageText = await lastMessage.evaluate(el => el.textContent);
        console.log(`📌 Last message content: "${messageText.substring(0, 100)}..."`);
      }
    } else {
      console.log('❌ FAILED: No new messages detected');
    }
    
    // Clean up
    fs.unlinkSync(testFilePath);
    
    console.log('\n📋 VERIFICATION SUMMARY:');
    console.log('=======================');
    console.log(`Send button disabled with file: ${isDisabled}`);
    console.log(`Messages before: ${initialCount}`);
    console.log(`Messages after: ${finalCount}`);
    console.log(`New messages: ${finalCount - initialCount}`);
    console.log(`Console errors: ${errors.length}`);
    
    if (!isDisabled && finalCount > initialCount) {
      console.log('🎉 RESULT: File-only uploads appear to be WORKING!');
    } else {
      console.log('🚨 RESULT: File-only uploads are NOT working properly');
    }
    
  } catch (error) {
    console.error('🔴 Verification test failed:', error.message);
    await takeScreenshot('verification-error');
  }
  
  console.log('\n🔍 Browser left open for manual inspection.');
}

fileOnlyVerification().catch(console.error);