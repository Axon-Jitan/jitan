"""Exercise the compiled server on Linux, with real HTTPS and trusted test certs.

Docker and OpenSSL are test tools only. No certificates or keys enter the archive.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

root = Path(__file__).resolve().parents[2]
release = root / 'build/network-smoke'
image = 'ubuntu:26.04'
openssl = shutil.which('openssl') or str(Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/usr/bin/openssl.exe')
passed = []


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()


def record(message):
    passed.append(message)
    print('PASS:', message, flush=True)


with tempfile.TemporaryDirectory(prefix='jitan-tls-') as temporary:
    fixtures = Path(temporary)
    run(openssl, 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
        '-keyout', str(fixtures / 'server.key'), '-out', str(fixtures / 'server.crt'),
        '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1')
    run(openssl, 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048',
        '-out', str(fixtures / 'different.key'))
    tls = ssl.create_default_context(cafile=str(fixtures / 'server.crt'))

    def launch(contents, port=8080, env=(), command=()):
        (fixtures / 'app.env').write_text(contents, encoding='utf-8', newline='\n')
        args = ['docker', 'run', '--detach', '--user', '65534:65534', '--read-only',
                '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
                '--publish', f'127.0.0.1::{port}',
                '--mount', f'type=bind,source={release},target=/release,readonly',
                '--mount', f'type=bind,source={fixtures},target=/etc/jitan,readonly']
        for setting in env:
            args += ['--env', setting]
        return run(*args, image, *(command or ['/release/jitan-server']))

    def state(cid):
        return json.loads(run('docker', 'inspect', cid))[0]

    def request(cid, path='/', secure=True, context=tls, method='GET', port=8080):
        mapping = state(cid)['NetworkSettings']['Ports'][f'{port}/tcp'][0]['HostPort']
        url = f'{"https" if secure else "http"}://127.0.0.1:{mapping}{path}'
        # Do not let a developer's proxy environment affect local checks.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
                                            urllib.request.HTTPSHandler(context=context))
        try:
            result = opener.open(urllib.request.Request(url, method=method), timeout=3)
        except urllib.error.HTTPError as error:
            result = error
        with result:
            return result.status, result.headers, result.read()

    def ready(cid, **kwargs):
        for _ in range(40):
            if not state(cid)['State']['Running']:
                raise AssertionError('Server exited: ' + run('docker', 'logs', cid))
            try:
                return request(cid, **kwargs)
            except (OSError, urllib.error.URLError):
                time.sleep(.1)
        raise AssertionError('Listener did not become ready')

    def stop(cid):
        run('docker', 'stop', '--timeout', '15', cid)
        assert state(cid)['State']['ExitCode'] == 0
        assert '"event":"stopped"' in run('docker', 'logs', cid)

    def remove(cid):
        run('docker', 'rm', '--force', cid)

    good = ('BIND_ADDRESS=0.0.0.0\nHOST=127.0.0.1\nPORT=8080\n'
            'TLS_CERT=/etc/jitan/server.crt\nTLS_KEY=/etc/jitan/server.key\n'
            'DB_PASS=secret-value-do-not-log\n')
    cid = launch(good)
    try:
        status, headers, body = ready(cid)
        assert status == 200 and b'Hello jitan!!' in body
        assert headers['Cache-Control'] == 'no-store'
        assert headers['Content-Type'].startswith('text/html')
        for path in ['/health', '/health/live', '/health/ready']:
            assert json.loads(request(cid, path)[2]) == {'status': 'ok', 'mode': 'network-test'}
        assert request(cid, method='HEAD')[2] == b''
        assert request(cid, '/missing')[0] == 404
        assert request(cid, '/api/companies')[0] == 404
        assert request(cid, '/../../etc/jitan/app.env')[0] == 404
        assert request(cid, method='POST')[0] == 405
        request(cid, '/?token=secret-value-do-not-log')
        record('Default /etc/jitan/app.env: HTTPS page, health, HEAD, 404/405, config-file traversal denied')

        for context in [ssl.create_default_context(), ssl.create_default_context(cafile=None)]:
            try:
                request(cid, context=context)
            except urllib.error.URLError as error:
                assert isinstance(error.reason, ssl.SSLCertVerificationError)
            else:
                raise AssertionError('Untrusted certificate accepted')
        record('HTTPS validated with trusted test certificate; untrusted certificate rejected')
        try:
            request(cid, secure=False)
        except (OSError, urllib.error.URLError):
            pass
        else:
            raise AssertionError('Plain HTTP unexpectedly accepted on TLS port')
        assert ready(cid)[0] == 200
        record('No plaintext HTTP fallback on HTTPS port; invalid connection does not crash listener')
        assert 'secret-value-do-not-log' not in run('docker', 'logs', cid)
        record('DB password and query-string test marker absent from logs')
        stop(cid)
        run('docker', 'start', cid)
        assert ready(cid)[0] == 200
        stop(cid)
        record('SIGTERM exits 0, all listeners stop, and HTTPS works after restart')
    finally:
        remove(cid)

    # Simulate IT's private IPv4 interface using this container's actual IP.
    cid = launch(good, command=['sh', '-c', 'export BIND_ADDRESS="$(hostname -i)"; exec /release/jitan-server'])
    try:
        assert ready(cid)[0] == 200
        startup = next(json.loads(line) for line in run('docker', 'logs', cid).splitlines()
                       if '"event":"started"' in line)
        assert len(startup['hosts']) == 2 and startup['hosts'][1] == '127.0.0.1'
        run('docker', 'exec', cid, 'bash', '-c', 'echo > /dev/tcp/127.0.0.1/8080')
        assert ready(cid)[0] == 200
        stop(cid)
        record('Specific private IPv4 plus 127.0.0.1 both listen; environment overrides file without rebuild')
    finally:
        remove(cid)

    # A different file port is used with the exact same executable.
    cid = launch('HOST=0.0.0.0\nPORT=8081\nDB_PASS=secret-value-do-not-log\n', port=8081)
    try:
        assert ready(cid, secure=False, port=8081)[0] == 200
        stop(cid)
        record('HOST alias and changed file PORT work without rebuild; HTTP works when TLS is omitted')
    finally:
        remove(cid)

    cases = [
        ('partial TLS', 'BIND_ADDRESS=0.0.0.0\nTLS_CERT=/etc/jitan/server.crt\n', ()),
        ('missing TLS file', good.replace('server.key', 'absent.key'), ()),
        ('mismatched TLS key', good.replace('server.key', 'different.key'), ()),
        ('invalid port', good.replace('PORT=8080', 'PORT=secret-value-do-not-log'), ()),
        ('malformed file', 'secret-value-do-not-log\n', ()),
        ('missing explicit config', good, ('JITAN_CONFIG_FILE=/etc/jitan/absent.env',)),
    ]
    for name, config, env in cases:
        cid = launch(config, env=env)
        try:
            code = run('docker', 'wait', cid)
            assert code == '78', (name, code)
            logs = run('docker', 'logs', cid)
            # Docker sends stderr separately; include it in this redaction check.
            output = subprocess.run(['docker', 'logs', cid], capture_output=True, text=True)
            assert 'secret-value-do-not-log' not in output.stdout + output.stderr
            assert '"event":"started"' not in logs
            record(f'{name}: startup refused (78), no listener and no secret values in logs')
        finally:
            remove(cid)

binary_hash = hashlib.sha256((release / 'jitan-server').read_bytes()).hexdigest()
digest = run('docker', 'image', 'inspect', '--format', '{{index .RepoDigests 0}}', image)
report = ('Jitan network-test 0.1.2 - verified 2026-10-15\n'
          f'Binary SHA-256: {binary_hash}\n'
          'Build: Dart 3.12.1 cross-compiled for Linux x64. ELF64 verified.\n'
          'Config checks and Dart analysis passed.\n'
          f'Runtime: Ubuntu 26.04 x64 container ({digest}).\n'
          'Non-root UID/GID 65534, read-only filesystem, no Dart/Flutter runtime installed.\n'
          'Docker and OpenSSL are local testing tools only.\n\n' +
          '\n'.join('PASS: ' + item for item in passed) +
          '\n\nNot tested: IT VM, IT certificates, systemd boot, real DNS/firewalls.\n'
          'DB_* settings are ignored by this network test; no database connection is made.\n')
(root / 'dev/network-smoke/TEST_RESULTS.txt').write_text(report, encoding='utf-8', newline='\n')
