# Speech Recognition Permissions Setup

## Required Info.plist Entries

You need to add these two permissions to your `Info.plist` file in Xcode:

### 1. Microphone Usage Description
**Key:** `NSMicrophoneUsageDescription`
**Value:** `Mano uses your microphone to transcribe your voice messages for easier coaching conversations.`

### 2. Speech Recognition Usage Description
**Key:** `NSSpeechRecognitionUsageDescription`
**Value:** `Mano uses speech recognition to convert your voice into text, making it easier to have coaching conversations.`

---

## How to Add in Xcode

1. Open `Mano.xcodeproj` in Xcode
2. Select the **Mano** target
3. Go to the **Info** tab
4. Click the **+** button under "Custom iOS Target Properties"
5. Add both keys with their descriptions

**Or manually edit Info.plist:**

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Mano uses your microphone to transcribe your voice messages for easier coaching conversations.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Mano uses speech recognition to convert your voice into text, making it easier to have coaching conversations.</string>
```

---

## Testing on Device

Since speech recognition requires actual device microphone access, you must test on a physical device:

1. Add the permissions to Info.plist (as above)
2. Build and run on your iPhone (not simulator)
3. When you first tap-and-hold the mic button, iOS will prompt for permission
4. Grant microphone and speech recognition access
5. Try dictating into the mic button

The simulator will not work for testing speech-to-text features.

---

## Files Modified

- `Mano/Services/SpeechRecognitionService.swift` - Core speech recognition logic
- `Mano/Views/Input/InputComposer.swift` - UI with mic button and tap-and-hold gesture

**Note:** Info.plist must be modified in Xcode, not via command line.
