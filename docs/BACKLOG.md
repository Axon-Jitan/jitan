# Backlog: Named Follow-up Tasks

Work that is defined and agreed but not yet done. Blockers that need someone else's
answer live elsewhere: ERD/IT questions in [database/ERD_GAPS.md](database/ERD_GAPS.md),
product questions in [PRODUCT_CLARIFICATIONS.md](PRODUCT_CLARIFICATIONS.md).

Status values: `TODO` · `IN PROGRESS` · `DONE (commit)`

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
assigned → English, logged as a data error (CLARIFY-07).

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

- **Key convention vs. existing rows.** Code uses `company.title` / `common.retry` style
  keys. If `tblTranslation` already holds rows under another convention (CLARIFY-11),
  align before translations are entered.
- **Production content.** Who enters and maintains non-English rows, and how (an admin
  screen, IT scripts)? A screen listing keys without a translation per language would
  help translators.
- **Plural rules.** Plural keys use `.one` / `.other`, which fits English and Dutch;
  French (0 is singular) and others need richer keys when added.
- CLARIFY-07 (one language per user?) and CLARIFY-08 (duplicate keys per language).

---

## DB-VERIFY-01: Verify the Company list against the real dev database
Status: `TODO` · waiting for dev database credentials

- [ ] Fill `server/jitan_api/.env` and `.env.test` (never committed)
- [ ] `dart test` in `server/jitan_api` with `JITAN_TEST_DB_*` set: schema contract and
      company repository integration tests must pass
- [ ] `dart run tool/dev_seed.dart` if the database lacks useful data (add `--pseudo-language` to
      see a database language), then run the API and the Admin web app against it and check the list
      in a browser, in English and in the pseudo language
- [ ] Fix any column-spelling or type differences the schema contract test finds
