import os
import sys
import time
import socket
import threading
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
            # Port is actively being served (e.g. by user flutter run)
            time.sleep(30)
            continue

        try:
            ThreadingHTTPServer.allow_reuse_address = True
            handler = make_handler_for_directory(directory)
            server = ThreadingHTTPServer(('127.0.0.1', port), handler)
            print(f"[ONLINE] {name} serving on http://127.0.0.1:{port} from {directory}")
            server.serve_forever()
        except Exception as e:
            # If occupied or in TIME_WAIT, sleep and recheck peacefully
            time.sleep(30)

def main():
    base_dir = r"c:\Users\sarba\OneDrive\Desktop\projekt rega"
    apps = [
        ("REGA Admin", 8080, os.path.join(base_dir, "rega_admin", "build", "web")),
        ("REGA Froshyar (Vendor)", 8081, os.path.join(base_dir, "rega_froshyar", "build", "web")),
        ("REGA Customer", 8082, os.path.join(base_dir, "rega", "build", "web")),
        ("REGA Delivery (Captain)", 8083, os.path.join(base_dir, "rega_delivery", "build", "web")),
    ]

    threads = []
    for name, port, directory in apps:
        t = threading.Thread(target=start_server_thread, args=(name, port, directory), daemon=True)
        t.start()
        threads.append(t)

    print("REGA smart port manager started.")
    while True:
        time.sleep(60)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
