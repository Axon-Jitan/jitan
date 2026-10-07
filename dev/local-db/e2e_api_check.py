"""ONB-07 end-to-end check of onboarding, sign-in and recovery over HTTP.

Needs: the local database freshly seeded (docker compose down -v && up -d),
and the API running in development mode with JITAN_DEV_USER_ID=1 (Hanne,
HR) against it. Checks database state through the container.

    python dev/local-db/e2e_api_check.py [http://127.0.0.1:8080]

Changes the data (onboards Disan, resets and recovers Kevin): re-seed
before running again. Prints only pass/fail lines, never a password, token
or hash.
"""
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

BASE = (sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8080').rstrip('/')
HERE = os.path.dirname(os.path.abspath(__file__))

# Seed fixtures (seed.sql)
QR = {
    'disan': '5xYTglqwzf36v9UidULWYleBWfwt7Cjp',
    'kevin': 'MvrbloqIf-j151FU_94120bzpkqi4K6o',
    'fabian': 'arLmzMjwoiD_9wfeXpfKFaZ9vs_jExUp',
    'sara': 'ZYOtI-VXnKNJB7-4yl0Ow5sMukkdzpYk',
}
DEVICE_A = 'e2e-device-AAAAAAAAAAAAAAAA'
DEVICE_B = 'e2e-device-BBBBBBBBBBBBBBBB'

failures = []


def check(name, condition):
    print(('PASS  ' if condition else 'FAIL  ') + name)
    if not condition:
        failures.append(name)


def call(method, path, body=None, token=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(BASE + path, data=data, method=method)
    request.add_header('content-type', 'application/json')
    if token:
        request.add_header('authorization', 'Bearer ' + token)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            return response.status, (json.loads(raw) if raw else None), dict(response.headers)
    except urllib.error.HTTPError as error:
        raw = error.read()
        return error.code, (json.loads(raw) if raw else None), dict(error.headers)


def sql(query):
    env = {}
    for line in open(os.path.join(HERE, '.env'), encoding='utf-8'):
        if '=' in line and not line.startswith('#'):
            key, value = line.strip().split('=', 1)
            env[key] = value
    out = subprocess.run(
        ['docker', 'compose', 'exec', '-T', '-e', 'MYSQL_PWD=' + env['JITAN_LOCAL_DB_PASSWORD'], 'mysql',
         'mysql', '-N', '-B', '-u' + env['JITAN_LOCAL_DB_USER'], env['JITAN_LOCAL_DB_NAME'], '-e', query],
        cwd=HERE, capture_output=True, text=True, check=True)
    return [line.split('\t') for line in out.stdout.strip().splitlines()]


def error_code(body):
    return (body or {}).get('error', {}).get('code')


print(f'API {BASE}')
status, body, _ = call('GET', '/health/database')
check('API and database reachable', status == 200)

# ── 1. Onboarding: Disan (active, userPassword NULL) ─────────────────────
status, body, headers = call('POST', '/onboarding/start', {'qrCode': QR['disan']})
check('onboarding start: Disan found (QR exists, active, not MFD, no password)',
      status == 200 and body['code'] == 'SBW' and body['companies'] == ['Almeco'])
check('onboarding start response is not cached', headers.get('cache-control') == 'no-store')

status, body, _ = call('POST', '/onboarding/complete', {
    'qrCode': QR['disan'], 'password': 'Disan-Local-Dev-1', 'deviceId': DEVICE_A, 'languageCode': 'nl'})
disan_token = (body or {}).get('session', {}).get('accessToken')
check('onboarding complete returns a session (no second sign-in)', status == 200 and bool(disan_token))
check('session works for GET /me', call('GET', '/me', token=disan_token)[0] == 200)
row = sql("SELECT LEFT(userPassword, 16), userQRcode FROM tblUser WHERE userCode = 'SBW'")[0]
check('password stored as Argon2id hash', row[0] == '$argon2id$v=19$m')
check('QR unchanged after onboarding', row[1] == QR['disan'])
check('language preference stored (nl)', sql(
    "SELECT l.languageCode FROM tblUserLanguage ul JOIN tblLanguage l ON l.languageID = ul.languageID "
    "JOIN tblUser u ON u.userID = ul.userID WHERE u.userCode = 'SBW'") == [['nl']])
check('onboarding audited with its event type', sql(
    "SELECT t.eventTypeName FROM tblEventLog e JOIN tblEventLogEventType x ON x.eventLogID = e.eventLogID "
    "JOIN tblEventType t ON t.eventTypeID = x.eventTypeID WHERE e.userIDTarget = 2") == [['employee.onboarding.completed']])
status, body, _ = call('POST', '/onboarding/start', {'qrCode': QR['disan']})
check('same QR cannot restart onboarding (409)', status == 409 and error_code(body) == 'onboarding_already_completed')
status, body, _ = call('POST', '/onboarding/start', {'qrCode': 'not-a-jitan-qr'})
check('unknown QR: generic invalid_qr_code', status == 404 and error_code(body) == 'invalid_qr_code')

# ── 2. Normal sign-in ────────────────────────────────────────────────────
status, body, _ = call('POST', '/auth/sign-in', {'code': 'KDV', 'password': 'Kevin-Local-Dev-1', 'deviceId': DEVICE_A})
kevin_token = (body or {}).get('session', {}).get('accessToken')
check('Kevin signs in with code + password', status == 200 and bool(kevin_token))
status_b, body_b, _ = call('POST', '/auth/sign-in', {'code': 'KDV', 'password': 'Kevin-Local-Dev-1', 'deviceId': DEVICE_B})
kevin_token_b = (body_b or {}).get('session', {}).get('accessToken')
check('Kevin signs in on a second device', status_b == 200 and bool(kevin_token_b))
wrong = call('POST', '/auth/sign-in', {'code': 'KDV', 'password': 'wrong password', 'deviceId': DEVICE_A})
unknown = call('POST', '/auth/sign-in', {'code': 'NOBODY', 'password': 'wrong password', 'deviceId': DEVICE_A})
check('wrong password and unknown code are identical 401 invalid_credentials',
      wrong[0] == unknown[0] == 401 and wrong[1] == unknown[1] and error_code(wrong[1]) == 'invalid_credentials')

# ── 3. Inactive / MFD refusal ────────────────────────────────────────────
for who, code, password in [('Fabian (inactive)', 'FPT', 'Fabian-Local-Dev-1'), ('Sara (MFD)', 'SMA', 'Sara-Local-Dev-1')]:
    status, body, _ = call('POST', '/auth/sign-in', {'code': code, 'password': password, 'deviceId': DEVICE_A})
    check(f'{who}: correct password -> 403 account_inactive', status == 403 and error_code(body) == 'account_inactive')
    status, body, _ = call('POST', '/auth/sign-in', {'code': code, 'password': 'wrong password', 'deviceId': DEVICE_A})
    check(f'{who}: wrong password -> generic 401', status == 401 and error_code(body) == 'invalid_credentials')
for who in ('fabian', 'sara'):
    status, body, _ = call('POST', '/onboarding/start', {'qrCode': QR[who]})
    check(f'{who} QR refused for onboarding/recovery (403)', status == 403 and error_code(body) == 'account_inactive')

# ── Company scoping ──────────────────────────────────────────────────────
_, almeco, _ = call('GET', '/companies/1/employees')
_, pca, _ = call('GET', '/companies/2/employees')
check('Almeco list excludes Thomas (PCA only)', 'TVM' not in [e['code'] for e in almeco['employees']])
check('PCA list has Thomas', 'TVM' in [e['code'] for e in pca['employees']])
status, _, _ = call('POST', '/companies/2/employees/3/reset-access')
check('reset outside the employee\'s company -> 404', status == 404)
status, body, _ = call('POST', '/companies/2/employees/6/reset-access')
check('reset of a not-activated employee -> 409 account_not_activated',
      status == 409 and error_code(body) == 'account_not_activated')

# ── 4. HR/Admin Reset account access (Kevin) ─────────────────────────────
qr_before = sql("SELECT userQRcode FROM tblUser WHERE userID = 3")[0][0]
status, _, _ = call('POST', '/companies/1/employees/3/reset-access')
check('HR/Admin resets Kevin\'s access (204)', status == 204)
row = sql("SELECT userPassword IS NULL, userQRcode FROM tblUser WHERE userID = 3")[0]
check('reset: userPassword = NULL', row[0] == '1')
check('reset: userQRcode unchanged', row[1] == qr_before == QR['kevin'])
check('reset audited (employee.access.reset, actor HR, target Kevin, company Almeco)', sql(
    "SELECT e.userIDInit, e.companyID FROM tblEventLog e JOIN tblEventLogEventType x ON x.eventLogID = e.eventLogID "
    "JOIN tblEventType t ON t.eventTypeID = x.eventTypeID "
    "WHERE e.userIDTarget = 3 AND t.eventTypeName = 'employee.access.reset'") == [['1', '1']])
check('reset revokes both of Kevin\'s sessions',
      call('GET', '/me', token=kevin_token)[0] == 401 and call('GET', '/me', token=kevin_token_b)[0] == 401)
check('Disan\'s session is unaffected', call('GET', '/me', token=disan_token)[0] == 200)
status, body, _ = call('POST', '/auth/sign-in', {'code': 'KDV', 'password': 'Kevin-Local-Dev-1', 'deviceId': DEVICE_A})
check('old password no longer signs in', status == 401)

# ── 5. QR recovery after reset ───────────────────────────────────────────
status, body, _ = call('POST', '/onboarding/start', {'qrCode': QR['kevin']})
check('same QR identifies Kevin for recovery', status == 200 and body['code'] == 'KDV')
status, body, _ = call('POST', '/onboarding/complete', {
    'qrCode': QR['kevin'], 'password': 'Kevin-Recovered-2', 'deviceId': DEVICE_A})
kevin_new = (body or {}).get('session', {}).get('accessToken')
check('recovery sets the new password and returns a fresh session', status == 200 and bool(kevin_new))
check('fresh session works', call('GET', '/me', token=kevin_new)[0] == 200)
check('new password stored as Argon2id',
      sql("SELECT LEFT(userPassword, 10) FROM tblUser WHERE userID = 3")[0][0] == '$argon2id$')
check('language preference kept through recovery', sql(
    "SELECT l.languageCode FROM tblUserLanguage ul JOIN tblLanguage l ON l.languageID = ul.languageID "
    "WHERE ul.userID = 3") == [['nl']])
check('QR still unchanged after recovery', sql("SELECT userQRcode FROM tblUser WHERE userID = 3")[0][0] == QR['kevin'])
status, body, _ = call('POST', '/onboarding/start', {'qrCode': QR['kevin']})
check('repeated recovery refused once the password is set again (409)',
      status == 409 and error_code(body) == 'onboarding_already_completed')
status, _, _ = call('POST', '/auth/sign-in', {'code': 'KDV', 'password': 'Kevin-Recovered-2', 'deviceId': DEVICE_B})
check('Kevin signs in with the recovered password', status == 200)

# ── 6. Change password (current password verified) ───────────────────────
status, body, _ = call('POST', '/me/password', {'currentPassword': 'not mine', 'newPassword': 'Kevin-Changed-3'},
                       token=kevin_new)
check('change password: wrong current password -> 400 on currentPassword',
      status == 400 and (body or {}).get('error', {}).get('field') == 'currentPassword')
status, body, _ = call('POST', '/me/password', {'currentPassword': 'Kevin-Recovered-2', 'newPassword': 'Kevin-Changed-3'},
                       token=kevin_new)
kevin_changed = (body or {}).get('session', {}).get('accessToken')
check('change password succeeds and returns a new session', status == 200 and bool(kevin_changed))
check('this device stays signed in (new token)', call('GET', '/me', token=kevin_changed)[0] == 200)
check('previous sessions end', call('GET', '/me', token=kevin_new)[0] == 401)
check('password change audited', sql(
    "SELECT COUNT(*) FROM tblEventLog e JOIN tblEventLogEventType x ON x.eventLogID = e.eventLogID "
    "JOIN tblEventType t ON t.eventTypeID = x.eventTypeID "
    "WHERE e.userIDTarget = 3 AND t.eventTypeName = 'employee.password.changed'") == [['1']])

print()
print(f'{len(failures)} failure(s)' if failures else 'ALL CHECKS PASSED')
sys.exit(1 if failures else 0)
