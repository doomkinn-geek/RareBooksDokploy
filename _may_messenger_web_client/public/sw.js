// Service Worker for Web Push Notifications
const CACHE_NAME = 'may-messenger-v1';

self.addEventListener('install', (event) => {
  console.log('[SW] Service Worker installing...');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Service Worker activating...');
  event.waitUntil(clients.claim());
});

// Handle push notifications (FCM Data Messages)
self.addEventListener('push', (event) => {
  console.log('[SW] Push notification received', event);
  
  if (!event.data) {
    console.log('[SW] No data in push event');
    return;
  }

  try {
    const data = event.data.json();
    console.log('[SW] Push data:', data);
    
    // Extract notification details from data payload
    const title = data.title || data.data?.title || 'May Messenger';
    const body = data.body || data.data?.body || 'New message';
    const chatId = data.chatId || data.data?.chatId;
    const icon = '/icon-192.png';
    const badge = '/icon-96.png';

    const notificationOptions = {
      body,
      icon,
      badge,
      tag: chatId || 'default', // Group by chat
      data: {
        chatId,
        url: `/web/?chat=${chatId}`,
      },
      actions: [
        {
          action: 'open',
          title: 'Открыть',
        },
      ],
      requireInteraction: false,
      vibrate: [200, 100, 200],
    };

    event.waitUntil(
      self.registration.showNotification(title, notificationOptions)
    );
  } catch (error) {
    console.error('[SW] Error parsing push data:', error);
  }
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked', event);
  
  event.notification.close();

  const chatId = event.notification.data?.chatId;
  const urlToOpen = chatId 
    ? `${self.location.origin}/web/?chat=${chatId}`
    : `${self.location.origin}/web/`;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Check if there's already a window open
      for (const client of clientList) {
        if (client.url.includes('/web') && 'focus' in client) {
          // Navigate existing window to chat
          client.postMessage({
            type: 'OPEN_CHAT',
            chatId,
          });
          return client.focus();
        }
      }
      
      // Open new window if none exists
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});

// Handle messages from clients (e.g., cache updates)
self.addEventListener('message', (event) => {
  console.log('[SW] Message received:', event.data);
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

