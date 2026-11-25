#!/usr/bin/env python3
"""Sirve la build web en un origen fijo para probar la persistencia (P6).

Uso:
    flutter build web
    python3 tool/serve_web.py build/web 8080

Luego abre http://127.0.0.1:8080 en un perfil de Chrome. Sin las cabeceras
COOP/COEP, Drift usa IndexedDB; con ellas usaría OPFS. La app funciona en
ambos modos.

Solo usa la biblioteca estándar de Python 3.
"""
import functools
import http.server
import mimetypes
import os
import sys

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("text/javascript", ".js")

directorio = sys.argv[1] if len(sys.argv) > 1 else "build/web"
puerto = int(sys.argv[2]) if len(sys.argv) > 2 else 8080


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, formato, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), formato % args))


handler = functools.partial(Handler, directory=os.path.abspath(directorio))
servidor = http.server.ThreadingHTTPServer(("127.0.0.1", puerto), handler)
print(f"Sirviendo {directorio} en http://127.0.0.1:{puerto}")
servidor.serve_forever()
