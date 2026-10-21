# Backlog: Named Follow-up Tasks

Work that is defined and agreed but not yet done. Blockers that need someone else's
answer live elsewhere: ERD/IT questions in [database/ERD_GAPS.md](database/ERD_GAPS.md),
product questions in [PRODUCT_CLARIFICATIONS.md](PRODUCT_CLARIFICATIONS.md).

Status values: `TODO` · `IN PROGRESS` · `DONE (commit)`

## EMP-DETAILS-V2: Details from a table row (version 2) · `TODO`

**Decided 2026-10-21 (product owner):** in V1 no HR/Admin table opens details when HR
clicks a row; that comes in V2, with its Figma frames.

- **Employees:** the Employee details dialog (`employee_details_dialog.dart`, with the
  temporary onboarding/recovery QR and Reset account access) is built and tested but has
  **no way in**. Until V2 or a designed entry point, HR cannot generate an onboarding QR
  or reset access from the web app. **Needs a product decision before employees are
  onboarded.**
- **Employee groups:** the group page is reached only right after Create group (and from
  "Manage employees →" in Cannot deactivate group). Adding employees or changing hours
  later needs a way in.

## GRP-01: Employee groups managed by HR/Admin

Status: `IN PROGRESS` · decided 2026-10-20 · roadmap phase 2 · **server done** (`GET /groups/overview`, `POST /groups`, `PUT /groups/{id}`, `POST /groups/{id}/deactivate|reactivate`, `GroupManagementApi`); screen waits for the Figma frame

