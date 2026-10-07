# Backlog: Named Follow-up Tasks

Work that is defined and agreed but not yet done. Blockers that need someone else's
answer live elsewhere: ERD/IT questions in [database/ERD_GAPS.md](database/ERD_GAPS.md),
product questions in [PRODUCT_CLARIFICATIONS.md](PRODUCT_CLARIFICATIONS.md).

Status values: `TODO` · `IN PROGRESS` · `DONE (commit)`

---

## I18N-01: Database-driven translation infrastructure
Status: `IN PROGRESS`: built and tested in code; **verification against the real
database is pending** (DB-VERIFY-01). Required before any UI is production-ready.

The DEV TEMPORARY `AdminStrings` map has been deleted. The Company list is the first
screen fully on database translations.

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

- [x] Server: `LanguageRepository`, `TranslationRepository`, `LanguageService`,
      `LanguageRoutes` with unit tests and DB integration tests (only active, non-MFD
      languages; duplicate keys keep the lowest `translationID` and are logged)
- [x] Server: the user's language from `tblUserLanguage` (`GET /me/language`): none →
      `null` (client uses English); several → 409 `configuration_error` (CLARIFY-07)
- [x] Shared `TranslationService` + `Translations` in `packages/jitan_core` (bundle cache,
      fallback chain, missing keys logged once); `TranslationScope` / `context.t()` in
      `packages/jitan_ui`
- [x] Company list, shell and error states use stable keys (`AdminTextKeys`,
      `CommonTextKeys`). `AdminBootstrap` loads the user's bundles before the app renders.
- [x] Tests: language switching, fallback to English, missing key shows the key and is
      logged once, user language none/one/several/not signed in, bootstrap end-to-end
      with Dutch → English → key
- [x] Dev seed (`tool/dev_seed.dart`) ensures the English `tblLanguage` row and inserts
      missing English texts for every key in use (`tool/dev_translations_en.dart`, seed
      data only, never read by the apps)
- [x] `AdminStrings._englishFallback` deleted
- [ ] Verify against the real dev database (DB-VERIFY-01)
- [ ] A language switcher in the UI: none is designed for HR/Admin yet; the Employee
      app's onboarding has one (roadmap §11)

### Open points

- **Key convention vs. existing rows.** Code uses `company.title` / `common.retry`
  style keys. If `tblTranslation` already holds rows under another convention
  (CLARIFY-11), align before production content is entered.
- **Production content.** Who enters and maintains translation rows in production, and
  how (an admin screen, IT scripts)? The dev seed refuses to run in production.
- **Text before any bundle loads.** If even the English bundle cannot be loaded (API down
  at startup, or a build without an API address), the error screen can only show keys,
  e.g. `common.error.network.title`. That follows the fallback rule, but is unfriendly.
  Is that acceptable, or should a minimal built-in bootstrap message be allowed as the
  one exception?
- **Plural rules.** Plural keys use `.one` / `.other`, which fits English and Dutch;
  French (0 is singular) and others need richer keys when added.
- CLARIFY-07 (one language per user?) and CLARIFY-08 (duplicate keys per language).

---

## DB-VERIFY-01: Verify the Company list against the real dev database
Status: `TODO` · waiting for dev database credentials

- [ ] Fill `server/jitan_api/.env` and `.env.test` (never committed)
- [ ] `dart test` in `server/jitan_api` with `JITAN_TEST_DB_*` set: schema contract and
      company repository integration tests must pass
- [ ] `dart run tool/dev_seed.dart` if the database lacks useful data (also seeds English
      translations), then run the API and the Admin web app against it and check the list
      in a browser, in English and in a second language
- [ ] Fix any column-spelling or type differences the schema contract test finds
