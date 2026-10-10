"""Offline DoH, endpoint bootstrap, and split-DNS fixture for the NixOS test."""
import base64
import http.server
import ipaddress
import pathlib
import socket
import socketserver
import ssl
import struct
import threading
import urllib.parse

ROOT = pathlib.Path('/run/dns-fixture')


def answer(query, transport):
    offset, labels = 12, []
    while query[offset]:
        length = query[offset]
        labels.append(query[offset + 1:offset + length + 1].decode())
        offset += length + 1
    name = '.'.join(labels)
    qtype = struct.unpack('!H', query[offset + 1:offset + 3])[0]
    question = query[12:offset + 5]
    with (ROOT / (transport + '.log')).open('a') as log:
        log.write(name + '\n')
    if name in ('endpoint.test', 'wrong-host.test', 'cloudflare-dns.com'):
        ip = '127.0.0.2' if qtype == 1 else None
    elif name == 'endpoint6.test':
        ip = '::1' if qtype == 28 else None
    else:
        ip = ('198.51.100.44' if transport == 'plain' else '198.51.100.7') if qtype == 1 else '2001:db8::7' if qtype == 28 else None
    header = query[:2] + struct.pack('!HHHHH', 0x8180, 1, int(ip is not None), 0, 0)
    record = b''
    if ip is not None:
        packed = ipaddress.ip_address(ip).packed
        record = b'\xc0\x0c' + struct.pack('!HHIH', qtype, 1, 0, len(packed)) + packed
    return header + question + record


class UDP(socketserver.DatagramRequestHandler):
    def handle(self):
        self.wfile.write(answer(self.rfile.read(), 'plain'))


class TCP(socketserver.StreamRequestHandler):
    def handle(self):
        size = struct.unpack('!H', self.rfile.read(2))[0]
        response = answer(self.rfile.read(size), 'plain')
        self.wfile.write(struct.pack('!H', len(response)) + response)


class HTTPS(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        encoded = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)['dns'][0]
        self.respond(base64.urlsafe_b64decode(encoded + '=' * (-len(encoded) % 4)))

    def do_POST(self):
        self.respond(self.rfile.read(int(self.headers['Content-Length'])))

    def respond(self, query):
        with (ROOT / 'paths.log').open('a') as log:
            log.write(urllib.parse.urlsplit(self.path).path + '\n')
        response = answer(query, 'doh')
        self.send_response(200)
        self.send_header('Content-Type', 'application/dns-message')
        self.send_header('Content-Length', str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, *_):
        pass


class HTTP6(http.server.ThreadingHTTPServer):
    address_family = socket.AF_INET6


for kind in (socketserver.ThreadingUDPServer, socketserver.ThreadingTCPServer):
    kind.allow_reuse_address = True
    service = kind(('127.0.0.2', 53), UDP if kind == socketserver.ThreadingUDPServer else TCP)
    threading.Thread(target=service.serve_forever, daemon=True).start()

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(ROOT / 'cert.pem', ROOT / 'key.pem')
for address, kind in [(('127.0.0.2', 8443), http.server.ThreadingHTTPServer), (('::1', 8443), HTTP6)]:
    service = kind(address, HTTPS)
    service.socket = context.wrap_socket(service.socket, server_side=True)
    threading.Thread(target=service.serve_forever, daemon=True).start()
threading.Event().wait()
