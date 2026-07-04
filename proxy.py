#!/usr/bin/env python3
"""Forward 127.0.0.1:18180 -> 207.244.247.64:18180/json_rpc for KDF native mode.
KDF sends Bitcoin RPC methods (listunspent, getbalance) that Fuego daemon doesn't support.
This proxy intercepts unsupported methods and returns empty results."""
import http.server, urllib.request, json

FUEGO_URL = 'http://207.244.247.64:18180/json_rpc'

# Bitcoin RPC methods that Fuego daemon doesn't support
UNSUPPORTED_METHODS = {
    'listunspent', 'getbalance', 'listtransactions',
    'gettransaction', 'sendtoaddress', 'createrawtransaction',
    'signrawtransaction', 'sendrawtransaction',
}

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length)

        try:
            req_body = json.loads(body)
            method = req_body.get('method', '')
            req_id = req_body.get('id', 0)
        except Exception:
            method = ''
            req_id = 0

        # Intercept unsupported methods
        if method in UNSUPPORTED_METHODS:
            if method == 'listunspent':
                resp = json.dumps({
                    'result': [],
                    'id': req_id,
                    'jsonrpc': '2.0'
                }).encode()
            elif method == 'getbalance':
                resp = json.dumps({
                    'result': '0.00000000',
                    'id': req_id,
                    'jsonrpc': '2.0'
                }).encode()
            elif method == 'listtransactions':
                resp = json.dumps({
                    'result': [],
                    'id': req_id,
                    'jsonrpc': '2.0'
                }).encode()
            else:
                resp = json.dumps({
                    'result': None,
                    'id': req_id,
                    'jsonrpc': '2.0'
                }).encode()

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(resp)
            return

        # Forward everything else to the real daemon
        req = urllib.request.Request(
            FUEGO_URL,
            data=body,
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = resp.read()
                self.send_response(resp.status)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(data)
        except Exception as e:
            self.send_response(502)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(str(e).encode())

    def log_message(self, format, *args):
        pass

print('Daemon proxy: 127.0.0.1:18180 -> 207.244.247.64:18180/json_rpc (intercepting Bitcoin RPCs)', flush=True)
http.server.HTTPServer(('127.0.0.1', 18180), ProxyHandler).serve_forever()
