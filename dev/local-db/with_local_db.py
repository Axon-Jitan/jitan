"""Run a command with the local disposable database's connection settings.

    python dev/local-db/with_local_db.py <command...>

Reads dev/local-db/.env (git-ignored) and exports, for that one process:
  JITAN_TEST_DB_*  for the server's integration tests
  JITAN_DB_*       for `dart run bin/server.dart`
Nothing is written to disk and no value is printed.
"""
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
env_file = os.path.join(here, '.env')
if not os.path.exists(env_file):
    sys.exit('dev/local-db/.env is missing: copy .env.example to .env first.')

values = {}
for line in open(env_file, encoding='utf-8'):
    line = line.strip()
    if line and not line.startswith('#') and '=' in line:
        key, value = line.split('=', 1)
        values[key.strip()] = value.strip()

settings = {
    'HOST': '127.0.0.1',
    'PORT': values.get('JITAN_LOCAL_DB_PORT', '3307'),
    'NAME': values['JITAN_LOCAL_DB_NAME'],
    'USER': values['JITAN_LOCAL_DB_USER'],
    'PASSWORD': values['JITAN_LOCAL_DB_PASSWORD'],
    # TLS, as in production (MySQL 8's default authentication requires it).
    'SECURE': 'true',
}
env = dict(os.environ)
for key, value in settings.items():
    env[f'JITAN_TEST_DB_{key}'] = value
    env[f'JITAN_DB_{key}'] = value

sys.exit(subprocess.call(sys.argv[1:], env=env, shell=(os.name == 'nt')))
