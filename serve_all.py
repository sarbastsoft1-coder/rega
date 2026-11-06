import os
import sys
import time
import socket
import threading
import subprocess
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

class FlutterHandler(SimpleHTTPRequestHandler):
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
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def handle(self):
        try:
            super().handle()
        except Exception:
            pass

    def log_message(self, format, *args):
        try:
            sys.stderr.write("%s - - [%s] %s\n" %
                             (self.address_string(),
                              self.log_date_time_string(),
                              format % args))
            sys.stderr.flush()
        except Exception:
            pass

def is_port_in_use(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('127.0.0.1', port)) == 0

def make_handler_for_directory(directory):
    class CustomFlutterHandler(FlutterHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=directory, **kwargs)
    return CustomFlutterHandler

def start_server_thread(name, port, directory):
    while True:
        if is_port_in_use(port):
            time.sleep(10)
            continue

        try:
            ThreadingHTTPServer.allow_reuse_address = True
            handler = make_handler_for_directory(directory)
            server = ThreadingHTTPServer(('127.0.0.1', port), handler)
            print(f"[ONLINE] {name} serving on http://127.0.0.1:{port} from {directory}", flush=True)
            server.serve_forever()
        except Exception as e:
            time.sleep(10)

def start_backend_thread(base_dir):
    backend_dir = os.path.join(base_dir, "rega_backend")
    while True:
        if is_port_in_use(8001):
            time.sleep(10)
            continue
        try:
            print("[ONLINE] REGA Backend starting on http://127.0.0.1:8001 ...", flush=True)
            proc = subprocess.Popen(
                ["php", "artisan", "serve", "--port=8001", "--host=127.0.0.1"],
                cwd=backend_dir,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            while proc.poll() is None:
                time.sleep(5)
        except Exception as e:
            print(f"[ERROR] Backend error: {e}", flush=True)
            time.sleep(10)

def main():
    base_dir = r"c:\Users\sarba\OneDrive\Desktop\projekt rega"
    
    # 1. Start Laravel Backend Thread (Port 8001)
    backend_thread = threading.Thread(target=start_backend_thread, args=(base_dir,), daemon=True)
    backend_thread.start()

    # 2. Start Web Frontend Servers
    apps = [
        ("REGA Admin", 8080, os.path.join(base_dir, "rega_admin", "build", "web")),
        ("REGA Froshyar (Vendor)", 8081, os.path.join(base_dir, "rega_froshyar", "build", "web")),
        ("REGA Customer", 8082, os.path.join(base_dir, "rega", "build", "web")),
        ("REGA Delivery (Captain)", 8083, os.path.join(base_dir, "rega_delivery", "build", "web")),
    ]

    threads = [backend_thread]
    for name, port, directory in apps:
        t = threading.Thread(target=start_server_thread, args=(name, port, directory), daemon=True)
        t.start()
        threads.append(t)

    print("REGA Unified Ecosystem online and serving on all ports (8001, 8080, 8081, 8082, 8083).", flush=True)
    for t in threads:
        t.join()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
