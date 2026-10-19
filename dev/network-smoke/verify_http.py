"""Read-only HTTP smoke checks: python verify_http.py http://host:port"""
import json
import sys
import urllib.error
import urllib.request

base = sys.argv[1].rstrip('/')

def fetch(path, method='GET'):
    try:
        response = urllib.request.urlopen(
            urllib.request.Request(base + path, method=method), timeout=5)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return response.status, response.headers, response.read()

status, headers, body = fetch('/')
assert status == 200 and b'Hello jitan!!' in body
assert headers['Content-Type'].startswith('text/html')
assert headers['Cache-Control'] == 'no-store'
assert headers['X-Content-Type-Options'] == 'nosniff'
print('PASS: embedded page, HTML content type, cache/security headers')
for path in ('/health', '/health/live', '/health/ready'):
    status, headers, body = fetch(path)
    assert status == 200 and json.loads(body) == {'status': 'ok', 'mode': 'network-test'}
    assert headers['Content-Type'].startswith('application/json')
    print(f'PASS: {path}')
assert fetch('/', 'HEAD')[2] == b''
assert fetch('/', 'HEAD')[0] == 200
assert fetch('/missing')[0] == 404
assert fetch('/api/companies')[0] == 404
assert fetch('/../etc/passwd')[0] == 404
assert fetch('/', 'POST')[0] == 405
assert fetch('/', 'POST')[1]['Allow'] == 'GET, HEAD'
assert fetch('/?token=smoke-test-do-not-log')[0] == 200
print('PASS: HEAD, missing routes, no API impersonation, traversal, method handling')
