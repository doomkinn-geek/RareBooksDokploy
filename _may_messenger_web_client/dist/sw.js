// Service Worker for Web Push Notifications and Offline Support
const CACHE_NAME = 'may-messenger-v1.1';
const RUNTIME_CACHE = 'may-messenger-runtime';

// Assets to cache on install
const PRECACHE_ASSETS = [
  '/web/',
  '/web/index.html',
  // Icons
  '/icon-192.png',
  '/icon-96.png',
];

self.addEventListener('install', (event) => {
  console.log('[SW] Service Worker installing...');
  
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Caching app shell');
      return cache.addAll(PRECACHE_ASSETS.map(url => 
        new Request(url, { cache: 'reload' })
      )).catch((err) => {
        console.error('[SW] Failed to cache assets:', err);
      });
    }).then(() => {
      return self.skipWaiting();
    })
  );
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Service Worker activating...');
  
  event.waitUntil(
    // Clean up old caches
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME && cacheName !== RUNTIME_CACHE) {
            console.log('[SW] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      return clients.claim();
    })
  );
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

// Network strategies for different request types
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Skip non-GET requests and external URLs
  if (request.method !== 'GET' || !url.origin.includes(self.location.origin)) {
    return;
  }

  // Skip API calls (let them go through network)
  if (url.pathname.includes('/api/')) {
    return;
  }

  // HTML files - Network first, fallback to cache
  if (request.headers.get('accept').includes('text/html')) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          // Cache successful responses
          if (response.ok) {
            const responseClone = response.clone();
            caches.open(RUNTIME_CACHE).then((cache) => {
              cache.put(request, responseClone);
            });
          }
          return response;
        })
        .catch(() => {
          // Fallback to cache
          return caches.match(request).then((cachedResponse) => {
            return cachedResponse || caches.match('/web/index.html');
          });
        })
    );
    return;
  }

  // Static assets - Cache first, fallback to network
  if (request.url.match(/\.(js|css|png|jpg|jpeg|gif|svg|woff|woff2|ttf|ico)$/)) {
    event.respondWith(
      caches.match(request).then((cachedResponse) => {
        if (cachedResponse) {
          return cachedResponse;
        }
        
        return fetch(request).then((response) => {
          // Cache for future use
          if (response.ok) {
            const responseClone = response.clone();
            caches.open(RUNTIME_CACHE).then((cache) => {
              cache.put(request, responseClone);
            });
          }
          return response;
        });
      })
    );
    return;
  }

  // Default - Network first
  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.ok) {
          const responseClone = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => {
            cache.put(request, responseClone);
          });
        }
        return response;
      })
      .catch(() => {
        return caches.match(request);
      })
  );
});

