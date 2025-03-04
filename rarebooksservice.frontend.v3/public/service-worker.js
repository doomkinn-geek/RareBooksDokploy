// Service Worker для RareBooks Frontend
const CACHE_NAME = 'rarebooks-cache-v1';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/assets/index.css',
  '/assets/index.js',
];

// Установка сервис-воркера и кеширование основных ресурсов
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Кеширование статичных ресурсов');
        return cache.addAll(STATIC_ASSETS);
      })
  );
});

// Активация сервис-воркера и очистка старых кешей
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Удаление старого кеша:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

// Стратегия "Cache First, Network Fallback" для статичных ресурсов
// и "Network First, Cache Fallback" для API запросов
self.addEventListener('fetch', (event) => {
  // Пропускаем API запросы, чтобы они всегда шли напрямую в сеть
  if (event.request.url.includes('/api/')) {
    return;
  }

  // Для статичных ресурсов используем стратегию "Cache First, Network Fallback"
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Если ресурс найден в кеше, возвращаем его
        if (response) {
          return response;
        }
        
        // Иначе делаем сетевой запрос и кешируем результат
        return fetch(event.request)
          .then((networkResponse) => {
            // Не кешируем ошибочные ответы
            if (!networkResponse || networkResponse.status !== 200 || networkResponse.type !== 'basic') {
              return networkResponse;
            }

            // Кешируем новый ресурс и возвращаем response
            const responseToCache = networkResponse.clone();
            caches.open(CACHE_NAME)
              .then((cache) => {
                cache.put(event.request, responseToCache);
              });

            return networkResponse;
          })
          .catch(() => {
            // Если нет сети и ресурса в кеше, возвращаем fallback страницу
            if (event.request.headers.get('accept').includes('text/html')) {
              return caches.match('/offline.html');
            }
          });
      })
  );
}); 