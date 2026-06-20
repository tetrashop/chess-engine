self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open('chess-v1').then((cache) => {
      return cache.addAll([
        '/',
        '/style.css',
        '/script.js',
        '/manifest.json'
      ]);
    })
  );
});
self.addEventListener('fetch', (e) => {
  e.respondWith(
    caches.match(e.request).then((resp) => resp || fetch(e.request))
  );
});
