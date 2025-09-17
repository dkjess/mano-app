/**
 * Manual Browser Test for Dynamic Profiles
 * 
 * Instructions:
 * 1. Open http://localhost:3000/people/43fe5254-805f-410d-a474-5dd7c9503f77
 * 2. Open browser console (F12)
 * 3. Copy and paste this script
 * 4. Run: testDynamicProfiles()
 */

async function testDynamicProfiles() {
  console.log('🧪 Starting Dynamic Profiles Browser Test\n');
  let results = {
    passed: 0,
    failed: 0,
    tests: []
  };

  function test(name, assertion, expected = true) {
    try {
      const result = assertion();
      const passed = expected ? !!result : !result;
      if (passed) {
        console.log(`✅ ${name}`);
        results.passed++;
      } else {
        console.log(`❌ ${name} - Expected: ${expected}, Got: ${!!result}`);
        results.failed++;
      }
      results.tests.push({ name, passed, result });
    } catch (error) {
      console.log(`❌ ${name} - Error: ${error.message}`);
      results.failed++;
      results.tests.push({ name, passed: false, error: error.message });
    }
  }

  // Test 1: Page loaded correctly
  test('Page loaded with person profile', () => {
    return window.location.pathname.includes('/people/') && 
           window.location.href.includes('43fe5254-805f-410d-a474-5dd7c9503f77');
  });

  // Test 2: Profile editor present
  test('Profile editor is present', () => {
    return document.querySelector('.profile-editor') !== null;
  });

  // Test 3: TipTap editor present
  test('TipTap editor is present', () => {
    return document.querySelector('.ProseMirror') !== null;
  });

  // Test 4: Chat input present
  test('Chat input is present', () => {
    return document.querySelector('textarea[placeholder*="Type your message"]') !== null;
  });

  // Test 5: Split pane layout (desktop)
  test('Split pane layout present', () => {
    return window.innerWidth > 1024 ? 
           document.querySelector('[role="separator"]') !== null :
           true; // Skip on mobile
  });

  // Test 6: Mobile tabs (mobile view)
  if (window.innerWidth <= 1024) {
    test('Mobile tabs present', () => {
      const chatTab = Array.from(document.querySelectorAll('button')).find(b => b.textContent?.includes('Chat'));
      const profileTab = Array.from(document.querySelectorAll('button')).find(b => b.textContent?.includes('Profile'));
      return chatTab && profileTab;
    });
  }

  // Test 7: Profile content editing
  console.log('\n🔄 Testing profile content editing...');
  const editor = document.querySelector('.ProseMirror');
  if (editor) {
    test('Profile editor can be focused', () => {
      editor.focus();
      return document.activeElement === editor || editor.contains(document.activeElement);
    });

    // Clear and type test content
    const testContent = `Browser test content ${Date.now()}`;
    try {
      editor.focus();
      document.execCommand('selectAll');
      document.execCommand('delete');
      document.execCommand('insertText', false, testContent);
      
      test('Profile content was inserted', () => {
        return editor.textContent?.includes(testContent.substring(0, 20));
      });

      // Wait for auto-save
      console.log('⏳ Waiting for auto-save (2 seconds)...');
      await new Promise(resolve => setTimeout(resolve, 2000));

      test('Auto-save status shown', () => {
        const saveStatus = document.querySelector('.profile-header p');
        return saveStatus && (
          saveStatus.textContent?.includes('All changes saved') || 
          saveStatus.textContent?.includes('Saving...')
        );
      });
    } catch (error) {
      console.log(`❌ Profile editing failed: ${error.message}`);
      results.failed++;
    }
  }

  // Test 8: Message sending
  console.log('\n🔄 Testing message sending...');
  const chatInput = document.querySelector('textarea[placeholder*="Type your message"]');
  if (chatInput) {
    test('Chat input can be focused', () => {
      chatInput.focus();
      return document.activeElement === chatInput;
    });

    const testMessage = `Browser test message ${Date.now()}`;
    const initialMessageCount = document.querySelectorAll('.message-bubble').length;
    
    try {
      chatInput.value = testMessage;
      chatInput.dispatchEvent(new Event('input', { bubbles: true }));

      // Simulate Enter key
      const enterEvent = new KeyboardEvent('keydown', {
        key: 'Enter',
        code: 'Enter',
        keyCode: 13,
        which: 13,
        bubbles: true
      });
      chatInput.dispatchEvent(enterEvent);

      console.log('⏳ Waiting for message to appear (3 seconds)...');
      await new Promise(resolve => setTimeout(resolve, 3000));

      test('User message appeared', () => {
        const messages = document.querySelectorAll('.message-bubble');
        return messages.length > initialMessageCount &&
               Array.from(messages).some(msg => msg.textContent?.includes(testMessage));
      });

      // Wait a bit more for AI response
      console.log('⏳ Waiting for AI response (5 seconds)...');
      await new Promise(resolve => setTimeout(resolve, 5000));

      test('AI response appeared', () => {
        const messages = document.querySelectorAll('.message-bubble');
        const userMessages = Array.from(messages).filter(msg => 
          msg.textContent?.includes(testMessage)
        );
        return messages.length > initialMessageCount + 1; // User + AI message
      });

    } catch (error) {
      console.log(`❌ Message sending failed: ${error.message}`);
      results.failed++;
    }
  }

  // Test 9: Check console for errors
  const errors = [];
  const originalError = console.error;
  console.error = (...args) => {
    errors.push(args.join(' '));
    originalError.apply(console, args);
  };

  setTimeout(() => {
    console.error = originalError;
    test('No JavaScript errors in console', () => {
      const relevantErrors = errors.filter(err => 
        !err.includes('favicon') && 
        !err.includes('devtools') &&
        !err.includes('Extension')
      );
      if (relevantErrors.length > 0) {
        console.log('Console errors:', relevantErrors);
      }
      return relevantErrors.length === 0;
    });

    // Final results
    console.log('\n📊 Test Results Summary:');
    console.log('========================');
    console.log(`✅ Passed: ${results.passed}`);
    console.log(`❌ Failed: ${results.failed}`);
    console.log(`📈 Success Rate: ${Math.round((results.passed / (results.passed + results.failed)) * 100)}%`);

    if (results.failed > 0) {
      console.log('\n❌ Failed Tests:');
      results.tests.filter(t => !t.passed).forEach(t => {
        console.log(`  - ${t.name}${t.error ? ': ' + t.error : ''}`);
      });
    }

    console.log('\n🏁 Browser testing completed!');
  }, 1000);
}

// Make function available globally
if (typeof window !== 'undefined') {
  window.testDynamicProfiles = testDynamicProfiles;
  console.log(`
🧪 Dynamic Profiles Browser Test Ready!

To run the test:
1. Make sure you're on: http://localhost:3000/people/43fe5254-805f-410d-a474-5dd7c9503f77
2. Run: testDynamicProfiles()

This will test:
- Profile editor functionality
- TipTap auto-save
- Message sending
- AI responses
- Layout components
- Error checking
  `);
}