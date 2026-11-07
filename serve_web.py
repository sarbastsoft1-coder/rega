import sys
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

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
        # Allow cross-origin and disable stale aggressive caching on localhost
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

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
