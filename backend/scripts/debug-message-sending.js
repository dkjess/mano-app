/**
 * Debug script for message sending in Dynamic Profiles
 * Run this in browser console after opening the profile page
 */

async function debugMessageSending() {
  console.log('🔍 Debugging Message Sending...\n');

  // Test 1: Check if chat input exists and is functional
  const chatInput = document.querySelector('textarea[placeholder*="Type your message"]');
  console.log('1️⃣ Chat Input:', chatInput ? '✅ Found' : '❌ Not found');

  if (!chatInput) {
    console.log('❌ Cannot proceed without chat input');
    return;
  }

  // Test 2: Check if we can type in the input
  try {
    chatInput.focus();
    chatInput.value = 'Debug test message';
    chatInput.dispatchEvent(new Event('input', { bubbles: true }));
    console.log('2️⃣ Typing in input: ✅ Works');
  } catch (error) {
    console.log('2️⃣ Typing in input: ❌ Error:', error.message);
  }

  // Test 3: Check if Enter key handler exists
  try {
    const enterEvent = new KeyboardEvent('keydown', {
      key: 'Enter',
      code: 'Enter',
      keyCode: 13,
      which: 13,
      bubbles: true
    });
    
    console.log('3️⃣ Simulating Enter key...');
    chatInput.dispatchEvent(enterEvent);
    console.log('3️⃣ Enter key dispatched: ✅');
  } catch (error) {
    console.log('3️⃣ Enter key error: ❌', error.message);
  }

  // Test 4: Monitor network requests
  console.log('4️⃣ Monitoring network requests for 10 seconds...');
  
  const originalFetch = window.fetch;
  window.fetch = function(...args) {
    console.log('🌐 Network Request:', args[0], args[1]?.method || 'GET');
    return originalFetch.apply(this, args);
  };

  setTimeout(() => {
    window.fetch = originalFetch;
    console.log('4️⃣ Network monitoring ended');
  }, 10000);

  // Test 5: Check for JavaScript errors
  const originalError = console.error;
  const errors = [];
  console.error = function(...args) {
    errors.push(args.join(' '));
    originalError.apply(console, args);
  };

  setTimeout(() => {
    console.error = originalError;
    console.log('5️⃣ JavaScript Errors:', errors.length === 0 ? '✅ None' : '❌ Found:', errors);
  }, 5000);

  console.log('\n💡 Instructions:');
  console.log('1. Try typing a message in the chat input');
  console.log('2. Press Enter to send');
  console.log('3. Watch console for network requests and errors');
}

// Make function available globally
window.debugMessageSending = debugMessageSending;

console.log(`
🔍 Message Sending Debug Tool Ready!

To debug message sending:
1. Make sure you're on a person profile page
2. Run: debugMessageSending()
3. Follow the instructions

This will help identify where message sending is failing.
`);