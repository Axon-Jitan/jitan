# Product Clarifications

Product behaviour that is not yet defined. Per [ENGINEERING_RULES.md](ENGINEERING_RULES.md)
§0, each item stops **only** the behaviour it describes. All other work continues.

Database-structure questions live in [database/ERD_GAPS.md](database/ERD_GAPS.md).

Status values: `OPEN` · `RESOLVED (date, decision)` · `WITHDRAWN (reason)`

---

## PRODUCT-CLARIFY-OFFLINE: Offline registration semantics
Status: `OPEN`

**Affects:** final offline-capable registration in Employee Mobile (§41) and Jitan
Terminal (§26–§27).

**Does not block:** backend, Employee Web, HR/Admin Web, foundation work, or online-only
mobile/terminal flows.

To define before offline registration is implemented:

- what can be queued (geofence arrival/departure? terminal QR scans? manual corrections?)
- what cannot be queued (e.g. anything needing a server decision first)
- which timestamp is authoritative: device clock at the event, or server receipt (and how
  device clock drift is handled)
- retry behaviour (backoff, maximum age of a queued event)
- duplicate prevention (same scan sent twice, same geofence transition from two sources)
- conflict handling (queued event contradicts what the server already has, e.g. an HR
  correction made while the device was offline)
- UI pending state (how the employee or terminal user sees "recorded, not yet confirmed")
- server reconciliation (what the server does with a late event that changes an already
  calculated day)

Related: [ENGINEERING_RULES.md](ENGINEERING_RULES.md) §21 (no fake success) and §26
(offline behaviour must be explicit).

---

## PRODUCT-CLARIFY-COMPANY-LIST: What the company list columns count
Status: `OPEN` · implemented with the interpretation below, easy to change

**Affects:** HR/Admin Companies list (Figma `153:35` / `153:804`), columns "Employees" and
"Last updated".

Current interpretation (in `CompanyRepository.listCompanies`):

- **Employees** = users with a `tblUserCompany` membership in the company and
  `userMFD = 0`. This **includes inactive users** and **includes HR/Admin users** who are
  members. Should it count only active users? Only users whose credential group is
  "Employee"?
- **Last updated** = the latest `tblEventLog.eventLogTimestamp` whose `companyID` is the
  company, or "—" when there is none. Should every event referencing the company count
  (e.g. an employee being added), or only changes to the company record itself? The
  displayed day also depends on the timezone of `eventLogTimestamp` (ERD GAP-02).

---

## PRODUCT-CLARIFY-EMPLOYEES-LIST: Company context and the Type/Policy columns
Status: `RESOLVED (2026-10-07)` except the final switcher design and Policy (below)

Decisions:

1. **Company context.** HR/Admin always works inside a **currently selected company**.
   The Employees screen shows that company's employees only
   (`tblUser → tblUserCompany → tblCompany`), never all companies mixed. Until the final
   company switcher is designed, a **development-only** selector sets the current company.
   No company is hardcoded. *Still open:* the design of the production company switcher
   (Figma has none yet).
2. **Type** = the user's groups (`tblUser → tblUserGroup → tblGroup`), e.g. Blue collar /
   White collar. One group: show it. Several: show all their names, comma-separated, with
   no invented priority. Confirm real usage against production `tblGroup` rows at
   DB-VERIFY-01.
3. **Policy** → split out as PRODUCT-CLARIFY-EMPLOYEE-POLICY.

Still blocked on this page: **Location** (ERD GAP-11) and **Onboarding** (ERD GAP-04),
both shown as "—".

---

## PRODUCT-CLARIFY-EMPLOYEE-POLICY: Meaning of the Employees "Policy" column
Status: `OPEN` · does **not** block the Employees flow

There is no `tblPolicy`, and none will be created. What the product called "policy" is
spread across `tblGroup`, `tblScheduleType`, `tblSchedule`, `tblUserSchedule`,
`tblRoundingRule`, `tblScheduleRoundingRule`, `tblGeofence` and `tblTimeRegType`. Which
of these the Figma column (values "Office" / "Field") should summarise is undefined.

Until it is defined, the column is **omitted** from the Employees list. No fake or
derived policy value is shown or persisted.

---

## PRODUCT-CLARIFY-PASSWORD-POLICY: Password rules
Status: `OPEN` · development defaults in place, does not block

Defined once in `server/jitan_api/lib/src/auth/password_policy.dart`: at least **8
characters** (12+ recommended to the employee), not only spaces, at most **256
characters** (only a guard against abuse; Argon2id has no 72-byte limit). Letters,
numbers, symbols and any Unicode are allowed; no composition rules. Passwords are used
exactly as typed (never trimmed). Open: a breached-password check, and whether HR/Admin
accounts need stricter rules.

---

## PRODUCT-CLARIFY-SESSION-LIFETIME: How long a device stays signed in
Status: `OPEN` · development default in place, does not block

A session from onboarding (or later sign-in) lasts **30 days** by default
(`JITAN_SESSION_LIFETIME_DAYS`). There is no refresh yet: when it expires the employee
signs in again with code + password. Open: the lifetime for mobile, Terminal and
Employee Web; whether activity extends it; whether HR/Admin need shorter sessions.
Revoking a single device needs storage (GAP-05).

---

## PRODUCT-CLARIFY-TRANSLATION-MAINTENANCE: Who maintains translations
Status: `OPEN` · operational, does not block development

Who enters and maintains non-English rows in `tblTranslation` in production, and how (an
admin screen, IT scripts, an export/import for translators)? English is built into the
apps and maintained in code (`builtInEnglish`).

---

## DESIGN-CLARIFY-ONBOARDING: Gaps between Figma and the agreed onboarding flow
Status: `OPEN` · development choices in place, does not block

The Employee app (ONB-02) follows Figma `01 — Employee App` except where Figma conflicts
with decisions already taken, or has no screen:

1. **Language step: no Figma frame.** Built like "05 Registration method" (choice cards,
   English first, other active languages from the database). Please design it.
2. **"03 Employee identifier" is skipped.** The personal QR already identifies the
   employee (EMP-08), so the code screen isn't needed.
3. **Join copy changed.** Figma says "company QR" / "shown on your company terminal". The
   onboarding QR is personal and shown by HR/Admin, so the app says "Scan the personal Jitan
   QR that HR/Admin shows you" and "Scan QR".
4. **"Set this later" removed** from "07 Set password": the password is mandatory (ONB-01).
   The step counter reads "8 of 9" because the flow has the extra language step.
5. **Job title on "04 Account found" omitted.** The ERD has no job title.
6. **"Sign in" and "Contact HR/Admin" buttons on error screens 02 and 04 not shown yet** (required by the 2026-10-07 onboarding brief; waiting on the questions below).
   Sign-in is AUTH-01 (not built); the ERD holds no HR contact details. "Back" is shown.
7. **Ready summary** says "Allow location in Settings to use automatic registration"
   (warning colour) instead of "Required permissions configured" when automatic
   registration was chosen but location was refused. A refusal never blocks onboarding.
8. **Home** is a placeholder ("Hello, {name}") until the Today screens are built.
