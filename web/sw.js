const CACHE_NAME = 'whatsapp-monitor-v1';
const urlsToCache = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/assets/images/edicion-de-fotos.png',
  '/assets/images/fondo.png',
  '/assets/images/blank-profile.png',
  '/assets/images/chats.png',
  '/assets/images/home.png',
  '/assets/images/image_data.png',
  '/assets/images/loading.gif',
  '/assets/images/login.png',
  '/assets/images/mensaje.png',
  '/assets/images/mensajes.png',
  // Cache Firebase assets if needed
  'https://www.gstatic.com/firebasejs/9.22.0/firebase-app.js',
  'https://www.gstatic.com/firebasejs/9.22.0/firebase-auth.js',
  'https://www.gstatic.com/firebasejs/9.22.0/firebase-firestore.js',
  'https://www.gstatic.com/firebasejs/9.22.0/firebase-storage.js'
];

// Install event - cache resources
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        return cache.addAll(urlsToCache);
      })
  );
});

// Fetch event - serve from cache when offline
self.addEventListener('fetch', (event) => {
  // Handle image requests specially for offline viewing
  if (event.request.url.includes('/assets/images/') ||
      event.request.url.includes('firebasestorage.googleapis.com')) {
    event.respondWith(
      caches.match(event.request)
        .then((response) => {
          // Return cached version or fetch from network
          return response || fetch(event.request).then((response) => {
            // Cache the new response for future offline use
            if (response.status === 200) {
              const responseClone = response.clone();
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(event.request, responseClone);
              });
            }
            return response;
          }).catch(() => {
            // If network fails and no cache, return a placeholder
            if (event.request.url.includes('firebasestorage.googleapis.com')) {
              return caches.match('/assets/images/image_data.png');
            }
          });
        })
    );
  } else {
    // For other requests, try network first, then cache
    event.respondWith(
      fetch(event.request)
        .catch(() => {
          return caches.match(event.request);
        })
    );
  }
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});