Today groups (`tblGroup`) exist only as database rows (seed, IT's script); HR can pick them
but not create them. Schedules are set per group, so HR needs to manage groups.

- [x] List groups (active and inactive) with their number of employees.
- [x] Add a group: name required, at most 100 characters (`groupName`), unique ignoring
      case (the ERD has no unique key, so Jitan checks).
- [x] Rename a group: same checks; employees and schedules stay attached.
- [x] Deactivate a group only when no current employee is in it ("Move the 12 employees in
      Drivers to another group first"); soft delete, the row stays. Reactivate allowed.
- [x] Every change audited in `tblEventLog` (`groupID`), event types added to
      `reference_data.sql`.
- [ ] HR/Admin screen from the designer's frame, next to Schedules.

## DEPLOY-01: Adopt IT's server configuration contract

Status: `TODO` · agreement recorded 2026-10-16 · roadmap phase 12

Follow [DEPLOYMENT_CONFIGURATION.md](DEPLOYMENT_CONFIGURATION.md) for the full API.
The network-test 0.1.2 implementation (`dev/network-smoke/`) is a reference, not
completed API integration. IT runs it on their Ubuntu 26.04 VM (service up, listeners on
`127.0.0.1:8080` and the VM address, "Hello jitan!!" in a browser). The public domain
`jitan.axongroup.com` still showed nginx's default page at the last check: its reverse
proxy is not yet confirmed to forward to Jitan.

- [x] Load `/etc/jitan/app.env` with an optional `JITAN_CONFIG_FILE` override
      (2026-10-20, `config/config_sources.dart`; strict parser in `config/env_file.dart`).
- [x] Support `BIND_ADDRESS` / `HOST`, `PORT` and direct HTTPS via `TLS_CERT` / `TLS_KEY`;
      retain legacy aliases and documented precedence, including localhost binding
      (`config/listener_config.dart`, `bin/server.dart`).
- [x] Map IT's `DB_*` names to existing database settings; preserve production guards,
      session-secret requirements and verified MySQL TLS (separate from HTTPS keys; see
      SEC-01).
- [x] Add fail-closed configuration/TLS tests, graceful systemd shutdown (SIGTERM) and log
      redaction (no setting values in parser errors). `/health/live` and `/health/ready`
      added as aliases of `/health` and `/health/database`.
- [ ] Preserve IT's executable-only update procedure: same `jitan-server` path/service,
      external config and certificates; stop, back up, replace, start and verify.
- [ ] Embed compiled web assets for executable-only replacement; agree any alternative
      asset update procedure with IT. Verify client HTTPS/API configuration without secrets.
- [ ] Verify on the target Linux environment, including systemd restart, certificate
      permissions, staging database connectivity, and client integration.

Packaging work does not resolve the separate authentication/authorization dependencies.

**Commits:** each completed task is its own reviewable commit. History is pushed as-is,
never squashed.

---

## I18N-01: Translation infrastructure
Status: `IN PROGRESS`: built and tested in code; **verification against the real
database is pending** (DB-VERIFY-01). Required before any UI is production-ready.

### Rules

- **English is the guaranteed built-in default language.** Its texts live in **one
  central place**, `builtInEnglish` in `packages/jitan_core`. Every app can render its
  complete English interface with no API, database or network.
- **Other languages are database-driven**: `tblLanguage`, `tblTranslation`,
  `tblUserLanguage`. The database is the source of truth for every non-English language.
  English may exist in `tblLanguage` if the database needs it, but the apps never depend
  on, or read, a database copy of English.
- **Screens never contain copy.** `Text(context.t(AdminTextKeys.companyTitle))`, never
  `Text('Companies')`. Keys are constants in `CommonTextKeys` (shared) or
  `<App>TextKeys`.
- Keys describe **meaning, not copy**: `company.add`, `common.save`,
  `onboarding.language.title`. Not `Add company`.
- No JSON/ARB translation files. JSON is only the API transport format.
- **Rendering never waits for translations.** Apps start in built-in English and switch
  when the user's database bundle arrives.

### Resolution order (per key)

```text
1. selected language is English          → built-in English
2. other language: database bundle       → its text
3.   missing in that bundle              → built-in English
4.   bundle unavailable (offline, API or
     database down, unknown language)    → built-in English
5. missing even in built-in English      → the key itself, logged once
```

User language: `tblUserLanguage`. None assigned or not signed in → English. Several
assigned → English, logged as a data error (CLARIFY-07). **If the user language cannot be
fetched but is already in the in-memory cache, the cached language is used** instead of
English, and apps render their first frame in it when it is cached
(`TranslationService.cachedForCurrentUser`). Signing out (401) or `clearCache()`
forgets it.

### Loading

```text
tblLanguage → tblTranslation → Dart API → TranslationService → in-memory cache → UI
                                                    ↑ fallback
                                           built-in English (always present)
```

- Whole bundles, never key by key: `GET /translations?language=<code>`.
- Loaded at app start, session start and language change. Each language is fetched once
  per session and cached in memory. A cached bundle keeps working if the API later goes
  down.
- `GET /languages` lists the active languages (for a language picker);
  `GET /me/language` gives the signed-in user's language.

### Scope

- [x] Central built-in English bundle (`builtInEnglish`, jitan_core)
- [x] Translation key API for the UI: `context.t()` / `context.tPlural()` under a
      `TranslationScope` (jitan_ui), keys in `CommonTextKeys` / `AdminTextKeys`
- [x] Server: active languages from `tblLanguage`, bundles from `tblTranslation`, user
      language from `tblUserLanguage`, with unit and DB integration tests
- [x] English as default; English fallback for missing keys and for any load failure
- [x] In-memory cache of non-English bundles; language switching
- [x] Cached user language preferred over English when the API is unreachable, and
      used for the first frame when available
- [x] Missing keys shown as the key and logged once
- [x] Tests for every fallback path (jitan_core), the app starting in English and
      switching to a database language (admin_web), and offline/API-down startup
- [x] A test that fails when a key used in code has no built-in English text, and one
      that fails when a screen passes a literal string to `t()`
- [x] Company list, shell and error states migrated
- [x] Dev seed: optional `[DEV] Pseudo` language (`--pseudo-language`) to see the database
      path working; English is not seeded (it is built in)
- [ ] Verify against the real dev database (DB-VERIFY-01)
- [ ] Persist the last loaded bundle on the device, so a non-English language survives an
      offline app restart. Needed for the mobile app and the Terminal; today the cache is
      in memory, so an offline restart shows English. Optional per the rule ("may").
- [ ] A language switcher in the UI: none is designed for HR/Admin yet; the Employee app's
      onboarding has one (roadmap §11)

### Open points

- **Key convention vs. existing rows.** Development continues with the current key
  convention (`company.title`). At DB-VERIFY-01: inspect the real `tblTranslation` rows,
  compare their key style, report differences. Never modify the ERD or silently rewrite
  production translation data.
- **Production content:** PRODUCT-CLARIFY-TRANSLATION-MAINTENANCE.
- **Persistent offline cache** for non-English languages: later, for Employee Mobile and
  Terminal. Does not block development.
- **Plural rules.** Plural keys use `.one` / `.other`, which fits English and Dutch;
  French (0 is singular) and others need richer keys when added.
- CLARIFY-07 (one language per user?) and CLARIFY-08 (duplicate keys per language).

---

## DB-VERIFY-01: Verify everything built so far against the real dev database
Status: `IN PROGRESS` · access to IT's development database verified 2026-10-09 ·
**does not block development**

- [x] Access: credentials received (kept outside the repository), MySQL 8.4 over TLS
- [x] Verify every mapped column against the real schema (2026-10-09, from IT's
      `information_schema` export, never committed): same 30 tables, columns and keys;
      every column the code uses exists. Differences found and fixed: Active/MFD on all 11
      junction tables (now filtered everywhere), NOT NULL columns and lengths (validated
      before insert), fixtures that IT's schema rejects. `dev/local-db/schema.sql` now
      mirrors IT's schema, and every integration test passes against it.
- [ ] Verify the server's TLS certificate before the API or any test connects to IT's
      database (SEC-01)
- [ ] The 2026-10-12 `ERD.jpg` adds `tblConfigType`, `tblConfiguration`,
      `tblUserConfiguration` and three `tblEventLog` FKs that IT's database did not have
      on 2026-10-09: ask IT when they are created, then export again and regenerate
      `dev/local-db/schema.sql`
- [ ] Run the read-only `schema_contract_test` against IT's database. The other integration
      tests insert and delete `[DEV-TEST]` fixtures: they run only on the local database
      unless IT agrees otherwise
- [ ] Inspect the actual reference rows of `tblGroup`, `tblCredGroup`, `tblAppModules`,
      `tblFunction`, `tblScheduleType`, `tblTimeRegType`, `tblEventType`, `tblLanguage`,
      `tblTranslation` and report how they compare with the code's assumptions (the first
      lookup export was empty; CLARIFY-11)
- [ ] With IT's agreement only: `dart run tool/dev_seed.dart` if the database lacks useful
      data, then run the API and the Admin web app against it
- [ ] Report any mismatch. **Never change the fixed ERD to make code or tests pass**;
      fix the code, or raise an ERD gap.

---

## SEC-01: Production security review before deployment
Status: `TODO` · does not block development (decision 2026-10-13: keep building features;
this is the pre-production checklist) · **item 1 is due the day the API first connects to
IT's database**, items 2–3 before production

- [x] **Database TLS certificate verification** (2026-10-20, `database/database_tls.dart`).
      mysql_client_plus 0.1.3 accepts any certificate by default, so the API always passes
      its own check: `JITAN_DB_TLS_FINGERPRINTS` (SHA-256, comma-separated) or
      `JITAN_DB_TLS_CA_FILE`. Production refuses to start without one. The TLS layer checks
      every certificate in the chain it can't verify, so MySQL's auto-generated pair needs
      **both** fingerprints, the CA's and the server certificate's (verified against the
      local MySQL: the pair connects; either one alone, or a wrong one, is refused). The CA
      file only works with a certificate issued for the database's address (MySQL's
      auto-generated one names no host).
