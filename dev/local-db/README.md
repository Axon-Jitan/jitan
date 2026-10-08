# Local development database (temporary, disposable)

A local MySQL with the Jitan ERD, so onboarding, sign-in and recovery can be tested end
to end before IT provides the real development database. **Not** the IT database; when
that arrives, point the same settings at it and rerun the same tests.

| File | What |
|---|---|
| `schema.sql` | Every table, column, key and unique pair of `docs/database/ERD.jpg`. Nothing else |
| `seed.sql` | Fake companies and employees for the current flows (below) |
| `docker-compose.yml` | MySQL 8.4 on `127.0.0.1` only; loads schema + seed on first start |
| `.env.example` | Connection settings; copy to `.env` (git-ignored) |
| `with_local_db.py` | Runs a command with `JITAN_DB_*` / `JITAN_TEST_DB_*` set from `.env` |
| `e2e_api_check.py` | ONB-07 end-to-end check over HTTP, with database assertions |

## Use

```sh
cd dev/local-db
cp .env.example .env              # then set your own local passwords
docker compose up -d              # first start loads schema.sql + seed.sql
docker compose down -v            # throw away; the next "up" starts fresh

# Server integration tests against it (none skipped)
cd server/jitan_api
python ../../dev/local-db/with_local_db.py dart test

# API in development mode (HR user 1 as development identity)
JITAN_ENV=development JITAN_DEV_USER_ID=1 JITAN_CORS_ORIGINS=http://localhost:5000 \
  python ../../dev/local-db/with_local_db.py dart run bin/server.dart

# End-to-end over HTTP (re-seed first: it changes data)
python dev/local-db/e2e_api_check.py

# End-to-end in the Android emulator (re-seed first)
cd apps/employee_mobile
flutter test integration_test -d emulator-5554 --dart-define=JITAN_API_BASE_URL=http://10.0.2.2:8080
```

The connection uses TLS (`JITAN_DB_SECURE=true`), as production will: MySQL 8's default
authentication requires it, and the container's certificate is self-signed.

## Seed

| ID | Who | Company | State | Local password |
|---|---|---|---|---|
| 1 | Hanne Claes (HCL) | Almeco, PCA | HR, activated | `Hanne-Local-Dev-1` |
| 2 | Disan Ssebowa (SBW) | Almeco | active, **not activated** (`userPassword` NULL) | – |
| 3 | Kevin De Vos (KDV) | Almeco | active, activated, language nl | `Kevin-Local-Dev-1` |
| 4 | Fabian Peeters (FPT) | Almeco | **inactive**, activated | `Fabian-Local-Dev-1` |
| 5 | Sara Maes (SMA) | Almeco | **MFD**, activated | `Sara-Local-Dev-1` |
| 6 | Thomas Vermeulen (TVM) | PCA only | active, not activated | – |

Plus: groups White/Blue collar, credential groups Employee/HR/Admin, languages en/nl/fr/de,
a few Dutch translations, and audit event types named like the code (`AuditEventType`).
The `userQRcode` values are the permanent **Terminal** QRs (random); the end-to-end tests
use them only to check that they never onboard or recover. Onboarding and recovery use
temporary QRs generated through the API. Passwords are
Argon2id hashes made with Jitan's own `PasswordHasher`; they exist only here.

## Differences from the IT development database (to check when it arrives)

1. **Physical types.** The ERD gives logical types only. Here: `INT`, `VARCHAR(255)`,
   `BOOLEAN` (TINYINT(1)), `DATETIME`, `DOUBLE`, utf8mb4. The real database may differ;
   Jitan needs `userPassword` ≥ 97 characters (Argon2id) and reads booleans as
   TINYINT or BIT. `schema_contract_test` checks names, not types.
2. **NULL and defaults.** Here every non-key column is NULL-able without a default, so
   Jitan must set what it relies on. If IT's columns are `NOT NULL` without defaults,
   inserts that leave a column out (e.g. `userEmail`, `userPINCode` on create) will fail.
3. **Unique pair on `tblTranslation` (languageID + translationUIName).** Verified in
   ERD.jpg: both columns are shaded as one yellow block, and the legend defines yellow as
   "in same table, Unique Pair" (a composite constraint, not two single-column UKs).
   Enforced here and covered by integration tests (same key twice in one language is
   refused; same key in other languages and different keys in one language are allowed).
   Against IT's database those tests show whether it is enforced there too; if not, Jitan
   still handles duplicates (lowest `translationID` wins, logged; CLARIFY-08).
4. **Event type rows.** Here they carry Jitan's code names. IT's real names may differ
   (CLARIFY-11): then either IT adds these rows or the code adopts IT's names.
5. **Credential groups, modules, functions.** Seeded only by name. Authorization still uses
   the development evaluator (CLARIFY-10/11).
6. **Foreign keys.** Enforced here for every ERD relation (including all `tblEventLog`
   references). If IT's database lacks some, nothing in Jitan relies on cascades.
7. **TLS and accounts.** Here a local user with a self-signed certificate. IT's server will
   have its own users, privileges (Jitan needs SELECT/INSERT/UPDATE; tests also DELETE their
   `[DEV-TEST]` fixtures) and certificate.
8. **Time zone.** The container runs in UTC.
