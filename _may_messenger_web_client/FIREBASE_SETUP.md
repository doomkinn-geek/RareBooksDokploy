# Firebase Push Notifications Setup (Optional)

The web client is built **without Firebase by default** to avoid build issues. Push notifications are optional and can be enabled later.

## Why Firebase is Optional

Firebase SDK v10+ has compatibility issues with Vite 5 during build time. To keep the build process simple and fast, Firebase is excluded by default.

## Current Status

✅ **Web client builds successfully**  
⚠️ **Push notifications disabled** (will work after Firebase is configured)  
✅ **All other features work** (SignalR, messaging, audio, etc.)

---

## How to Enable Push Notifications

### Step 1: Install Firebase

```bash
cd _may_messenger_web_client
npm install firebase@latest
```

### Step 2: Uncomment Firebase Imports

Open `src/services/fcmService.ts` and:

1. **Uncomment these imports** (lines 14-15):
```typescript
import { initializeApp, FirebaseApp } from 'firebase/app';
import { getMessaging, getToken, onMessage, Messaging, MessagePayload } from 'firebase/messaging';
```

2. **Remove the temporary type definitions** (lines 18-21):
```typescript
// DELETE THESE:
type FirebaseApp = any;
type Messaging = any;
type MessagePayload = any;
```

3. **Uncomment the `initialize()` method** (around line 70)
4. **Uncomment the `requestPermissionAndGetToken()` method** (around line 120)

### Step 3: Configure Firebase

In `src/services/fcmService.ts`, update the Firebase config (lines 11-18):

```typescript
const firebaseConfig = {
  apiKey: "YOUR_ACTUAL_API_KEY",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef",
};

const VAPID_KEY = "YOUR_ACTUAL_VAPID_KEY";
```

**Where to get these values:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings → General → Your apps
4. Copy the config object
5. Go to Cloud Messaging → Web Push certificates
6. Generate or copy your VAPID key

### Step 4: Update Service Worker

The Service Worker (`public/sw.js`) already has FCM support. Just ensure your `firebase-messaging-sw.js` is configured:

Create `public/firebase-messaging-sw.js`:
```javascript
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "YOUR_API_KEY",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef"
});

const messaging = firebase.messaging();
```

### Step 5: Update Dockerfile (Optional)

If you want Firebase in Docker, update `package.json` before building:

```json
{
  "dependencies": {
    "firebase": "^11.0.0",
    // ... other deps
  }
}
```

Then rebuild:
```bash
docker-compose build maymessenger_web_client
docker-compose up -d
```

---

## Testing Push Notifications

1. Open the web app in a browser
2. Login to your account
3. Grant notification permission when prompted
4. Send a message from mobile app
5. You should receive a push notification (even when tab is inactive)

---

## Troubleshooting

### Build fails with Firebase error

**Solution:** Make sure you're using Firebase v11 or later:
```bash
npm install firebase@latest
```

### Notifications not appearing

1. Check browser console for errors
2. Ensure notifications permission is granted
3. Verify Firebase config is correct
4. Check that VAPID key is set
5. Ensure Service Worker is registered

### Token not registering

Check the browser console. If you see "Firebase not installed", follow Step 1-2 above.

---

## Alternative: Web Push without Firebase

If you don't want to use Firebase, you can implement native Web Push API directly:

1. Generate VAPID keys with `web-push` npm package
2. Use `navigator.serviceWorker.pushManager.subscribe()`
3. Send push subscriptions to backend
4. Backend sends notifications via Web Push protocol

This is more complex but doesn't require Firebase dependency.

---

## Performance Impact

- **Without Firebase:** Build size ~500KB smaller, faster builds
- **With Firebase:** Push notifications work, slightly larger bundle

Choose based on your needs:
- **Prototyping/MVP:** Skip Firebase initially ✅
- **Production with push:** Enable Firebase ✅

---

## Current Build Configuration

The web client is configured to:
- ✅ Build without Firebase
- ✅ Show warnings about missing Firebase
- ✅ Gracefully degrade (all other features work)
- ✅ Easy to enable later (just uncomment code)

This approach ensures a smooth development experience while keeping push notifications as an optional enhancement.