- [ ] **IT's two fingerprints.** We have the server certificate's (`70:26:23:…`). Get the
      CA's too, e.g. from IT's `/var/lib/mysql/ca.pem` (`openssl x509 -in ca.pem -noout
      -fingerprint -sha256`), confirm both with IT, and put both in `/etc/jitan/app.env`.
      Or IT issues a certificate with the database address in its SAN and gives us its CA.
- [x] **Production refuses `JITAN_DB_SECURE=false`** (2026-10-20, `app_config.dart`).
- [ ] **Least privilege** for the API's database account (SELECT/INSERT/UPDATE; IT's
      development account also has DELETE/CREATE/DROP/ALTER).
- [ ] **Sign-in rate limiting / lockout** (`POST /auth/sign-in`, ONB-04 for onboarding and
      recovery). Failed sign-ins are not audited; decide whether they should be, with no
      password or code value logged.
- [x] ~~Company-level access.~~ **Not needed for V1** (product decision 2026-10-13): HR has
      access to all companies, like Admin, so `GET /companies` returning every non-deleted
      company is correct. Revisit if a role limited to some companies is added later.

## DB-DRIVER-01: mysql_client_plus drops the connection on a SELECT error
Status: `OPEN` · worked around

mysql_client_plus 0.1.3 cannot parse an error packet sent in answer to a `SELECT` ("Wrong
first byte 0xff, while decoding getVariableEncInt"): a locking read that MySQL rejects
(e.g. deadlock victim) kills the connection instead of raising error 1213. Errors on
`INSERT`/`UPDATE` are parsed fine. Workaround in place: every assignment transaction takes
the employee's `tblUser` row lock as its **first** statement (a transaction with no locks
cannot be a deadlock victim) and then uses plain reads; no locking reads with joins. Fix
or replace the driver before production (also see the transaction-pool leak worked
around in `Database.transaction`).
Also because of this, assignment transactions don't lock group rows: a group schedule
saved at the same moment as an employee joins the group may leave that employee on the
previous rows until the group's next save (TIME_ENGINE_ANALYSIS D2d). Revisit with the driver.

