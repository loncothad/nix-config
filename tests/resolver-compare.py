"""Compare public DoH services on the current network, without changing DNS."""
import base64
import json
import statistics
import struct
import time
import urllib.request

providers = {
    'Quad9 threat blocking': 'https://dns.quad9.net/dns-query',
    'Cloudflare unfiltered': 'https://cloudflare-dns.com/dns-query',
}
results = []
for provider, endpoint in providers.items():
    timings, responses, failures = [], [], []
    for name in ('example.com', 'ietf.org', 'nixos.org'):
        for kind in (1, 28):
            wire = struct.pack('!HHHHHH', 1, 0x0100, 1, 0, 0, 0)
            wire += b''.join(bytes([len(label)]) + label.encode() for label in name.split('.')) + b'\0'
            wire += struct.pack('!HH', kind, 1)
            request = urllib.request.Request(
                endpoint + '?dns=' + base64.urlsafe_b64encode(wire).decode().rstrip('='),
                headers={'Accept': 'application/dns-message'},
            )
            started = time.monotonic()
            try:
                with urllib.request.urlopen(request, timeout=8) as response:
                    payload = response.read()
                    assert response.headers.get_content_type() == 'application/dns-message'
                flags, _, count = struct.unpack('!HHH', payload[2:8])
                responses.append({'name': name, 'type': 'A' if kind == 1 else 'AAAA', 'rcode': flags & 15, 'answers': count})
                timings.append(round((time.monotonic() - started) * 1000, 1))
            except (OSError, ValueError, AssertionError, struct.error) as error:
                failures.append({'name': name, 'type': kind, 'error': type(error).__name__})
    results.append({
        'provider': provider,
        'successful_https_requests': len(timings),
        'median_https_request_ms': statistics.median(timings) if timings else None,
        'responses': responses,
        'failures': failures,
    })
print(json.dumps({'scope': 'Current network only; TLS verified. HTTPS connection/transport overhead included. No private-domain queries or configuration changes.', 'providers': results}, indent=2))
