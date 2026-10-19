"""Build the isolated Linux smoke test; never bundle repository config/secrets."""
import hashlib
import io
from pathlib import Path
import shutil
import subprocess
import tarfile
import sys

source = Path(__file__).resolve().parent
root = source.parent.parent
name = 'jitan-network-test-0.1.2-linux-x64'
out = root / 'build' / 'network-smoke'
out.mkdir(parents=True, exist_ok=True)
binary = out / 'jitan-server'
dart = shutil.which('dart')
if dart is None:
    raise SystemExit('Dart SDK is required on the build machine.')
if '--package-only' not in sys.argv:
    subprocess.run([dart, 'compile', 'exe', '--target-os=linux', '--target-arch=x64',
                    str(source / 'server.dart'), '-o', str(binary)], check=True, cwd=root)

# Never infer Linux format from a filename or successful host compilation.
data = binary.read_bytes()
if data[:6] != b'\x7fELF\x02\x01' or int.from_bytes(data[18:20], 'little') != 62:
    raise SystemExit('Expected a little-endian ELF64 x86-64 executable.')

binary_hash = hashlib.sha256(data).hexdigest()
results = (source / 'TEST_RESULTS.txt').read_text(encoding='utf-8')
if binary_hash not in results:
    results = ('Runtime validation pending for this binary.\n'
               f'Binary SHA-256: {binary_hash}\n')
files = {
    'bin/jitan-server': data,
    'config/app.env.example': (source / 'app.env.example').read_bytes(),
    'systemd/jitan.service': (source / 'jitan.service').read_bytes(),
    'README.md': (source / 'README.md').read_bytes(),
    'TEST_RESULTS.txt': results.encode('utf-8'),
}
files['SHA256SUMS'] = ''.join(
    f'{hashlib.sha256(content).hexdigest()}  {path}\n'
    for path, content in sorted(files.items())
).encode()
archive = out / f'{name}.tar.gz'
with tarfile.open(archive, 'w:gz') as tar:
    for path, content in sorted(files.items()):
        info = tarfile.TarInfo(f'{name}/{path}')
        info.size = len(content)
        info.mode = 0o755 if path.startswith('bin/') else 0o644
        tar.addfile(info, io.BytesIO(content))
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix(archive.suffix + '.sha256').write_text(
    f'{checksum}  {archive.name}\n', encoding='ascii')
print(f'Built: {archive}\nSHA-256: {checksum}')
