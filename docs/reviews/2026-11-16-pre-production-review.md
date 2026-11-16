# Pre-production review: security, quality and synchronization

**Date:** 2026-11-16 · **Scope:** `server/jitan_api` (all of `lib/src`, `bin`, `tool`), the
four apps and the shared packages, at tag `v0.0.1` (commit `3f7484a`). **Method:** code
read line by line in four parts (SQL; authorization and data isolation; transactions,
concurrency and Active/MFD; group/schedule and time-registration rules), every serious
finding then checked in the code a second time, and the main defects reproduced with
tests against the local database. No schema, data or code was changed for this review.

## Verdict

- **No SQL injection.** All of the about 90 places where SQL text is built at run time use only text
  from the code (column names, filters, placeholders `:u0, :u1, …`); every value is a
  bound parameter. Searches escape `%`, `_` and `\`.
- **No cross-company leak.** Every company endpoint passes the company to the permission
  check and verifies that every other id belongs to that company.
- **No secret in responses or logs.** Hashes, the session secret, QR values and database
  credentials never leave the server; errors are generic.
- **Not ready for production yet:** five **High** findings break the time records
  themselves (time can be backdated, registered twice, or lost on approval) or let one
  setting switch off all authorization. All five are reproduced by a test.

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 5 |
| Medium | 11 |
| Low | 14 |
| Info | 6 |

## Fix status (updated 2026-11-16)

Every technical finding is fixed, each with a regression test; the full server suite
(843 tests, with the local MySQL) and the analyzer pass. Every product decision is taken; L4 and L5 are accepted as they are.

| Finding | Status | Commit |
|---|---|---|
| H1 terminal | Fixed: a scan older than 2 minutes is refused (the tablet keeps nothing offline) | `250ec55` |
| H1 mobile | Fixed (D51): a tapped time at most 5 minutes old, a detected one at most 24 hours; older goes as a change for HR | `c4ec718` |
| H2 | Fixed: the employee's lock is taken before any read; the same time sent twice is stored once | `250ec55` |
| H3 | Fixed: a correction switches off only what it replaces; impossible start/finish orders refused | `4b4b6be` |
| H4 | Fixed: allow-all permissions need `JITAN_DEV_ALLOW_ALL_PERMISSIONS=true`; `TLS_CERT` forces production | `3e4cccc` |
| H5 | Fixed: the terminal decides in/out under the employee's lock | `250ec55` |
| M1, L12 | Fixed: company names and employee codes under a MySQL named lock | `4d1850d` |
| M2 | Fixed: attempts counted when they start, accent-folded; at most one Argon2 hash per core | `a5c98f9` |
| M3 | Fixed (product owner): nobody corrects, approves, rejects or marks as non-work their own time (403 `own_time_records`, its own message on the HR website) | see git log |
| M4, M5, M6, M8, M9 | Fixed: reactivation re-syncs the schedule; a sole member keeps the group's hours; group locks first, then employees; a deactivated group is refused inside the transaction | `3229997` |
| M7 | Fixed: named locks instead of table-wide locking reads; lock conflicts answer 503 and are retried | `eb04024`, `a7b38b7`, `4e1c829` |
| M10, L1 | Fixed: the rounding rule is read before the transaction; a request counts as approved only at its own time | `4b4b6be` |
| M11 | Fixed (product owner): the tablet sends a scan whose answer was lost once more with the same time (the server knows it); if that fails too it says "Your scan may not be registered" | see git log |
| L2 | Fixed (D52, product owner): only day shifts; nothing outside 05:00–19:00 is registered, so rounding can't cross midnight | see git log |
| L3 | Fixed: the right is checked in every company of the employee | `a878d8d` |
| L4 | Accepted (product owner): any HR person may reset any account, HR and Admin included; the reset is audited with who did it | – |
| L5 | Accepted (product owner): every employee sees every company's places and projects; IT's ERD has no place-to-company link and none is asked for (GAP-03) | – |
| L6 | Fixed: the tablet's id is checked; a retry is not audited twice | `56a79e9` |
| L7 | Fixed: the website's token is `JITAN_MAPBOX_PUBLIC_TOKEN`, only `pk.` accepted | `56a79e9` |
| L8 | Fixed: Jitan's own connection pool discards a broken connection | `3c406bd` |
| L9 | Documented: run one API process (DEPLOYMENT_CONFIGURATION) | `29015d4` |
| L10 | Fixed: audit time in UTC. Rows written before keep the database's zone | `3c406bd` |
| L11 | Fixed: pairing QR audited first, module link only when made, schedule changes per employee | `56a79e9` |
| L13 | Fixed: `ESCAPE '!'`; the API refuses a database with `NO_BACKSLASH_ESCAPES`, as the driver escapes with backslashes | `29015d4` |
| L14 | Fixed | `250ec55` |
| I1 | Fixed: database errors are logged by number only | `a7b38b7` |
| I2 | Fixed: HSTS on direct HTTPS | `29015d4` |
| I3 | Fixed: the Terminal app is not backed up | `29015d4` |
| I4 | Fixed: CLAUDE.md says offline queueing is not built | `29015d4` |
| I5 | By decision D31; no change | – |
| I6 | Fixed: server test files run one at a time | `eb04024` |

Second review (of `3f7484a`, received 2026-11-16): its H1 and the accent part of its
sign-in finding were already fixed (`c4ec718`, `a5c98f9`). New and fixed:
- **Phone events for another employee:** what the phone remembers (arrival, leaving,
  pending trips) belongs to the employee code that signed in; another employee signing in
  drops it, so it is never sent with their session.
- **Pending trips lost:** trips wait in a list (a new one never replaces an unsent one) and
  are dropped only on a refusal (4xx); no connection, 408, 429 or 5xx keep them for later.
- **Retry returning another row:** a retry answers with the rounded row stored right after
  its own time; when HR replaced it, with none, never a later day's row.

Found while fixing L13: the driver (mysql_client_plus) fills parameters in on the client
with backslash escaping. Quotes are always safe, but with `NO_BACKSLASH_ESCAPES` every
stored backslash would be doubled; hence the startup refusal. Replacing the driver stays
open (DB-DRIVER-01).

---

Paths below are relative to `server/jitan_api/lib/src/` unless they start with `apps/`,
`bin/` or `server/`. "Reproduced" means a test against the local MySQL fails today;
the tests are listed in the appendix.

---

## High

### H1. A start or finish can be backdated and counts at once, with no reason and no HR review
- **Where:** `time_registration/time_registration_write_service.dart:81-84` (only a time
  in the *future* is refused), `:149` (`manualEntry` false for `entry=now`);
  `terminals/terminal_device_service.dart:107-129` (the tablet's `at` is used as is).
- **Affected:** `POST /me/time-registrations`, `POST /terminal/scan`, `POST /terminal/switch`,
  `/me/activity` (`activities/activity_service.dart:85-88, 132-135`).
- **Scenario:** an employee sends a start at 07:00 while it is 09:30, or three days ago.
  It is stored as detected, rounded and counted, audited as an ordinary registration.
  This bypasses D30/D31 (a changed time needs a reason and HR's approval).
- **Evidence:** reproduced, API and terminal: a start three days old is accepted and
  stored as `Start – actual – Manual` (not marked manual) plus `Start – rounded`.
- **Fix:** refuse `entry=now` older than a short window (for example 2 minutes plus the
  offline allowance the product decides, see PRODUCT-CLARIFY-OFFLINE); older times must
  go as `entry=corrected` with a reason. The terminal keeps nothing offline (D42), so it
  should use the server's clock or refuse anything older than the skew.

### H2. The same registration sent twice at the same moment is stored twice
- **Where:** `time_registration/time_registration_write_service.dart:98-104`. The first
  statements of the transaction (`_type` lookups) fix MySQL's snapshot *before*
  `lockUser`; a second request that waited for the lock then reads the old snapshot in
  `findSame`, `nextOfType`, `hasAny` (`:112`) and `_runningStart` (`:134-136`).
- **Affected:** every registration (app, geofence, terminal); totals, Time records,
  reports, the audit log. `tblTimeReg` has no unique key that could stop it.
- **Scenario:** a double tap, a retry after a slow network, or two geofence events at the
  same moment.
- **Evidence:** reproduced 3 of 3 runs: two simultaneous identical starts give two
  `Start – actual` and two `Start – rounded` rows (and two audit rows).
- **Fix:** make `lockUser` the first statement of the transaction (as the corrections and
  assignments already do); add a concurrent test (`Future.wait`).

### H3. Approving a "travelling" correction cuts the day short
- **Where:** `time_records/time_correction_service.dart:156-163` (`_count` switches off
  *every* corrected and rounded row of that boundary on that day);
  `time_records/time_record_days.dart:137-138` (`roundedAfter` pairs a time with the
  first rounded row of a higher id) and `:173-176`.
- **Affected:** HR approval of an employee's correction (D34b), corrections that close a
  gap, every total built on the day.
- **Scenario:** 08:00–13:00, away, 15:00–17:00. The employee asks for a travel finish
  at 15:00; HR approves. The 17:00 finish loses its rounded row and is paired with the new
  15:00 one: the day counts until 15:00. The same happens when HR corrects a finish to a
  time before the latest start (there is no "finish before start" check).
- **Evidence:** reproduced: after approval the day shows finish 17:00 but counts 15:00
  (2 h lost). No existing test calls `approve()`; `test/time_records/time_away_test.dart:111-129`
  uses a fixture that `_count` would not produce.
- **Fix:** switch off only the rows that currently count for that boundary (the latest
  finish's corrected/rounded pair), pair rounded rows with their own actual or corrected
  row explicitly, and refuse a corrected finish before the counted start.

### H4. One setting switches off all authorization
- **Where:** `bin/server.dart:184-186`; `config/app_environment.dart:23`. Any `JITAN_ENV`
  other than `production` selects `DevelopmentPermissionEvaluator`, which allows
  everything. Production's guard only refuses `JITAN_DEV_*` variables.
- **Scenario:** `JITAN_ENV=test` (or `development`) left in `/etc/jitan/app.env` or the
  service file: the server starts normally, and every signed-in employee can open every
  company, reset accounts, create recovery QRs and pair terminals.
- **Evidence:** reproduced: a configuration with IT's database settings and
  `JITAN_ENV=test` loads with development permissions.
- **Fix:** select the allow-all evaluator only with an explicit
  `JITAN_DEV_ALLOW_ALL_PERMISSIONS=true` (a `JITAN_DEV_*` name, so production refuses it),
  and refuse to start with `JITAN_ENV≠production` when `TLS_CERT` is set.

### H5. At the terminal, a double scan after coming back ends the day
- **Where:** `terminals/terminal_device_service.dart:111-117`. The one-minute repeat
  window compares with `day.start.actual`, the day's *first* start; and the whole
  check-in/check-out decision is made before, and outside, the registration's lock.
- **Scenario:** in at 08:00, out 12:00, in 13:00, scanned again 20 s later: the second scan
  checks the employee out. Two scans arriving together (two tablets, a retry) can both
  start or both finish the day.
- **Evidence:** reproduced: back in, then a scan 20 s later returns `checkedOut`.
  `test/integration/terminal_integration_test.dart:363-377` covers only the first check-in.
- **Fix:** compare with the latest counting moment, and take the decision and the window
  check inside the registration transaction after `lockUser`.

---

## Medium

| # | Finding | Where | Scenario | Fix | Evidence |
|---|---|---|---|---|---|
| M1 | Two "Add company" with the same name make two companies | `companies/company_service.dart:39-47`, `companies/company_repository.dart:60-64` (plain read, no unique key; the comment at `company_service.dart:95` is wrong) | double click or retry | lock the name check (`FOR UPDATE`) like groups and locations do | reproduced 3/3 |
| M2 | Sign-in throttle bypassed; Argon2 unbounded | `auth/sign_in_service.dart:53-61, 76`; `auth/sign_in_throttle.dart:22, 38-39`; `auth/password_hasher.dart:81` | parallel guesses all pass the check; accent variants of a code are separate keys; >10 000 codes evict a victim's count; hundreds of parallel sign-ins exhaust memory | count before hashing, key on the accent-folded code or user id, cap concurrent hashing (429/503), rate-limit in Nginx | code read |
| M3 | HR/Admin can correct, approve or reject their own time | `time_records/time_correction_service.dart:58-72, 97-123, 129-150` (no actor ≠ employee check, unlike `employees/employee_service.dart:116-118`) | an HR person requests a correction and approves it | refuse when actor = employee, or record a product decision | code read |
| M4 | A reactivated employee keeps a stale schedule | `employees/employee_service.dart:115-134` (no schedule sync); `schedules/schedule_write_repository.dart:39-51, 204-214` | group hours changed while the employee was inactive | run `EmployeeScheduleSync` on reactivation | code read; no test |
| M5 | When a group's only member joins a second group, the first group's hours are deleted | `schedules/employee_schedule_sync.dart:66-71, 131-135, 160-172` | S alone in Solo joins White: Solo's rows are switched off, S has no schedule | treat S's rows as Solo's, or warn HR | code read; no test |
| M6 | Schedule save and membership change at once: no schedule, or deadlock (500) | `schedules/schedule_write_repository.dart:204-214`, `schedules/schedule_editing_service.dart:286-304` | a member joins while HR saves the group's hours | lock affected employees in id order; retry 1213 (needs DB-DRIVER-01) | code read |
| M7 | Deadlocks and lock timeouts mostly not retried | `database/database_exception.dart:31` (1213 only), `http/error_middleware.dart:44-52`; table-wide `FOR UPDATE` in `groups/group_management_repository.dart:42-47`, `locations/location_repository.dart`, `terminals/terminal_repository.dart`, `lists/fixed_list_repository.dart` | concurrent HR work gets 500/503 | retry 1213/1205 in one place for idempotent transactions; fix DB-DRIVER-01 | code read |
| M8 | Adding several employees to a group reads later employees from an old snapshot | `groups/group_member_service.dart:126-135` | another HR change to employee 2 is silently lost | lock all employees (id order) before the first read | code read |
| M9 | A group can be deactivated while someone joins it | `groups/group_management_service.dart:53-69` vs `group_member_service.dart:103, 181` | employee ends up in an inactive group | re-check the group inside the add transaction | code read |
| M10 | Corrections can exhaust the connection pool | `time_records/time_correction_service.dart:164` (`policyOn` uses a second connection inside the transaction) | 10 corrections at once hang every request | compute the policy before the transaction | code read |
| M11 | The terminal says "Nothing was registered" when the server did | `apps/terminal/lib/src/flow/terminal_controller.dart:133-161` | lost response; the rescan a minute later checks the employee out | say "unknown", or resend the same `at` so the server deduplicates | code read |

## Low

| # | Finding | Where | Fix |
|---|---|---|---|
| L1 | HR's own correction silently resolves an employee's pending request, without an approve/reject audit row | `time_records/time_correction_service.dart:194-197`, `time_record_days.dart:119-120` | resolve pending requests explicitly, audited |
| L2 | A rounded time past midnight lands on the next day | `time_records/time_record_days.dart:44-50` | group a rounded row with its own time's date |
| L3 | Deactivate, reset access, and group changes from the employee page check only the path company | `employees/employee_service.dart:115-172`, `employees/employee_assignment_service.dart:181-242` | check every company of the employee (rule §28a.5); no V1 impact |
| L4 | Any HR person can take over another HR/Admin account (reset + recovery QR); the recovery is audited as the target | `employees/employee_service.dart:147-239`, `recovery/recovery_service.dart:79-92` | refuse resetting someone with a group the actor lacks, or need a second person |
| L5 | `/me/locations` and `/me/activity` list every company's client sites to every employee | `locations/location_service.dart:33-36`, `activities/activity_service.dart:276-290` | record as accepted (GAP-03/D44) or filter by company |
| L6 | Terminal pairing doesn't validate `deviceId`; a repeated pairing by the same device runs twice | `terminals/terminal_device_service.dart:66-89`, `temporary_qr/temporary_qr_service.dart:50-56` | `checkedDeviceId`; honour `isRetry` |
| L7 | One variable name for the server's Mapbox secret and the website's public token | `config/app_config.dart:77`, `server/jitan_api/tool/build_release.dart` | separate names; refuse a non-`pk.` token in the web build |
| L8 | A failed `ROLLBACK` can leave a pooled connection "in transaction" | driver `mysql_client_plus` `connection.dart:760-776`; `database/database.dart:57-70` | discard a connection whose transaction failed |
| L9 | Temporary QRs, terminal presence and the sign-in throttle are per process | `temporary_qr/in_memory_temporary_token_store.dart`, `terminals/terminal_presence.dart`, `auth/sign_in_throttle.dart` | fine for one instance (documented); a shared store before scaling out |
| L10 | Audit time is `NOW()`, the database server's zone, not UTC | `audit/audit_log_repository.dart:17` | `UTC_TIMESTAMP()` |
| L11 | Audit gaps: pairing QR issued before its audit; a module link audited even when it already existed; `tblUserSchedule` link changes not audited one by one | `terminals/terminal_service.dart:119-120`, `auth/first_hr_setup_service.dart:137-138`, `schedules/employee_schedule_sync.dart` | audit first; audit only real changes |
| L12 | Codes that differ only by accents (RENÉ, RENE) can both be created at once | `employees/employee_service.dart:301` | lock the check |
| L13 | Search escaping relies on MySQL's default `LIKE` escape, which `NO_BACKSLASH_ESCAPES` turns off | `database/like_pattern.dart:3-4` | add `ESCAPE '\\'` to the `LIKE` clauses |
| L14 | An empty type list gives `IN ()` (500) when the registration types are not set up yet | `time_registration/time_registration_write_service.dart:220-227` | refuse with a configuration error first |

## Info

- I1. Unhandled errors are logged with the database's message, which can contain a column
  value (`http/error_middleware.dart:45`). Redact `DatabaseQueryException.cause`.
- I2. API responses have no `Strict-Transport-Security`; add it when serving TLS directly.
- I3. The Terminal app's manifest lacks `android:allowBackup="false"` (the employee app has it).
- I4. **Offline queue not built**, although CLAUDE.md "Conventions" says Mobile and
  Terminal queue events in SQLite: open by decision (PRODUCT-CLARIFY-OFFLINE, D42). A
  geofence arrival that can't be sent is lost (`apps/employee_mobile/lib/src/geofencing/geofence_event_handler.dart:29-30, 79`).
  Correct the CLAUDE.md line.
- I5. "Mark as non-work" switches off actual rows too: by decision D31.
- I6. One integration test (`test/integration/first_hr_integration_test.dart`, the
  command test) timed out once while every suite ran at the same time; it passes alone
  and in a normal full run.

## Synchronization: what holds

Checked and correct: a group's save gives fresh rows and switches old ones off (never
in place, never deleted); employees in several groups that follow the group move with it;
removing or re-adding a membership reactivates the old rows; a group with employees can't
be deactivated; renaming leaves schedules alone; groups and schedules are user-wide, so
several companies are handled; every registration writes its actual and rounded rows and
its audit row in one transaction; corrections switch rows off, never delete; day bounds
use the workplace zone, so 23- and 25-hour days are right; a retried trip is not counted
twice. Covered by `test/integration/employee_schedule_sync_integration_test.dart`,
`schedule_editing_integration_test.dart`, `time_registration_write_integration_test.dart`
and the unit suites. Not covered: everything concurrent (H2, H5, M1, M6, M8, M9), the
approve path (H3), the spring-forward day.

## Order of work

1. **Before IT installs 0.0.1 for real use:** H4 (one-line config guard) and H1 (refuse
   backdated "now" times).
2. **Before employees register real time:** H2, H3, H5, M11, then M1–M3.
3. **Before more HR users work in parallel:** M4–M10.
4. Low and Info as part of normal work. Each fix gets the matching reproduction test.

## Appendix: evidence

| Run | Result |
|---|---|
| `dart analyze` (repository) | no issues |
| `server/jitan_api`: `dart test` with the local MySQL (unit + 229 integration, incl. `sql_injection_integration_test.dart`) | 813 passed |
| `packages`: models 56, api_client 64, core 35, ui 24 | all passed |
| `apps`: employee_mobile 174, admin_web 417, employee_web 28, terminal 23 | all passed |
| Reproduction tests (not committed; local MySQL, `[DEV-TEST]` rows removed) | H1 (API and terminal), H2 (3/3), H3, H4, H5, M1 (3/3) all **fail as described** |

The reproduction tests are kept outside the repository, ready to be added as regression
tests with each fix: H3 and H1 by `TimeCorrectionService.approve` and
`TimeRegistrationWriteService.register` on a gap day; H2 and M1 with `Future.wait`; H5 and
the terminal side of H1 in `terminal_integration_test.dart`; H4 with
`AppConfig.fromSources`.
