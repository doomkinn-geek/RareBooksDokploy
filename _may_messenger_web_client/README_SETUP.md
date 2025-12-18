# May Messenger Web Client - Setup Guide

## Firebase Configuration

The web client now supports Web Push Notifications via Firebase Cloud Messaging (FCM). To enable this feature, you need to configure Firebase.

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Register your web app

### Step 2: Get Configuration

1. In Firebase Console, go to Project Settings
2. Under "Your apps", select your web app
3. Copy the Firebase configuration object

### Step 3: Update fcmService.ts

Open `src/services/fcmService.ts` and replace the configuration:

```typescript
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_AUTH_DOMAIN",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_STORAGE_BUCKET",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID",
};
```

### Step 4: Get VAPID Key

1. In Firebase Console, go to Project Settings > Cloud Messaging
2. Under "Web Push certificates", generate a new key pair
3. Copy the "Key pair" value

Update `src/services/fcmService.ts`:

```typescript
const VAPID_KEY = "YOUR_VAPID_KEY";
```

### Step 5: Generate PWA Icons

Generate icon files in different sizes (see `public/icon-readme.md`):

```bash
# Install dependencies
npm install

# Generate icons from a 512x512 source image
# (use ImageMagick, online tools, or PWA asset generators)
```

### Step 6: Build and Deploy

```bash
# Install dependencies
npm install

# Development
npm run dev

# Production build
npm run build

# Preview production build
npm run preview
```

## Features

### ✅ Implemented

- ✅ Web Push Notifications (Service Worker)
- ✅ Browser Notifications API
- ✅ FCM Integration for push messages
- ✅ Message status indicators (Sending, Sent, Delivered, Read)
- ✅ Typing indicators
- ✅ PWA manifest (Progressive Web App)
- ✅ Offline sync service
- ✅ Audio messages
- ✅ SignalR real-time communication
- ✅ Message retry on failure

### 🎨 UI Improvements

- Status icons for messages (clock, checkmark, double-checkmark)
- Animated typing indicator with dots
- Retry button for failed messages
- Visual feedback for message states

## Testing Push Notifications

1. Open the web client in a browser (Chrome/Firefox/Edge recommended)
2. Grant notification permissions when prompted
3. Send a message from another device
4. You should receive a browser notification even when the tab is not visible

## Browser Compatibility

- ✅ Chrome/Edge (full support)
- ✅ Firefox (full support)
- ⚠️ Safari (limited Service Worker support, notifications work but FCM may not)
- ❌ Internet Explorer (not supported)

## Deployment

### Nginx Configuration

Add to your nginx config:

```nginx
# Service Worker must be served with proper headers
location /sw.js {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Service-Worker-Allowed "/";
}

# PWA Manifest
location /manifest.json {
    add_header Content-Type "application/manifest+json";
}
```

### Docker

The project includes a Dockerfile. Build and run:

```bash
docker build -t may-messenger-web .
docker run -p 80:80 may-messenger-web
```

