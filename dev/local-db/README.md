# Local development database (temporary, disposable)

A local MySQL with the Jitan ERD, so onboarding, sign-in and recovery can be tested end
to end before IT provides the real development database. **Not** the IT database; when
that arrives, point the same settings at it and rerun the same tests.

| File | What |
|---|---|
| `schema.sql` | IT's development database as exported on 2026-10-09: every table, column, type, length, NULL/default, key and unique pair. Nothing else |
| `seed.sql` | Fake companies and employees for the current flows (below) |
| `proposals/gap15_group_schedule.sql` | **Proposal, not in IT's database:** `tblGroupSchedule` and `tblEventLog.groupScheduleID` (ERD_GAPS GAP-15), sent to IT on 2026-10-21. Local only; changed or deleted when IT answers. To add it to an existing local database: `docker exec -i jitan-local-db-mysql-1 sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < proposals/gap15_group_schedule.sql` |
| `proposals/projects_terminals_visitors.sql` | **Proposal, not in IT's database:** projects, terminals, visitors ([PROPOSED_TABLES.md](../../docs/database/PROPOSED_TABLES.md)). Run once, after `schema.sql` |
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

## Differences from the IT development database

`schema.sql` was generated from IT's `information_schema` export of 2026-10-09 (the
exports themselves are never committed). The structure is the same: tables, columns,
types and lengths, NOT NULL and defaults, primary/unique/foreign keys and constraint
names, including Active/MFD on all 11 junction tables. What still differs:

1. **Character set and collation.** Not in the export; `utf8mb4_0900_ai_ci` is assumed.
2. **Data.** Here only the `[DEV]` seed below. IT's lookup rows (credential groups, event
   types, languages) are not known yet (CLARIFY-11): if IT's event type names differ from
   the code's (`AuditEventType`), either IT adds these rows or the code adopts IT's names.
3. **TLS and accounts.** Here a local user with a self-signed certificate. IT's server has
   its own account, privileges and certificate; Jitan needs SELECT/INSERT/UPDATE (the
   integration tests also DELETE their `[DEV-TEST]` fixtures, so they never run there).
4. **Time zone.** The container runs in UTC.

When IT changes its schema, export it again and regenerate `schema.sql`; never add
anything here that IT's database does not have.
