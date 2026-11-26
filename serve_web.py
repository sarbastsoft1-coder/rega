import sys
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

API_BACKEND_ORIGIN = os.environ.get("REGA_LOCAL_API", "http://127.0.0.1:8001")

class MultiThreadedFlutterHandler(SimpleHTTPRequestHandler):
    extensions_map = SimpleHTTPRequestHandler.extensions_map.copy()
    extensions_map.update({
        '.wasm': 'application/wasm',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.otf': 'font/otf',
        '.ttf': 'font/ttf',
        '.woff2': 'font/woff2',
    })

    def end_headers(self):
        # Allow cross-origin and disable stale aggressive caching on localhost / LAN
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def _is_api_or_storage(self):
        p = self.path.split('?', 1)[0]
        return p.startswith('/api/') or p == '/api' or p.startswith('/storage/')

    def _proxy_to_backend(self):
        length = int(self.headers.get('Content-Length', 0) or 0)
        body = self.rfile.read(length) if length > 0 else None
        target = f"{API_BACKEND_ORIGIN}{self.path}"
        headers = {
            k: v for k, v in self.headers.items()
            if k.lower() not in ('host', 'content-length', 'transfer-encoding', 'connection')
        }
        req = Request(target, data=body, headers=headers, method=self.command)
        try:
            with urlopen(req, timeout=120) as resp:
                data = resp.read()
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    if k.lower() in ('transfer-encoding', 'connection', 'content-encoding', 'access-control-allow-origin'):
                        continue
                    self.send_header(k, v)
                self.end_headers()
                self.wfile.write(data)
        except HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            self.send_header('Content-Type', e.headers.get('Content-Type', 'application/json'))
            self.end_headers()
            if data:
                self.wfile.write(data)
        except URLError as e:
            self.send_response(502)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()
            self.wfile.write(f'{{"message":"Backend unavailable: {e}"}}'.encode('utf-8'))

    def do_GET(self):
        if self._is_api_or_storage():
            return self._proxy_to_backend()
        clean_path = self.path.split('?', 1)[0].split('#', 1)[0]
        fs_path = self.translate_path(clean_path)
        if not os.path.exists(fs_path) and '.' not in os.path.basename(clean_path):
            self.path = '/index.html'
        return super().do_GET()

    def do_POST(self):
        if self._is_api_or_storage():
            return self._proxy_to_backend()
        self.send_error(405, "Method Not Allowed")

    def do_PUT(self):
        if self._is_api_or_storage():
            return self._proxy_to_backend()
        self.send_error(405, "Method Not Allowed")

    def do_PATCH(self):
        if self._is_api_or_storage():
            return self._proxy_to_backend()
        self.send_error(405, "Method Not Allowed")

    def do_DELETE(self):
        if self._is_api_or_storage():
            return self._proxy_to_backend()
        self.send_error(405, "Method Not Allowed")

def run():
    if len(sys.argv) < 3:
        print("Usage: python serve_web.py <directory> <port> [host]")
        sys.exit(1)

    directory = sys.argv[1]
    port = int(sys.argv[2])
    # Bind all interfaces so iPhone/Android on same Wi-Fi can open the app.
    host = sys.argv[3] if len(sys.argv) > 3 else '0.0.0.0'
    os.chdir(directory)

    ThreadingHTTPServer.allow_reuse_address = True
    server = ThreadingHTTPServer((host, port), MultiThreadedFlutterHandler)
    print(f"Serving {directory} on http://{host}:{port} (Multi-Threaded, phone-ready)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    run()