## QR-TEMP: Temporary onboarding and recovery QRs
Status: `DONE` (2026-10-08, IT decision) · production multi-instance store pending IT

Signed 10-minute single-use QR tokens (`TemporaryQrTokens`, HMAC-SHA256) with one-time
state in `TemporaryTokenStore` (in memory; never MySQL). HR/Admin: Generate temporary QR
(`…/onboarding-qr`, Figma `153:1214`) and, after Reset account access, the recovery QR
(`…/recovery-qr`, `207:111`), with countdown, expiry and regeneration. Employee app:
onboarding and Sign in → Recover account accept only these QRs (`/onboarding/*`,
`/recovery/*`), with the expired / used / wrong-purpose states (Auth/06C). The permanent
`userQRcode` is the Terminal QR only. Completion is claim → MySQL → consume; the same
device can finish an interrupted completion with the same password.

## Employee management

Order agreed 2026-10-07. Employee Onboarding follows immediately after.

| Task | Scope | Status |
|---|---|---|
| EMP-01 | Employee list for the current company: search, Type from `tblGroup`, all states, responsive, translation keys. Location shows "—" (GAP-11), Onboarding shows Activated / Not activated since ONB-03a, Policy omitted | `DONE` |
| EMP-02 | Add employee: first/last name, code, type (`tblGroup`), phone, in the current company; one transaction incl. audit; duplicate-code and validation errors on their fields. Location and Work policy omitted | `DONE` |
| EMP-03 | Employee details modal from a row click: type, phone, status; Location/Account "—", Work policy omitted | `DONE` |
| EMP-04 | Company assignment (`tblUserCompany`): Employee details → Manage assignments → Companies (Figma `201:472`, `207:292`). **Several companies per employee** (IT, 2026-10-08). Add (audited `employee.company.assigned`, needs `manageEmployeeAssignments` in both companies) and **remove** with confirmation (Figma `207:329`): soft delete `userCompanyActive = 0, userCompanyMFD = 1`, row kept and hidden, audited `employee.company.removed`; re-adding reactivates the same row. The company in the path is not removable in its own context, so one membership always remains | `DONE` |
| EMP-05 | Group assignment (`tblUserGroup`): Manage assignments → Groups (Figma `201:572`, `207:406`). Universal groups (IT, 2026-10-08), no company selector. Add (audited `employee.group.assigned`) and **remove** with confirmation (Figma `207:441`): soft delete `userGroupActive = 0, userGroupMFD = 1`, audited `employee.group.removed`; re-adding reactivates the row. Groups grant no company access | `DONE` |
| EMP-06 | Preferred language (`tblUserLanguage`): Manage assignments → Language (Figma `201:673`) and `PUT /me/language` for the employee. One language per user, updated in place under a user-row lock (concurrent changes never leave two rows); generic audit `employee.language.changed` (GAP-12 accepted). Employee app screen awaits design (DESIGN-CLARIFY-PROFILE-LANGUAGE) | `DONE` |
| EMP-07 | Credential-group assignment (`tblUserCredGroup`): Manage assignments → Access (Figma `201:778`). Names and levels from `tblCredGroup`, no role names in code. Adds only (CLARIFY-09), duplicates skipped, audited (`employee.credential_group.assigned`). Permission `manageEmployeeAccess` in **every** company of the employee (a credential group is user-wide). **No privilege escalation**: until IT defines the hierarchy (CLARIFY-10), an actor may grant only credential groups they hold themselves; anything else is 403 and not offered in the picker. This holds even with the dev evaluator, so nobody can raise their own access | `DONE` |
| EMP-08 | Onboarding QR from Employee details: shows `tblUser.userQRcode` as a scannable QR (stores a random one once if missing, audited); no-store, never logged or shown as text. **Superseded by QR-TEMP (2026-10-08):** onboarding uses a temporary QR; `userQRcode` is the Terminal QR only | `DONE`, superseded |
| EMP-09 | Bulk import (Figma "Import CSV / Excel", roadmap §8): upload → preview → validate → import | `TODO` |

## TR-01: Read-only time-registration foundation
Status: `DONE` (2026-10-08) · the time engine itself waits for GAP-01, GAP-02, CLARIFY-02

The raw `tblTimeReg` stream, read-only, for the HR/Admin Time Records screen and the
employee's history (staged: their screens come later).

- `GET /companies/{id}/employees/{userId}/time-registrations` (permission
  `viewTimeRegistrations` in that company; the employee must belong to it, since
  `tblTimeReg` has no company) and `GET /me/time-registrations` (own data).
