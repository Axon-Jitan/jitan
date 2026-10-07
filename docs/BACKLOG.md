# Backlog: Named Follow-up Tasks

Work that is defined and agreed but not yet done. Blockers that need someone else's
answer live elsewhere: ERD/IT questions in [database/ERD_GAPS.md](database/ERD_GAPS.md),
product questions in [PRODUCT_CLARIFICATIONS.md](PRODUCT_CLARIFICATIONS.md).

Status values: `TODO` · `IN PROGRESS` · `DONE (commit)`

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
Status: `TODO` · waiting for dev database credentials · **does not block development**

- [ ] Fill `server/jitan_api/.env` and `.env.test` (never committed)
- [ ] `dart test` in `server/jitan_api` with `JITAN_TEST_DB_*` set: every skipped
      integration test (schema contract, repositories) must pass
- [ ] Verify every mapped column against the real schema
- [ ] Inspect the actual reference rows of `tblGroup`, `tblCredGroup`, `tblAppModules`,
      `tblFunction`, `tblScheduleType`, `tblTimeRegType`, `tblLanguage`, `tblTranslation`
      and report how they compare with the code's assumptions
- [ ] `dart run tool/dev_seed.dart` if the database lacks useful data (add `--pseudo-language` to
      see a database language), then run the API and the Admin web app against it and check the list
      in a browser, in English and in the pseudo language
- [ ] Report any mismatch. **Never change the fixed ERD to make code or tests pass**;
      fix the code, or raise an ERD gap.

---

## Employee management

Order agreed 2026-10-07. Employee Onboarding follows immediately after.

| Task | Scope | Status |
|---|---|---|
| EMP-01 | Employee list for the current company: search, Type from `tblGroup`, all states, responsive, translation keys. Location/Onboarding show "—" (GAP-11/GAP-04), Policy omitted | `DONE` |
| EMP-02 | Add employee: first/last name, code, type (`tblGroup`), phone, in the current company; one transaction incl. audit; duplicate-code and validation errors on their fields. Location and Work policy omitted | `DONE` |
| EMP-03 | Employee details modal from a row click: type, phone, status; Location/Account "—", Work policy omitted | `DONE` |
| EMP-04 | Company assignment (`tblUserCompany`) | `TODO` |
| EMP-05 | Group assignment (`tblUserGroup`) | `TODO` |
| EMP-06 | Language assignment (`tblUserLanguage`) | `TODO` |
| EMP-07 | Credential-group assignment (`tblUserCredGroup`) where required | `TODO` |
| EMP-08 | Onboarding QR from Employee details: shows `tblUser.userQRcode` as a scannable QR (stores a random one once if missing, audited); no-store, never logged or shown as text | `DONE` |
| EMP-09 | Bulk import (Figma "Import CSV / Excel", roadmap §8): upload → preview → validate → import | `TODO` |

## Employee onboarding (next)

| Task | Scope | Status |
|---|---|---|
| ONB-01 | Server: `POST /onboarding/start` resolves a scanned `userQRcode`; `POST /onboarding/complete` sets the mandatory password (Argon2id since ONB-05), which completes onboarding; **re-onboarding guard** (`userPassword IS NOT NULL` → 409), row-locked and race-safe; audited; `OnboardingApi` client ready for ONB-02 | `DONE` |
| ONB-04 | Rate limiting on the public onboarding **and sign-in** endpoints. Sign-in is the important one: an employee code is not secret, so only Argon2id's cost slows password guessing today. Needs a decision on lockout vs. throttling (no ERD field for failed attempts) | `TODO` |
| ONB-05 | Argon2id password hashing (off the event loop, PHC format, benchmark tool `tool/bench_argon2.dart`); onboarding completion stores the password and language in one transaction and returns a session token for the device (no second sign-in); bearer-token middleware (active + password-fingerprint check on every request); `GET /me`; `ApiTransport.accessToken`, `MeApi` | `DONE` |
| ONB-06 | Persisted trusted devices and per-device revocation: blocked on **GAP-05** (no device/session table). Until then the device id lives only in the stateless token | `BLOCKED` |
| AUTH-01 | Mobile sign-in and recovery (Figma Auth / 01–07): `POST /auth/sign-in`, generic failures; Forgot password → Recover with QR (only after HR/Admin reset, then Set new password → Home); Profile → Password & web login → Change password (`POST /me/password`); Sign out; HR/Admin "Reset account access" in Employee details (`reset-access`, audited); returning devices open sign-in; 06B Recovery refused; Change password with current password; onboarding 06B Language after permissions | `DONE` |
| AUTH-03 | Employee Web / 07B Change password: **designed and backend-ready** (`POST /me/password`, current password verified, tested). Implementation deferred to the Employee Web roadmap task, built as one coherent app from the approved Figma (Login, QR login when GAP-05 allows, Home, Period, My QR, Profile, Password & web login, Change password, Notifications, Registration method, Privacy, Sign out). No partial Employee Web app before then | `DEFERRED` |
| AUTH-02 | HR/Admin and Employee Web sign-in screens (Figma "Employee Web / 01 Login") on the same endpoint; then remove the development identity from production paths | `TODO` |
| ONB-02 | Employee app `apps/employee_mobile` (Android first): welcome → scan → confirm → registration method → permissions → language (06B) → set password → ready → home, signed in by onboarding (token in secure storage, device id per install); all Figma error states incl. session recovery. Widget- and unit-tested against a simulated API. **Not yet built or run on a device: the Android SDK isn't installed on the dev machine** | `DONE` (device run pending) |
| ONB-07 | Run ONB-02 on a real Android device/emulator against the dev API; iOS Podfile permission macros and first iOS build | `TODO` |
| ONB-03a | HR side: Activated / Not activated in the list's Onboarding column, the details Account field and the Onboarding card; activated employees' QR shown as the personal Terminal QR | `DONE` |
| ONB-03b | HR side: live "Employee activated" confirmation while the QR modal is open (Figma `153:532`); needs polling or push | `TODO` |
