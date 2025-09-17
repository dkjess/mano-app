import puppeteer from 'puppeteer';

async function testDynamicProfilesSimple() {
  console.log('🧪 Running Simple Browser Test...\n');
  
  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox']
  });

  const page = await browser.newPage();
  
  try {
    // Go to the profile page
    console.log('📍 Navigating to profile page...');
    await page.goto('http://localhost:3000/people/43fe5254-805f-410d-a474-5dd7c9503f77');
    
    // Wait for page to load
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Test 1: Check if main elements exist
    console.log('1️⃣ Checking page elements...');
    
    const hasProfileEditor = await page.$('.profile-editor') !== null;
    const hasTipTap = await page.$('.ProseMirror') !== null; 
    const hasChatInput = await page.$('textarea') !== null;
    
    console.log(`Profile Editor: ${hasProfileEditor ? '✅' : '❌'}`);
    console.log(`TipTap Editor: ${hasTipTap ? '✅' : '❌'}`);
    console.log(`Chat Input: ${hasChatInput ? '✅' : '❌'}`);

    // Test 2: Try typing in profile editor
    if (hasTipTap) {
      console.log('2️⃣ Testing profile editing...');
      await page.click('.ProseMirror');
      await page.type('.ProseMirror', 'Test content from automated test');
      await new Promise(resolve => setTimeout(resolve, 1500));
      console.log('✅ Typed in profile editor');
    }

    // Test 3: Try sending a message
    if (hasChatInput) {
      console.log('3️⃣ Testing message sending...');
      await page.click('textarea');
      await page.type('textarea', 'Test message from automated test');
      await page.keyboard.press('Enter');
      await new Promise(resolve => setTimeout(resolve, 2000));
      console.log('✅ Sent test message');
    }

    console.log('\n✅ Simple browser test completed!');
    console.log('👀 Browser window left open for manual inspection');
    console.log('❓ Please manually verify:');
    console.log('   - Profile content auto-saved');
    console.log('   - Message appeared in chat');
    console.log('   - AI response generated');
    console.log('   - No JavaScript errors in console');

    // Keep browser open for manual inspection
    await new Promise(resolve => setTimeout(resolve, 30000));

  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await browser.close();
  }
}

testDynamicProfilesSimple().catch(console.error);