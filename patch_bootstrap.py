import re
import sys
import os

paths = [
    "/var/www/rega/rega/build/web",
    "/var/www/rega/rega_froshyar/build/web",
    "/var/www/rega/rega_admin/build/web",
    "/var/www/rega/rega_delivery/build/web",
]

sw_code = """self.addEventListener("install", (e) => { self.skipWaiting(); });
self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.map((k) => caches.delete(k))))
      .then(() => self.registration.unregister())
      .then(() => self.clients.matchAll({ type: "window" }))
      .then((clients) => clients.forEach((c) => c.navigate(c.url)))
  );
});
"""

for base in paths:
    fb = os.path.join(base, "flutter_bootstrap.js")
    if os.path.exists(fb):
        with open(fb, "r", encoding="utf-8") as f:
            content = f.read()
        content = re.sub(
            r"serviceWorkerSettings:\s*\{[\s\S]*?\}",
            "serviceWorkerSettings: null",
            content,
        )
        content = content.replace(
            '"mainJsPath":"main.dart.js"',
            '"mainJsPath":"main.dart.js?v=" + Date.now()',
        )
        with open(fb, "w", encoding="utf-8") as f:
            f.write(content)
        print("Patched bootstrap:", fb)

    sw = os.path.join(base, "flutter_service_worker.js")
    with open(sw, "w", encoding="utf-8") as f:
        f.write(sw_code)
    print("Patched service worker:", sw)
