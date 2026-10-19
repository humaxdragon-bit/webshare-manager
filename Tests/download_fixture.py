import http.server
import pathlib
import sys
import time

class Fixture(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Length', str(128 * 16384))
        self.end_headers()
        try:
            for _ in range(128):
                self.wfile.write(b'x' * 16384)
                self.wfile.flush()
                time.sleep(0.015)
        except (BrokenPipeError, ConnectionResetError):
            pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Fixture)
pathlib.Path(sys.argv[1]).write_text(str(server.server_port))
server.serve_forever()
