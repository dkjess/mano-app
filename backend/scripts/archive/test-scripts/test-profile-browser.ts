/**
 * Browser-based test for Dynamic Profiles
 * Run this in the browser console after logging in
 */

async function testDynamicProfiles() {
  console.log('🧪 Testing Dynamic Profiles in Browser\n');
  
  // 1. Check if we're on a person page with dynamic profiles enabled
  const profileEditor = document.querySelector('.profile-editor');
  if (!profileEditor) {
    console.error('❌ Profile editor not found. Make sure you are on a person page.');
    return;
  }
  console.log('✅ Profile editor found');
  
  // 2. Test profile content editing
  console.log('\n2️⃣ Testing profile content editing...');
  const editor = document.querySelector('.ProseMirror');
  if (!editor) {
    console.error('❌ TipTap editor not found');
    return;
  }
  
  // Focus the editor and add content
  editor.focus();
  const testContent = `Test content ${Date.now()}`;
  
  // Clear existing content
  document.execCommand('selectAll');
  document.execCommand('delete');
  
  // Type new content
  document.execCommand('insertText', false, testContent);
  
  console.log('✅ Typed test content, waiting for auto-save...');
  
  // Wait for auto-save indicator
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  const saveStatus = document.querySelector('.profile-header p');
  if (saveStatus?.textContent?.includes('All changes saved')) {
    console.log('✅ Auto-save confirmed');
  } else {
    console.warn('⚠️  Save status not confirmed');
  }
  
  // 3. Test message sending
  console.log('\n3️⃣ Testing message sending...');
  const chatInput = document.querySelector('textarea[placeholder*="Type your message"]');
  if (!chatInput) {
    console.error('❌ Chat input not found');
    return;
  }
  
  const testMessage = `Test message ${Date.now()}`;
  chatInput.value = testMessage;
  chatInput.dispatchEvent(new Event('input', { bubbles: true }));
  
  // Simulate Enter key press
  const enterEvent = new KeyboardEvent('keydown', {
    key: 'Enter',
    code: 'Enter',
    keyCode: 13,
    which: 13,
    bubbles: true
  });
  chatInput.dispatchEvent(enterEvent);
  
  console.log('✅ Message sent, waiting for response...');
  
  // Wait for message to appear
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  const messages = document.querySelectorAll('.message-bubble');
  const lastMessage = messages[messages.length - 1];
  if (lastMessage?.textContent?.includes(testMessage)) {
    console.log('✅ Message appeared in chat');
  } else {
    console.warn('⚠️  Message not found in chat');
  }
  
  // 4. Test desktop split-pane
  console.log('\n4️⃣ Testing split-pane functionality...');
  const resizeHandle = document.querySelector('[role="separator"]');
  if (resizeHandle) {
    console.log('✅ Split-pane resize handle found');
  } else {
    console.warn('⚠️  Split-pane not found (might be on mobile view)');
  }
  
  console.log('\n✅ Browser tests completed!');
  console.log('📝 Manual verification needed for:');
  console.log('   - Profile content persistence after reload');
  console.log('   - Mobile tab switching');
  console.log('   - Multiple rapid messages');
}

// Instructions for running
console.log(`
To run the test:
1. Log in to the application
2. Navigate to any person's profile
3. Open browser console (F12)
4. Copy and paste this entire script
5. Run: testDynamicProfiles()
`);

// Make function available globally
window.testDynamicProfiles = testDynamicProfiles;