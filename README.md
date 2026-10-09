# Jitan

Workforce time registration. **Time tracking without the tracking.**

Rules and context: [CLAUDE.md](CLAUDE.md) · [docs/ENGINEERING_RULES.md](docs/ENGINEERING_RULES.md) ·
[docs/ROADMAP.md](docs/ROADMAP.md) · [docs/database/ERD.md](docs/database/ERD.md)

## Repository

Dart pub workspace (one lockfile at the root).

```text
apps/admin_web            HR/Admin web app (Flutter web)
apps/employee_mobile      Employee app (Flutter, Android first, then iOS)
packages/jitan_models     shared API/domain models (pure Dart)
packages/jitan_api_client typed API client for all Flutter apps (pure Dart)
packages/jitan_core       shared client logic, e.g. the translation service (pure Dart)
packages/jitan_ui         design system from Figma: tokens, theme, components (Flutter)
server/jitan_api          Dart API, the only component that talks to MySQL
```

Not created yet, added with their first slice: `apps/employee_web`, `apps/terminal`.

Requirements: Flutter 3.44+ (Dart 3.12+). Docker only for the optional local database
([dev/local-db](dev/local-db/README.md)), used until IT's development database exists.

```sh
flutter pub get        # at the repo root; resolves every package
dart analyze           # whole workspace
```

## Run the API (development)

```sh
cd server/jitan_api
cp .env.example .env   # fill in the dev database; never commit .env
dart run bin/server.dart
```

- `GET /health`: process is up (no database needed)
- `GET /health/database`: `SELECT 1` against MySQL (503 when unreachable)
- `GET /languages`, `GET /translations?language=<code>`: UI text from `tblTranslation`
  (no sign-in needed, so the login screen can be translated)
- `GET /me/language`, `PUT /me/language`: the signed-in user's language
  (`tblUserLanguage`, one current row)
- `POST /onboarding/start`, `POST /onboarding/complete`: employee onboarding with a
  **temporary onboarding QR** (no sign-in; the QR is the credential: signed, 10 minutes,
  single use, never stored in MySQL; refused once a password is set). Completing sets the
  mandatory password and returns a session token for that device
- `POST /recovery/start`, `POST /recovery/complete`: password recovery with a
  **temporary recovery QR**, after Reset account access; returns a fresh session
- `GET /me`: the signed-in employee (`Authorization: Bearer <token>`)
- `POST /auth/sign-in`: employee code + password → session for this device (generic
  `invalid_credentials` on failure)
- `POST /me/password`: a signed-in employee changes the password (current password
  verified server-side); returns a new session
  for this device, all other sessions end
- `POST /companies/{id}/employees/{userId}/reset-access`: HR/Admin "Reset account access"
  (clears the password, keeps the Terminal QR, ends every session; 204)
- `GET /companies?search=`: company list (needs an identity, see below)
- `GET /companies/{id}/employees?search=`: that company's employees
- `POST /companies/{id}/employees`: create an employee in that company
- `GET /companies/{id}/employees/{userId}`: one employee's details (404 outside that company)
- `POST /companies/{id}/employees/{userId}/onboarding-qr` and `…/recovery-qr`: a new
  temporary QR (`{qrCode, purpose, expiresAt}`, `no-store`); the previous one stops working.
  The permanent `userQRcode` is the Terminal QR only and is never shown here
- `GET /groups`: assignable employee groups (the "Employee type")
- `…/employees/{userId}/assignments/companies|groups|language|credential-groups`
  (GET, plus POST to add, `DELETE …/companies/{id}` and `…/groups/{id}` to remove, PUT for
  the language): HR/Admin "Manage employee assignments". Removal is a soft delete
- `GET /companies/{id}/employees/{userId}/time-registrations` and
  `GET /me/time-registrations` (`from`, `to`, `limit`, `cursor`): the read-only
  `tblTimeReg` stream (staged; no app screen yet)

An id in a path that is not a known row, including one too large for an integer, is 404.

