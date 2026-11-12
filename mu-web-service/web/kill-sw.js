// Bản web không dùng Service Worker (nó cache cứng index.pck/wasm -> người chơi không nhận được bản cập nhật).
// Trình duyệt nào đã đăng ký SW cũ sẽ tải file này thay cho index.service.worker.js, tự xoá cache rồi huỷ đăng ký.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    try { for (const k of await caches.keys()) await caches.delete(k); } catch (_) {}
    try { await self.registration.unregister(); } catch (_) {}
    try { for (const c of await self.clients.matchAll({ type: 'window' })) c.navigate(c.url); } catch (_) {}
  })());
});
