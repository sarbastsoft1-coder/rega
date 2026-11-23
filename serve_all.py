import os
import sys
import ssl
import time
import socket
import threading
import subprocess
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CERT_FILE = os.path.join(BASE_DIR, "certs", "localhost.pem")
KEY_FILE = os.path.join(BASE_DIR, "certs", "localhost-key.pem")
BACKEND_INTERNAL_PORT = 18001
BACKEND_PUBLIC_PORT = 8001


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
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

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


class BackendHttpsProxy(BaseHTTPRequestHandler):
    """HTTPS → plain PHP built-in server on 127.0.0.1:18001."""

    def _proxy(self):
        length = int(self.headers.get('Content-Length', 0) or 0)
        body = self.rfile.read(length) if length > 0 else None
        target = f"http://127.0.0.1:{BACKEND_INTERNAL_PORT}{self.path}"
        headers = {
            k: v for k, v in self.headers.items()
            if k.lower() not in ('host', 'content-length', 'transfer-encoding', 'connection')
        }
        headers['Host'] = f'127.0.0.1:{BACKEND_INTERNAL_PORT}'
        req = Request(target, data=body, headers=headers, method=self.command)
        try:
            with urlopen(req, timeout=120) as resp:
                data = resp.read()
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    lk = k.lower()
                    if lk in ('transfer-encoding', 'connection', 'content-encoding'):
                        continue
                    self.send_header(k, v)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE')
                self.send_header('Access-Control-Allow-Headers', '*')
                self.end_headers()
                self.wfile.write(data)
        except HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            if data:
                self.wfile.write(data)
        except URLError as e:
            self.send_response(502)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(f'Backend unavailable: {e}'.encode('utf-8'))

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()

    def do_GET(self):
        self._proxy()

    def do_POST(self):
        self._proxy()

    def do_PUT(self):
        self._proxy()

    def do_PATCH(self):
        self._proxy()

    def do_DELETE(self):
        self._proxy()

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


def make_ssl_context():
    if not (os.path.isfile(CERT_FILE) and os.path.isfile(KEY_FILE)):
        gen = os.path.join(BASE_DIR, "certs", "gen_local_cert.py")
        if os.path.isfile(gen):
            subprocess.check_call([sys.executable, gen])
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
    return ctx


def make_handler_for_directory(directory):
    class CustomFlutterHandler(FlutterHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=directory, **kwargs)
    return CustomFlutterHandler


def start_https_server_thread(name, port, directory, ssl_ctx):
    while True:
        if is_port_in_use(port):
            time.sleep(10)
            continue
        try:
            ThreadingHTTPServer.allow_reuse_address = True
            handler = make_handler_for_directory(directory)
            server = ThreadingHTTPServer(('0.0.0.0', port), handler)
            server.socket = ssl_ctx.wrap_socket(server.socket, server_side=True)
            print(f"[ONLINE] {name} serving on https://0.0.0.0:{port} from {directory}", flush=True)
            server.serve_forever()
        except Exception as e:
            print(f"[ERROR] {name}: {e}", flush=True)
            time.sleep(10)


def start_backend_https_proxy(ssl_ctx):
    while True:
        if is_port_in_use(BACKEND_PUBLIC_PORT):
            time.sleep(10)
            continue
        try:
            ThreadingHTTPServer.allow_reuse_address = True
            server = ThreadingHTTPServer(('0.0.0.0', BACKEND_PUBLIC_PORT), BackendHttpsProxy)
            server.socket = ssl_ctx.wrap_socket(server.socket, server_side=True)
            print(
                f"[ONLINE] REGA Backend HTTPS proxy on https://0.0.0.0:{BACKEND_PUBLIC_PORT} "
                f"→ http://127.0.0.1:{BACKEND_INTERNAL_PORT}",
                flush=True,
            )
            server.serve_forever()
        except Exception as e:
            print(f"[ERROR] Backend HTTPS proxy: {e}", flush=True)
            time.sleep(10)


def start_backend_php_thread():
    backend_dir = os.path.join(BASE_DIR, "rega_backend")
    while True:
        if is_port_in_use(BACKEND_INTERNAL_PORT):
            time.sleep(10)
            continue
        try:
            print(
                f"[ONLINE] REGA Backend PHP starting on http://127.0.0.1:{BACKEND_INTERNAL_PORT} ...",
                flush=True,
            )
            proc = subprocess.Popen(
                f"php -S 127.0.0.1:{BACKEND_INTERNAL_PORT} -t public public/router.php",
                cwd=backend_dir,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                shell=True,
            )
            while proc.poll() is None:
                time.sleep(5)
        except Exception as e:
            print(f"[ERROR] Backend error: {e}", flush=True)
            time.sleep(10)


def main():
    ssl_ctx = make_ssl_context()

    php_thread = threading.Thread(target=start_backend_php_thread, daemon=True)
    php_thread.start()

    proxy_thread = threading.Thread(
        target=start_backend_https_proxy, args=(ssl_ctx,), daemon=True
    )
    proxy_thread.start()

    apps = [
        ("REGA Admin", 8080, os.path.join(BASE_DIR, "rega_admin", "build", "web")),
        ("REGA Froshyar (Vendor)", 8081, os.path.join(BASE_DIR, "rega_froshyar", "build", "web")),
        ("REGA Customer", 8082, os.path.join(BASE_DIR, "rega", "build", "web")),
        ("REGA Delivery (Captain)", 8083, os.path.join(BASE_DIR, "rega_delivery", "build", "web")),
    ]

    threads = [php_thread, proxy_thread]
    for name, port, directory in apps:
        t = threading.Thread(
            target=start_https_server_thread,
            args=(name, port, directory, ssl_ctx),
            daemon=True,
        )
        t.start()
        threads.append(t)

    print(
        "REGA Unified Ecosystem online over HTTPS "
        "(8001, 8080, 8081, 8082, 8083). Accept the self-signed cert once in the browser.",
        flush=True,
    )
    for t in threads:
        t.join()


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
