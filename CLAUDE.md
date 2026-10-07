# Jitan

Workforce time-registration platform. **Time tracking without the tracking.**

Guiding principle: **If Jitan already knows, don't ask the worker.** Every design decision
should reduce manual registration, not add to it.

**The engineering rules below are mandatory for all implementation work.** They are
imported here so every session loads them:

@docs/ENGINEERING_RULES.md

| Doc | Read it when |
|---|---|
| [docs/ENGINEERING_RULES.md](docs/ENGINEERING_RULES.md) | Always: imported above. Includes the Definition of Done (§34) |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Before starting any feature: product scope and build order |
| [docs/database/ERD.md](docs/database/ERD.md) | Before writing any model, query, repository or endpoint: what every table means |
| [docs/database/ERD.jpg](docs/database/ERD.jpg) | Authoritative structure. Wins over ERD.md if they disagree |
| [docs/database/ERD_GAPS.md](docs/database/ERD_GAPS.md) | Before building anything the roadmap wants but the ERD may not hold. Also holds IT clarifications. |
| [docs/PRODUCT_CLARIFICATIONS.md](docs/PRODUCT_CLARIFICATIONS.md) | Before building behaviour the product hasn't defined yet (e.g. offline) |
| [docs/BACKLOG.md](docs/BACKLOG.md) | Named follow-up tasks (I18N-01 translations, DB-VERIFY-01) |
| [Figma: Jitan](https://www.figma.com/design/KBsMGoDoYHR9AJq5sAnPb1) | Before building any screen: approved flows are the UI/UX source of truth (rule §30) |

### Figma pages

File key `KBsMGoDoYHR9AJq5sAnPb1`.

| Page | Node | Used by |
|---|---|---|
| 00 — Foundations | `0:1` | `packages/jitan_ui` (colors, typography, spacing) |
| 01 — Employee App | `1:19` | `apps/employee_mobile` |
| 02 — Jitan Terminal | `1:20` | `apps/terminal` |
| 03 — HR | `1:21` | `apps/admin_web` |
| 04 — Admin | `1:22` | `apps/admin_web` |
| 05 — Components | `1:23` | `packages/jitan_ui` |
| 06 — Employee Web | `147:2` | `apps/employee_web` |

## Development mode

Unresolved production details never stall development. Classify every issue (ENGINEERING_RULES §0):
**DEV TEMPORARY** (use a dev substitute) · **PRODUCT CLARIFICATION** · **IT CLARIFICATION** ·
**ERD GAP**. Stop only the affected behaviour; continue everything else.

- **Dev identity:** with `JITAN_ENV=development` or `test`, `JITAN_DEV_USER_ID` supplies the
  acting user. With `JITAN_ENV=production` (also the default when unset), the server refuses
  to start if any `JITAN_DEV_*` variable is set.
- **Dev permissions:** a dev-only permission evaluator allows everything and is selectable
  only outside production. Production authorization (CLARIFY-10/11) plugs into the same
  interface.
- **Dev data:** fixtures go in the dev/test database only, names prefixed `[DEV]`. Production
  code never references them.

## Stack

- **Clients:** Flutter (Android first → iOS → Employee Web → Admin Web → Terminal)
- **Backend:** standalone Dart API (HTTP/JSON)
- **Database:** MySQL, provided externally. Schema is **fixed** (see below).
- **Dev:** no Docker. **Prod:** Hyper-V → Linux VM → Nginx → Dart `systemd` service → MySQL

## The database schema is fixed

The ERD is the source of truth. **Never** create migrations, add tables or columns, rename
columns, repurpose a field, or invent backend-only storage to cover a missing
relationship. Schema changes happen only after discussion with IT and explicit approval.

Before adding any model, service, endpoint or query, map the concept to the ERD:

1. An existing table represents it → use it.
2. An existing junction table represents it → use it.
3. A type table represents it (`tblGroup`, `tblScheduleType`, `tblTimeRegType`,
   `tblLocationType`, `tblCredGroup`, `tblFunction`, `tblEventType`) → use it.
4. Nothing represents it → **STOP**. Add an entry to
   [ERD_GAPS.md](docs/database/ERD_GAPS.md) as **"ERD GAP — requires clarification with
   IT"** (requirement, tables considered, why they don't fit, what's missing). Implement
   no workaround. Keep building the parts that don't depend on it.

Easily confused tables:

- `tblGroup` = **employee type** (Blue collar / White collar)
- `tblCredGroup` = **access role** (Employee / HR / Admin)
- `tblFunction` = **specific capability** (Correct time, Export report, …)
- `tblScheduleType` = **kind of period** (Work / Break / Lunch / Travel). Break duration and
  similar "policy" settings are schedule rows, not a policy table. **There is no policy
  table.**
- `tblUser.userName` is the **first name**, not a login name. Login is `userCode`.

Use column names exactly as spelled in the ERD (`userQRcode`, `tblEventLog.userfunctionID`).
Read lookup values (roles, modules, functions, types, languages) from the database. Never
hardcode or invent them.

## Non-negotiable architecture rules

1. **No client touches MySQL.** Flutter apps talk only to the Dart API over HTTPS.
   There is no DB driver in any `apps/` or `packages/` target.
2. **The backend is authoritative** for time calculation: rounding, work-session
   boundaries, totals. `jitan_core` may mirror logic for display, but client-side results
   are never persisted or trusted.
3. **Actual time is never overwritten.** Jitan treats the actual detected time and the
   registered (rounded/corrected) time as separate concepts. *How* the registered time is
   persisted with a single `tblTimeReg` timestamp is open as **GAP-01**. Don't write
   time-engine persistence code until it is resolved.
4. **No physical deletes** of business/master data. Use `Active` + `MFD` (Marked For
   Deletion). `MFD = true` hides a record from the UI; the row stays. Every read filters
   `MFD = false`; selectable lists also filter `Active = true`.
5. **Location session ≠ work session.** Leaving a geofence does not end the workday.
   Moving between recognized workplaces continues the same work session. Work sessions are
   derived from the `tblTimeReg` stream; there is no session table.
6. **Audit through `tblEventLog`**, never a separate log table. Set `userIDInit` (actor),
   `userIDTarget` (subject) and the FK of each entity involved. Write the business change
   and its event-log row in **one transaction**.
7. **Company scoping is mandatory.** Employees belong to companies through
   `tblUserCompany`, which is many-to-many, so one person can be in several companies. HR
   works inside a **current company** and sees only that company's data. Company-scoped
   endpoints take the company in the path (`/companies/{id}/…`), query only that company,
   and pass it to `Authorizer.require(…, companyId: id)` so the permission evaluator can
   enforce access. Never only in the UI.
8. **Passwords and PINs are hashed server-side** (`userPassword`, `userPINCode`). They are
   never visible to HR/Admin, never logged, never returned by an API. Algorithm pending
   **CLARIFY-01** (blocks production auth only; development uses the dev identity).

## QR types: do not conflate

The onboarding QR and the personal (Terminal) QR are the **same value** for the MVP. It
never expires. **Onboarding complete ⇔ `userPassword IS NOT NULL`**: setting the password
is the mandatory last onboarding step, and the server refuses to start or redo onboarding
once it is set (`onboarding_already_completed`). Never check activation any other way. Treat the value as a credential: never log it, send it with
`cache-control: no-store`, show it only as a QR.

| QR | Generated by | Represents | Used for | ERD |
|---|---|---|---|---|
| Onboarding QR = Personal QR | system, at employee creation (HR shows it) | the employee | onboarding, then Terminal check-in/out | `tblUser.userQRcode` (IT decision 2026-10-07; one value, random, never derived from IDs) |
| Web-login QR | browser session | the *browser*, not the employee | approving a web sign-in from the mobile app | **GAP-05** |

## Layout

```text
apps/      employee_mobile · employee_web · admin_web · terminal
packages/  jitan_ui · jitan_models · jitan_api_client · jitan_core
server/    jitan_api
```

Dart pub workspace, one lockfile at the root. **Exists today:** `apps/admin_web`,
`packages/jitan_models`, `packages/jitan_api_client`, `packages/jitan_core`,
`packages/jitan_ui`, `server/jitan_api`.
The others are created with their first slice (no empty placeholder packages).

### Commands

```sh
flutter pub get                    # repo root, resolves everything
dart analyze                       # repo root, must report no issues
cd server/jitan_api && dart test   # also: packages/jitan_models, jitan_api_client, jitan_core
cd apps/admin_web && flutter test  # also: packages/jitan_ui
cd server/jitan_api && dart run bin/server.dart
cd apps/admin_web && flutter run -d chrome --web-port 5000 --dart-define=JITAN_API_BASE_URL=http://127.0.0.1:8080 --dart-define=JITAN_DEV_TOOLS=true
```

Details (env vars, dev seed, integration tests): [README.md](README.md).

### Server structure

`server/jitan_api/lib/src/<module>/` has `<module>_routes.dart` (thin HTTP: authorize,
parse, respond), `<module>_service.dart` (validation, use cases), `<module>_repository.dart`
(all SQL). Cross-cutting: `config/`, `database/` (`Database`, `DbRow`), `http/` (errors,
CORS, JSON), `auth/` (`RequestIdentity`, `Authorizer`, `PermissionEvaluator`). Every
endpoint calls `Authorizer.require(request, Permission.x)` first. Add the permission to
`auth/permission.dart`, and add any new column to
`test/integration/schema_contract_test.dart`.

**Writes.** A use case that changes data runs in `TransactionRunner.transaction` (the
`Database`). Repository write methods take the transaction's `SqlExecutor`, and the
`AuditLogRepository.record(tx, AuditEvent(...))` call goes **inside** the same
transaction, so data and audit commit or roll back together. Validation errors throw
`ApiException.validation(field, …)` so clients can mark the right field. Map MySQL
duplicate-key (1062) and too-long (1406) errors to 409/400 in the service.

### DEV TEMPORARY items in the code

Development-only stand-ins that must be replaced before production. Each is isolated and
named so it can be found:

| Item | Replace with | Blocked on |
|---|---|---|
| `DevelopmentIdentityMiddleware` | real authentication middleware attaching `RequestIdentity` | CLARIFY-01 |
| `DevelopmentPermissionEvaluator` / `UnconfiguredPermissionEvaluator` | evaluator over `tblCredGroup`/`tblAppModulesCredGroup`/`tblFunction` | CLARIFY-10, -11 |
| Sidebar role caption omitted | signed-in user's credential group from a `/me` endpoint | CLARIFY-11 |
| `DevCompanySelector` (admin_web, only with `JITAN_DEV_TOOLS=true`) | the production company switcher | switcher design (PRODUCT-CLARIFY-EMPLOYEES-LIST) |

Backend modules (each with controller / service / repository / models / validation):
`auth companies employees onboarding languages locations geofences schedules
time_registration work_sessions reports events`

Modules waiting on ERD gaps, not to be built until resolved: `devices` (GAP-05),
`terminals` (GAP-09), `visitors` (GAP-10), `exceptions` (GAP-08, detection-only is fine).
`policies` from the roadmap is **not** a module: its concerns live in `schedules`,
`geofences` and `employees` (groups).

## Conventions

- Employee identity for login is **employee code** (`userCode`), not email. No email is
  required anywhere.
- Shared models live in `jitan_models` and are the single definition used by every client.
- **Translations.** English is **built in**, in one central map: `builtInEnglish`
  (jitan_core). It is the default and the final fallback, and renders with no API,
  database or network. Other languages come from `tblTranslation` (via
  `tblLanguage`/`tblUserLanguage`); the apps never read English from the database.
  Resolution per key: selected database language → built-in English → the key itself
  (logged). Rendering never waits for translations: apps start in English and switch
  when the user's bundle arrives. Spec: I18N-01 in [docs/BACKLOG.md](docs/BACKLOG.md).
- **Never put copy in a widget.** Use `context.t(SomeTextKeys.x)` /
  `context.tPlural(key, n)` under a `TranslationScope`. Keys (meaning, not copy:
  `company.add`) are constants in `CommonTextKeys` (shared) or `<App>TextKeys`. **Every
  new key needs its English text in `builtInEnglish`**; a test fails otherwise, and also
  fails if a screen passes a string literal to `t()`.
- Mobile and Terminal queue events locally (SQLite) when offline and sync on reconnect. An
  event's actual timestamp is the moment it happened, not the moment it synced.
- Authorization: role → modules via `tblUserCredGroup` + `tblAppModulesCredGroup`;
  capabilities via `tblUserFunction`. HR and Admin seeing the same screens in V1 is a data
  configuration, not a code branch. Keep permission checks in one place.

## Testing priority

The **time engine, rounding, and audit trail** carry the most risk and get the most tests,
including generated code. Rounding cases to cover: arrival before/after scheduled start,
arrival outside the rounding window, mid-session workplace change, short exit under and
over threshold, missing start, missing end, HR correction over a rounded value.
