// Minimal service worker — its presence (registered, with a fetch handler)
// is part of Chrome's installability criteria for `beforeinstallprompt` to
// fire reliably. Deliberately not an offline-caching strategy; this app is
// backend/API-driven and stale cached responses would be worse than none.
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', () => {
  // Pass-through: let the browser handle every request normally.
});
