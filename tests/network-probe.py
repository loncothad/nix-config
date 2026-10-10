"""Network namespace probes; failures raise an error for the VM driver."""
import socket
import sys

mode, target, source = sys.argv[1:4]
family = socket.AF_INET6 if ':' in target else socket.AF_INET
if mode == 'ntp':
    connection = socket.socket(family, socket.SOCK_DGRAM)
    connection.settimeout(2)
    connection.bind((source, 0))
    connection.sendto(b'\x23' + bytes(47), (target, 123))
    assert len(connection.recv(512)) >= 48
elif mode == 'ssh':
    accepted = 0
    for _ in range(16):
        with socket.socket(family, socket.SOCK_STREAM) as connection:
            connection.settimeout(0.3)
            connection.bind((source, 0))
            try:
                connection.connect((target, 22))
                assert connection.recv(128).startswith(b'SSH-')
                accepted += 1
            except TimeoutError:
                pass
    assert 1 <= accepted <= 7, accepted