**Sessions.** `Authorization: Bearer <token>` with a token from onboarding. Set
`JITAN_SESSION_SECRET` (32+ characters, required in production; in development a random
one is generated per start, so tokens don't survive a restart) and optionally
`JITAN_SESSION_LIFETIME_DAYS` (default 30). Password hashing is Argon2id; tune it with
`JITAN_ARGON2_MEMORY_KIB`, `JITAN_ARGON2_ITERATIONS`, `JITAN_ARGON2_PARALLELISM` after
measuring on the server with `tool/bench_argon2.dart` (compile it for realistic numbers).

**Development identity.** Sign-in for HR/Admin isn't built yet. With `JITAN_ENV=development`, set
`JITAN_DEV_USER_ID` to an active `tblUser.userID`; every request then acts as that user. A
dev-only permission evaluator allows everything. With `JITAN_ENV=production` (also the
default when unset) the server **refuses to start** if any `JITAN_DEV_*` variable is set,
and every protected route answers 401/403 until real auth and permissions exist.

**Translations.** English is built into the apps (`builtInEnglish` in `jitan_core`) and
always works, even with no API or database. Other languages come from `tblTranslation`;
missing texts fall back to English.

**Development data.** To fill an empty dev database with `[DEV]` companies and users:

```sh
cd server/jitan_api
dart run tool/dev_seed.dart                   # [DEV] companies, users, groups; prints the
                                              # userID to use as JITAN_DEV_USER_ID
dart run tool/dev_seed.dart --pseudo-language # also: a fake "[DEV] Pseudo" database language
                                              # (texts in ⟦…⟧) assigned to the dev user
dart run tool/dev_seed.dart --remove          # deletes everything the seed created
```

Refuses to run outside `development`/`test`.

## Run the HR/Admin web app

```sh
cd apps/admin_web
flutter run -d chrome --web-port 5000 \
  --dart-define=JITAN_API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=JITAN_DEV_TOOLS=true
```

`JITAN_DEV_TOOLS=true` (development only) shows the **current company selector** above every
page. Company-scoped pages such as Employees need a current company, and the production
company switcher is not designed yet. Leave it out of production builds.

`JITAN_API_BASE_URL` is required. Without it the app shows a configuration error instead
of guessing. The API must list the web origin in `JITAN_CORS_ORIGINS`
(`.env.example` has `http://localhost:5000`).

## Run the Employee app

Needs the Android SDK (or Xcode for iOS) and a device or emulator. Android setup without
Android Studio: JDK 17, the SDK command-line tools **19.0** (later versions replace
`sdkmanager`), then `sdkmanager "platform-tools" "platforms;android-36"
"platforms;android-37.0" "build-tools;36.0.0" "ndk;28.2.13676358"`, and
`flutter config --android-sdk <sdk> --jdk-dir <jdk>`. The app compiles against API 37
(required by `permission_handler_android`), hence AGP 9.1.1 and Gradle 9.3.1.

```sh
cd apps/employee_mobile
flutter run --dart-define=JITAN_API_BASE_URL=http://10.0.2.2:8080   # Android emulator → host
```

`JITAN_API_BASE_URL` is required (absolute URL). Debug builds may use plain `http://`
(development only, `android/app/src/debug/AndroidManifest.xml`); release builds need
HTTPS. To onboard, open an employee in the HR/Admin app, choose **Generate temporary QR**
and scan it with the app within 10 minutes. Completing onboarding signs the device in; the session token is kept in
the platform's secure storage.

iOS: `permission_handler` needs its permission macros (`PERMISSION_CAMERA`,
`PERMISSION_LOCATION_WHENINUSE`, `PERMISSION_NOTIFICATIONS`) in the Podfile, added with
the first iOS build.

## Tests

```sh
cd packages/jitan_models     && dart test
cd packages/jitan_api_client && dart test
cd packages/jitan_core       && dart test
cd server/jitan_api          && dart test
cd packages/jitan_ui         && flutter test
cd apps/admin_web            && flutter test
cd apps/employee_mobile      && flutter test
```

Server **integration tests** (`test/integration/`) run against a real dev/test MySQL and are
skipped until one is configured. The local database runs them all:
`python ../../dev/local-db/with_local_db.py dart test` in `server/jitan_api`. Set `JITAN_TEST_DB_HOST`, `JITAN_TEST_DB_NAME`,
`JITAN_TEST_DB_USER`, `JITAN_TEST_DB_PASSWORD` (or put them in a git-ignored
`server/jitan_api/.env.test`). They verify every column the repositories use exists with
the exact ERD spelling (and every junction table's Active/MFD), then run the real SQL on
`[DEV-TEST]` fixtures that they remove afterwards. **Never point them at production**, and
not at IT's development database either without IT's agreement: they insert and delete
rows. The local database's schema mirrors IT's (`dev/local-db/schema.sql`).