- Only `timeRegActive = 1 AND timeRegMFD = 0`; required `from` (inclusive) / `to`
  (exclusive) as wall-clock values **without** timezone (GAP-02: refused with an offset,
  never converted); oldest first by timestamp then id; `limit` 1–500 (default 100) and an
  opaque keyset `cursor`, stable across equal timestamps.
- Returned as stored: wall-clock timestamp, `tblTimeRegType` id and name with no meaning
  attached (CLARIFY-02), address name, `timeRegManualEntry` (`null` stays unknown),
  comment, `timeRegWhenModified`.
- Shared models `TimeRegistration` / `TimeRegistrationPage` (jitan_models), client
  `TimeRegistrationsApi` (jitan_api_client); unit, client and MySQL integration tests.

Not built, on purpose: rounding, work sessions (no derived session is presented as a
record), and any writing or correcting of registrations.

## Employee onboarding

| Task | Scope | Status |
|---|---|---|
| ONB-01 | Server: `POST /onboarding/start` resolves a scanned `userQRcode` (**superseded by QR-TEMP:** it now resolves a temporary onboarding QR; `userQRcode` never onboards); `POST /onboarding/complete` sets the mandatory password (Argon2id since ONB-05), which completes onboarding; **re-onboarding guard** (`userPassword IS NOT NULL` → 409), row-locked and race-safe; audited; `OnboardingApi` client ready for ONB-02 | `DONE` |
| ONB-04 | Rate limiting on the public onboarding **and sign-in** endpoints. Sign-in is the important one: an employee code is not secret, so only Argon2id's cost slows password guessing today. Needs a decision on lockout vs. throttling (no ERD field for failed attempts) | `TODO` |
| ONB-05 | Argon2id password hashing (off the event loop, PHC format, benchmark tool `tool/bench_argon2.dart`); onboarding completion stores the password and language in one transaction and returns a session token for the device (no second sign-in); bearer-token middleware (active + password-fingerprint check on every request); `GET /me`; `ApiTransport.accessToken`, `MeApi` | `DONE` |
| ONB-06 | Persisted trusted devices and per-device revocation: blocked on **GAP-05** (no device/session table). Until then the device id lives only in the stateless token | `BLOCKED` |
| AUTH-01 | Mobile sign-in and recovery (Figma Auth / 01–07): `POST /auth/sign-in`, generic failures; Forgot password → Recover with QR (only after HR/Admin reset, then Set new password → Home); Profile → Password & web login → Change password (`POST /me/password`); Sign out; HR/Admin "Reset account access" in Employee details (`reset-access`, audited); returning devices open sign-in; 06B Recovery refused; Change password with current password; onboarding 06B Language after permissions | `DONE` |
| AUTH-03 | Employee Web / 07B Change password: **designed and backend-ready** (`POST /me/password`, current password verified, tested). Implementation deferred to the Employee Web roadmap task, built as one coherent app from the approved Figma (Login, QR login when GAP-05 allows, Home, Period, My QR, Profile, Password & web login, Change password, Notifications, Registration method, Privacy, Sign out). No partial Employee Web app before then | `DEFERRED` |
| AUTH-02 | HR/Admin and Employee Web sign-in screens (Figma "Employee Web / 01 Login") on the same endpoint; then remove the development identity from production paths | `TODO` |
| ONB-02 | Employee app `apps/employee_mobile` (Android first): welcome → scan → confirm → registration method → permissions → language (06B) → set password → ready → home, signed in by onboarding (token in secure storage, device id per install); all Figma error states incl. session recovery. Widget- and unit-tested against a simulated API, and run end to end on the Android emulator (ONB-07) | `DONE` |
| ONB-07 | End-to-end on the Android emulator against a **local disposable MySQL** with the ERD (`dev/local-db`): all server integration tests (none skipped), `e2e_api_check.py` (44 HTTP + database checks) and `integration_test/onb07_e2e_test.dart` (real app on the emulator: onboarding → Home, sign-in, inactive/MFD refusal, HR reset, QR recovery, repeated recovery refused) pass. Found and fixed: failed transactions leaked pool connections. **Remaining:** rerun against IT's database when available; scan a real QR with the camera (automation injects the value); iOS Podfile permission macros and first iOS build | `DONE` (local DB) |
| ONB-03a | HR side: Activated / Not activated in the list's Onboarding column, the details Account field and the Onboarding card; activated employees' QR shown as the personal Terminal QR | `DONE` |
| ONB-03b | HR side: live "Employee activated" confirmation while the QR modal is open (Figma `153:532`); needs polling or push | `TODO` |
