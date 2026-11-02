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
        print("Usage: python serve_web.py <directory> <port>")
        sys.exit(1)
    
    directory = sys.argv[1]
    port = int(sys.argv[2])
    os.chdir(directory)

    server = ThreadingHTTPServer(('127.0.0.1', port), MultiThreadedFlutterHandler)
    print(f"Serving {directory} on http://127.0.0.1:{port} (Multi-Threaded)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    run()

