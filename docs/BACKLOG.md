# Backlog: Named Follow-up Tasks

Work that is defined and agreed but not yet done. Blockers that need someone else's
answer live elsewhere: ERD/IT questions in [database/ERD_GAPS.md](database/ERD_GAPS.md),
product questions in [PRODUCT_CLARIFICATIONS.md](PRODUCT_CLARIFICATIONS.md).

Status values: `TODO` · `IN PROGRESS` · `DONE (commit)`

---

## I18N-01: Database-driven translation infrastructure
Status: `TODO` · **required before any UI is production-ready**

Replaces the DEV TEMPORARY `AdminStrings._englishFallback` map in `apps/admin_web`.

### Rules

- **The database is the only source of truth for UI text.** No `en.json` / `nl.json`, no
  ARB files, no hardcoded translation maps. JSON is only the API transport format.
- **English is an ordinary `tblLanguage` row** (`languageCode = 'en'`), not a special case in
  Flutter. It is the default language and the fallback language.
- `tblTranslation.translationUIName` is a stable key that describes **meaning, not copy**:
  `company.add`, `common.save`, `onboarding.language.title`. Not `Add company`, not
  `Screen1Label2`.
- Production UI never contains literal copy: `Text(t('company.add'))`, not
  `Text('Add company')`.

### Resolution

```text
user language: tblUserLanguage → tblLanguage (active, not MFD)
    no language set → English

text for key K:
    selected language has K? → use it
        ↓ no
    English has K?            → use it
        ↓ no
    show K itself, and log the missing key
```

### Loading

Bundles, never key-by-key:

```text
tblLanguage → tblTranslation → Dart API → Flutter translation service → in-memory cache → UI
```

- `GET /languages`: active, non-MFD languages (for the language picker)
- `GET /translations?language=<code>`: the whole bundle for one language,
  e.g. `{"common.save": "Opslaan", ...}`
- The client loads the selected bundle **and** the English bundle on app start, on
  session start and on language change, and caches them.
- The current user's language comes from the server (`tblUserLanguage`), not from a
  client guess.

### Scope

- [ ] Server: language and translation repositories, service, routes, tests (including
      only active/non-MFD languages and translations)
- [ ] Server: resolve the current user's language from `tblUserLanguage`, defaulting to English
- [ ] Shared translation service in a shared package (bundle cache + fallback chain),
      used by every Flutter app
- [ ] Replace hardcoded user-facing strings with stable keys. **The Company list is
      migrated first**, to prove the full path end-to-end.
- [ ] Tests: language switching, fallback to English, missing key shows the key and is
      logged
- [ ] Seed the Company list keys for English (and any other active language) in the dev
      database
- [ ] Delete `AdminStrings._englishFallback`

### Open points to settle while building it

- Existing `tblTranslation` key naming: the dev stand-in uses `admin.companies.title`
  style keys; the examples given use `company.title`. Align on one convention with the
  rows that already exist in the database (CLARIFY-11) before seeding.
- CLARIFY-07 (one language per user?) and CLARIFY-08 (duplicate keys per language).

---

## DB-VERIFY-01: Verify the Company list against the real dev database
Status: `TODO` · waiting for dev database credentials

- [ ] Fill `server/jitan_api/.env` and `.env.test` (never committed)
- [ ] `dart test` in `server/jitan_api` with `JITAN_TEST_DB_*` set: schema contract and
      company repository integration tests must pass
- [ ] `dart run tool/dev_seed.dart` if the database lacks useful data, then run the API and
      the Admin web app against it and check the list in a browser
- [ ] Fix any column-spelling or type differences the schema contract test finds
