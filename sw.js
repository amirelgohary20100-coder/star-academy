const V="star-academy-v18";const FILES=["./","index.html","manifest.webmanifest","icon-192.png","icon-512.png"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()));});
/* keep caches named isl-* : they hold the downloaded Quran audio */
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V&&!k.startsWith("isl-")).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener("fetch",e=>{if(e.request.method!=="GET")return;const u=new URL(e.request.url);
  if(u.hostname==="cdn.islamic.network"){e.respondWith(caches.open("isl-audio-v2").then(c=>c.match(u.href).then(m=>m||fetch(e.request))));return;}
  if(u.origin!==location.origin)return;
  e.respondWith(fetch(e.request).then(r=>{const c=r.clone();if(r.ok)caches.open(V).then(x=>x.put(e.request,c));return r;}).catch(()=>caches.match(e.request).then(m=>m||(e.request.mode==="navigate"?caches.match("index.html"):Response.error()))));});
