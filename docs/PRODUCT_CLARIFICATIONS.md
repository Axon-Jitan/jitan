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

The Employee app follows Figma `01 — Employee App` (flow: scan → confirm → registration
method → permissions → 06B Language → 07 Set password → Ready) except where Figma
conflicts with decisions already taken:

1. **"03 Employee identifier" is skipped.** The personal QR already identifies the
   employee (EMP-08), so the code screen isn't needed.
2. **Join copy changed.** Figma says "company QR" / "shown on your company terminal". The
   onboarding QR is personal and shown by HR/Admin, so the app says "Scan the personal Jitan
   QR that HR/Admin shows you" and "Scan QR".
3. **"Set this later" removed** from "07 Set password": the password is mandatory (ONB-01).
4. **Job title on "04 Account found" omitted.** The ERD has no job title.
5. **Ready summary** says "Allow location in Settings to use automatic registration"
   (warning colour) instead of "Required permissions configured" when automatic
   registration was chosen but location was refused. A refusal never blocks onboarding.
6. **Home** is a placeholder ("Hello, {name}") until the Today screens are built.

Resolved by Figma: 06B Language (languages from `tblLanguage`, own name + name in the UI
language from `language.name.<code>` translations, so new languages need only data),
"Already activated? Sign in" (Welcome), Onboarding Error / 02 "Contact HR/Admin" as an
instruction.

---

## DESIGN-CLARIFY-AUTH: Sign-in and recovery: open questions
Status: `OPEN` · small, does not block

Built from the approved Figma frames: Auth / 01–07 and 06B, Profile / Password & web login
/ Change password / Sign out, Admin / Employees — Employee details, Reset account access
modal and its disabled state. Resolved and removed from this list: Auth / 01 layout,
recovery refused, disabled reset, mobile Change password, Welcome "Sign in" and Sign in
"Set up with my QR" links, language selection.

Still open:

1. **"Password & web login" copy** (mobile `137:20`) says "use your email or employee
   login" and "Jitan will send a reset link to your verified contact method". Jitan has no
   email, and V1 recovery is HR/Admin-assisted, so the app shows: "Use your employee code
   with this password to sign in to Jitan on a new device" and "If you're signed out
   everywhere, contact HR/Admin to reset your Jitan access". Please update the frame.
2. **Wrong current password** on Change password has no frame: the app shows an inline
   field error "The current password is incorrect." (same style as the other field errors).
3. **Welcome link position**: Figma places "Already activated? Sign in" (top 786) inside
   the "Get started" button area (756–812); the app puts it directly below the button.
4. **Profile / Employee** shows only what exists (identity, code, Password & web login, Sign
   out); the other rows and the bottom navigation come with their features. Home opens
   Profile from a profile icon until the navigation bar exists.

## DESIGN-CLARIFY-PROFILE-LANGUAGE: Employee changes their language after onboarding
Status: `OPEN` · small, does not block

Employees may change their preferred language whenever they want (decision 2026-10-08).
The server endpoint (`PUT /me/language`, audited) and the client
(`LanguagesApi.setCurrentUserLanguage`) are built. Figma has a language choice only in
onboarding (06B, `199:47`); the Employee App Profile (`62:2`) has no Language row. Please
add one (e.g. reusing the 06B list) so the app can expose it.

## DESIGN-CLARIFY-TEMPORARY-QR: Gaps after the temporary-QR decision (2026-10-08)
Status: `OPEN` · small, does not block

1. **Reset account access** (`196:136`, `207:97`) still says "scan their existing QR" and
   "allow account recovery with the existing QR". The app says: "The employee will need a
   temporary recovery QR to set a new password." and "allow recovery with a temporary
   recovery QR". Please update the frames.
2. **Temporary QR expired** (HR, `207:123`) shows the same modal as a valid QR. When the
   countdown ends the app shows the status "EXPIRED" in place of "VALID FOR 10 MIN" and
   hides the code; "Generate new QR" replaces it.
3. **Onboarding with an expired, used or wrong-purpose QR** has no frame; the app uses the
   Onboarding Error layout with copy modelled on Auth / 06C.
4. **Which QR for an employee who has not set a password:** the database cannot tell a
   new employee from one whose access was reset. Employee details offers the onboarding
   QR; the recovery QR is offered right after Reset account access (and can be
   regenerated there).

## PRODUCT-CLARIFY-LAST-COMPANY: Removing an employee's last company
Status: `OPEN` · small

Removing an employee's **last** active company would leave them in no company, so no
HR/Admin could see or manage them. Jitan refuses it (`409 employee_last_company`) until
the product decides (e.g. disable the employee instead). The current company is not
offered for removal inside its own context (Figma shows it as "Current company").
