# ERD Gaps & Clarifications

Jitan requirements that the fixed ERD ([ERD.md](ERD.md)) cannot represent cleanly, per the
**ERD Gap Policy**. Nothing here gets implemented as a workaround. Each item waits for IT.

Two kinds of entry:

- **GAP**: structural. The information or relationship has no place in the schema.
- **CLARIFY**: the schema probably covers it, but the intended meaning of a field must be
  confirmed before code depends on it.

Status values: `OPEN` · `RESOLVED (date, decision)` · `WITHDRAWN (reason)`

---

## IT dependencies from the 2026-10-08 decisions

1. ~~Column names and types of the approved Active/MFD fields.~~ **Confirmed 2026-10-09**
   in IT's development database: every junction table has `<entity>Active` /
   `<entity>MFD`, `TINYINT(1) NOT NULL` with defaults 1 / 0, so no row can be NULL. Jitan
   uses exactly these names (checked by `schema_contract_test`).
2. **Shared temporary-token store** (only if the API runs as more than one instance):
   Redis or similar, persistence disabled, automatic expiry. Today's single API instance
   uses the in-memory store; a restart invalidates outstanding temporary QRs (HR/Admin
   generates new ones).
3. **`tblEventType` rows** for the new event names (CLARIFY-11).

## Open questions for IT (priority)

GAP-01, GAP-02, GAP-08, GAP-13, CLARIFY-02 and CLARIFY-03 were decided on 2026-10-12/13
within the existing ERD (D1–D16 in [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md#decisions-2026-10-1213-storage-and-behaviour)). Still open:

1. **GAP-03 / D16: projects and default companies.** IT will update the ERD with projects
   and each employee's default company. Registrations use the employee's choice, or else
   these defaults.
2. **CLARIFY-10/11: access roles.** Which credential groups may an actor grant? How do
   credential groups, modules and functions combine into permissions? Which rows go into
   the lookup tables (IT writes the default-data script; Jitan's proposal:
   [reference_data.sql](reference_data.sql))?
3. **Configuration tables.** The 2026-10-12 `ERD.jpg` has `tblConfigType`,
   `tblConfiguration`, `tblUserConfiguration`; IT's creation script (2026-10-13) does not.

---

## Blocking summary

Per [ENGINEERING_RULES.md](../ENGINEERING_RULES.md) §0, a gap blocks only the specific
behaviour it describes. **IT clarifications (CLARIFY-01, -10, -11) do not block
development.** A dev identity and a dev-only permission evaluator stand in until they are
answered, and they block only the production cut-over of authentication and authorization.

| Phase (roadmap §44) | Blocked by |
|---|---|
| Authentication (production cut-over only) | CLARIFY-01 |
| Authorization (production cut-over only) | CLARIFY-10, CLARIFY-11 |
| Companies: list | **not blocked**, built. "Locations" column shows "—" (GAP-03) |
| Companies: Add company (Figma `153:87`) | GAP-02 (country, timezone), GAP-03 (primary workplace), GAP-07 (company registration methods), CLARIFY-11 (audit event type). Only the name is storable, so the slice is held back rather than shipped partially |
| Employees: list (Figma `153:137`) | **not blocked**. Location (GAP-11) shows "—"; Onboarding shows Activated / Not activated (`userPassword IS NOT NULL`); Policy omitted (PRODUCT-CLARIFY-EMPLOYEE-POLICY) |
| Employee onboarding (**Milestone 1**) | **not blocked**, built: temporary onboarding QR (GAP-04 resolved), activated = `userPassword IS NOT NULL` |
| Schedules, schedule types, rounding rules: read-only views | **not blocked**: schedules are global and user-wide (CLARIFY-14 resolved) |
| Schedules and rounding rules: create / edit | **not blocked**: meanings decided (D10, D11) |
| Schedules per group ("policies" in older Figma) | **not blocked**: per group via its members (D2, D3); a change applies immediately (D12; future dates dropped for the MVP) |
| Employee Web QR login, privacy screens | GAP-05 |
| Core time engine (rounding, sessions, writing registrations) | **not blocked**: storage decided (D4–D11). Company/project of a registration waits for IT's ERD update (D16, GAP-03) |
| Geofencing | GAP-06, CLARIFY-04, CLARIFY-05 |
| Rounding (**Milestone 2**) | **not blocked** (D4, D10, D11) |
| Registration method choice | GAP-07 |
| Time Records / Reports per company | GAP-03 |
| Exceptions | **no separate screen**: problems are calculated and shown in Time records (D14) |
| Terminal | GAP-09 |
| Visitors | GAP-10 |

**Milestone 1 still needs GAP-03 (primary workplace).** GAP-04 (onboarding QR) is resolved.
CLARIFY-01 (password hashing) is needed before production, not before development.
Everything else in Milestone 1 maps cleanly.

---

## Resolved without a gap

Recorded so they aren't raised again.

| Requirement | Maps to |
|---|---|
| Employee type (§7) | `tblGroup` via `tblUserGroup`: Blue collar / White collar |
| Groups per company | None: **groups are universal** (IT decision, 2026-10-08). `tblGroup` stays without a company; an employee's groups apply in all their companies and grant no company access. Company-specific groups need IT approval first |
| Access role HR / Admin / Employee (§30) | `tblCredGroup` via `tblUserCredGroup` |
| Work policy (§7, §19) | No table. Distributed across `tblGroup`, `tblScheduleType`, `tblSchedule`, `tblRoundingRule`, `tblGeofence`, `tblTimeRegType` |
| Break duration (§19) | `tblSchedule` row with a Break-type `tblScheduleType` |
| Multi-company employee | `tblUserCompany`, many-to-many |
| Personal QR (§21) | `tblUser.userQRcode` |
| Work session (§15) | Derived from the ordered `tblTimeReg` stream per user |
| Audit trail (§37) | `tblEventLog` + `tblEventType` |
| Translations (§12) | `tblLanguage`, `tblTranslation`, `tblUserLanguage` |

---

# Gaps

## GAP-01: Actual time vs registered time
**Status:** `RESOLVED` (2026-10-13, D4–D8 in [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md#decisions-2026-10-1213-storage-and-behaviour)): actual and rounded time are separate `tblTimeReg` rows told apart by type; corrections add rows and deactivate the old rounded row; the reason is in `timeRegComment`.

1. **Requirement** (§16, §17, §23, §33, §34): every registration keeps the **actual**
   detected time (08:03) and the **registered** time (08:00) after rounding. The actual
   time is never overwritten. HR corrections preserve original and corrected values, need
   a reason and are audited; approved records never change when a policy changes (product,
   2026-10-12; [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md), Q1–Q8).
2. **Considered:** `tblTimeReg.timeRegTimestamp`, `timeRegWhenModified`,
   `timeRegManualEntry`, `timeRegComment`; `tblEventLog.timeRegID`.
3. **Why not:** `tblTimeReg` has **one** timestamp. `timeRegWhenModified` records *when* a
   row changed, not its previous value. `tblEventLog` can point at the `timeRegID` but has
   no column for old/new values.
4. **Missing:** a place for the registered time, or a confirmed rule that it is never
   stored. Questions for IT:
   - Is `timeRegTimestamp` the **actual** time, with registered time always computed at
     read time from `tblUserSchedule → tblSchedule → tblScheduleRoundingRule`?
   - If so: `tblUserSchedule` and `tblScheduleRoundingRule` have no effective dates, so a
     schedule or rule change would change past registered times. **The product has ruled
     this out** (approved records never change): where is the registered time, or the
     rule applied, of an approved record stored?
   - How is an HR correction stored so the original stays, and how are the original and
     the correction linked? (Jitan assumes no pattern, e.g. not "new manual row + original
     inactive", until IT confirms.)
   - Where is the required correction reason stored? `tblEventLog` has no text column, and
     the intended use of `tblTimeReg.timeRegComment` is not confirmed.
   - In an HR correction, is the value HR enters an *actual* time (still to be rounded)
     or a final *registered* time?

## GAP-02: Company timezone and country
**Status:** `RESOLVED` for Belgium (2026-10-13, D9 in [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md#decisions-2026-10-1213-storage-and-behaviour)): `timeRegTimestamp` in UTC; the workplace time zone (Europe/Brussels) is set once in the server configuration. A workplace outside Belgium would reopen it.

1. **Requirement** (§5): a company has a country and a timezone.
2. **Considered:** `tblCompany`, `tblAddress`.
3. **Why not:** `tblCompany` has only `companyName`. `tblAddress` has city/zipcode but no
   country or timezone. Schedules are wall-clock (`scheduleHrStart = 8`). Comparing a
   `timeRegTimestamp` against 08:00 needs to know *which* 08:00. Without that, rounding
   and lateness can be off by an hour or more. This also affects every employee whose
   workplaces span countries.
4. **Missing:** timezone (and country) on a company or an address. Also: is
   `timeRegTimestamp` stored in UTC or in local time?

## GAP-03: Company ↔ address (workplaces and attribution)
**Status:** `OPEN`, **IT will update the ERD** (2026-10-13, D16 in [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md#decisions-2026-10-1213-storage-and-behaviour)): projects and each employee's default company. A registration uses the employee's choice, or else these defaults.

1. **Requirement** (§6, §30, §32, §36): a primary workplace is configured during company
   creation. HR manages Locations per company. Time Records and Reports filter and total
   **per company**.
2. **Considered:** `tblAddress`, `tblAddressLocationType`, `tblLocationType`,
   `tblGeofenceAddress`, `tblUserCompany`, `tblTimeReg.addressID`.
3. **Why not:** no table links an address to a company. `tblUserCompany` links the *user*
   to companies, not individual registrations. For an employee in both Almeco and PCA,
   nothing says which company a given `tblTimeReg` row counts for, because the address
   would have told us and it has no company.
   Employees can work for several companies (IT, 2026-10-08). Until registrations can be
   attributed to a company, TR-01 shows HR/Admin of each of the employee's companies all
   of that employee's registrations (scoped through the active membership).
4. **Missing:**
   - an address → company relationship
   - which address is a company's *primary* workplace
   - for multi-company employees, how a registration is attributed to a company. Related:
     should their schedules differ per company? `tblUserSchedule` has no company.

## GAP-04: Employee onboarding QR
**RESOLVED (IT decision 2026-10-08): temporary QR codes, not stored in MySQL.** Supersedes
the 2026-10-07 decision that the permanent `userQRcode` also served for onboarding.

- **Onboarding and password recovery use temporary QR codes**: short-lived signed tokens
  (HMAC-SHA256, employee, purpose, expiry 10 minutes, random id) with temporary
  server-side state for one-time use and revocation. Generated on demand by HR/Admin,
  single use, a new one invalidates the previous one, never accepted for another purpose.
  **Nothing is stored in MySQL**: the state lives in a temporary store (in memory for one
  API instance; a shared cache such as Redis, with persistence off and automatic expiry,
  if the API ever runs as several instances: see "IT dependencies" below).
- **`tblUser.userQRcode` stays the permanent Terminal QR** only. It no longer authorizes
  onboarding or password recovery.
- **Activation signal unchanged:** `userPassword IS NOT NULL`. Onboarding and recovery
  both require `userPassword IS NULL` and set it under a row lock
  (`UPDATE … WHERE userPassword IS NULL`).

## GAP-05: Web-login QR, sessions, trusted devices, push tokens
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

1. **Requirement** (§4, §25, §14): browser sign-in approved by scanning a QR on the mobile
   app. Employee can list and revoke **active web sessions** and **trusted devices**.
   Server-initiated notifications ("Finished work?", exceptions).
2. **Considered:** `tblUser`, `tblEventLog`.
3. **Why not:** nothing stores a pending browser-login request, an active session, a
   device, a refresh token or a push token. Stateless signed tokens can authenticate, but
   they can't be listed or revoked per device without storage.
4. **Missing:** session/device storage. Question for IT: is V1 acceptable with stateless
   expiring tokens, no session list/revoke, and device-local notifications only?
5. **Interim (ONB-05, in place):** onboarding "registers" the device only inside its
   session token: a signed, expiring token carrying the userID, the device id and a
   fingerprint of the password hash. Nothing about the device is persisted. Until IT adds
   storage: no list of trusted devices; one device can't be revoked on its own (changing
   the password or deactivating the employee ends **all** sessions); a stolen token stays
   valid until it expires (default 30 days).

## GAP-06: Short-exit threshold
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

1. **Requirement** (§14, §19): after leaving a geofence, the employee is "temporarily
   away" until a threshold expires. Only then does Jitan ask "Finished work?".
2. **Considered:** `tblGeofence.geofenceCorrectionInMin`, `tblSchedule.scheduleMarginMin`,
   `tblScheduleType`, `tblGroup`.
3. **Why not:** no field is clearly this threshold. `geofenceCorrectionInMin` is the
   closest candidate but its meaning isn't confirmed (CLARIFY-04).
4. **Missing:** confirmation of where the threshold lives. If it's
   `geofenceCorrectionInMin`, this gap closes.

## GAP-07: Registration methods (allowed and chosen)
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

1. **Requirement** (§13, §11): HR/Admin controls which methods (Automatic / QR / Manual)
   are available. The employee **chooses** one of the available methods. Figma
   `Admin / Add company` (`153:87`) sets these three toggles **per company** at creation.
2. **Considered:** `tblFunction` / `tblUserFunction`, `tblGroup`, `tblTimeRegType`,
   `tblUser.userKioskMode`.
3. **Why not:** *allowed* methods could plausibly be functions (e.g. a "Use QR
   registration" function granted via `tblUserFunction`), but only if IT confirms that
   use. The employee's *chosen* method has no field anywhere.
4. **Missing:** a company-level setting for allowed methods (`tblCompany` has only name,
   active, MFD; `tblFunction` is per user, not per company). Confirmation for per-user
   allowed methods. A place for the chosen method, or a confirmation that it lives only on
   the device.
5. **Interim (ONB-02, in place):** the employee's choice is stored on the device only
   (`DeviceSettings`, secure storage). Every method is offered, since allowed methods
   can't be read from the ERD. Reinstalling the app loses the choice.

## GAP-08: Exception state and correction requests
**Status:** `RESOLVED` (2026-10-13, D14 in [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md#decisions-2026-10-1213-storage-and-behaviour)): problems are calculated from the registrations and shown in Time records; no stored state, no dismiss, no separate Exceptions screen.

1. **Requirement** (§35): exceptions (missing start/end, unfinished day, conflict,
   correction request) with states open / pending / resolved. HR resolves or dismisses.
2. **Considered:** `tblTimeReg` (detection is derivable from the stream), `tblEventLog` +
   `tblEventType` (resolution could be logged against a `timeRegID`).
3. **Why not:** detection works, but **state** doesn't. A *missing* start has no
   `timeRegID` to log a dismissal against, so a dismissed exception would reappear on
   every recalculation. An employee correction *request* awaiting HR approval needs a
   pending state that no table holds.
4. **Missing:** persisted exception state, or confirmation that exceptions are purely
   derived and that "dismiss" / "pending approval" are out of scope for V1.
5. **Product decision (2026-10-12):** resolving an issue in Time records also resolves the
   corresponding exception. If exceptions are purely derived, a correction that completes
   the stream clears the exception by itself; anything else needs this gap answered.

## GAP-09: Terminals
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

1. **Requirement** (§28, §27): HR manages terminals with name, type (Office / Vehicle),
   company, location or vehicle, online status, last seen, QR enabled, pairing code.
   Registrations made at a terminal.
2. **Considered:** `tblUser.userKioskMode` + `userPINCode` (a terminal as a kiosk user),
   `tblUserCompany`, `tblGroup`, `tblAddress`, `tblLocationType`.
3. **Why not:** a kiosk-mode user can *authenticate* a terminal and belong to a company,
   but there is no user → address link (the terminal's location), no type, no last seen,
   no pairing code, and `tblTimeReg` cannot record which terminal took the scan.
4. **Missing:** terminal metadata and the terminal → registration link. Question for IT:
   is a terminal intended to be a `tblUser` with `userKioskMode = true`?
5. **Product decision (2026-10-13, D18/D19 in
   [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md)):** two terminals, the **workshop**
   (Blue collar employees) and the **front desk** (White collar employees and visitors).
   The employee scans their Terminal QR; the default (client) project applies and can be
   changed, also later in the day, in the app or at a terminal.

## GAP-10: Visitors
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

1. **Requirement** (§29): visitor name, phone, person to meet, number plate, optional
   company, face photo, arrival and departure.
2. **Considered:** `tblUser`, `tblTimeReg`, `tblCompany`.
3. **Why not:** visitors are not users. Storing them as `tblUser` rows would mix them into
   employee lists and give them login fields. Nothing holds a number plate, photo, host or
   visit.
4. **Missing:** the entire visitor concept.
5. **Product decision (2026-10-13, D18):** visitors register at the **front-desk**
   terminal.

## GAP-11: Employee location
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

1. **Requirement** (§7, Figma `Admin / Employees` `153:137`, column "Location"): each
   employee has a location (their workplace, e.g. "Almeco").
2. **Considered:** `tblUser`, `tblUserCompany`, `tblAddress`, `tblGeofenceAddress`,
   `tblTimeReg.addressID`.
3. **Why not:** no table links a user to an address. `tblUserCompany` gives the
   *company*, not the workplace. Deriving it from the latest `tblTimeReg.addressID` would
   show where someone last registered, not their assigned location, which is an
   interpreted fact presented as configuration (ENGINEERING_RULES §10).
4. **Missing:** a user → address (workplace) relationship, or confirmation that
   "Location" means something else (e.g. the company).

## GAP-12: Auditing an employee's language change
**Status: `ACCEPTED` for V1** (product decision 2026-10-08) · no schema change

`tblEventLog` has no `languageID` / `userLanguageID`, so a language-change event cannot say
which language was chosen, and the one `tblUserLanguage` row is updated in place. Decision:
changing language is a **preference update, not a deletion**; Jitan records a generic
`employee.language.changed` event (actor, employee, type, timestamp) and does not keep the
previous/new value. If IT later adds the columns, the event gains the references; nothing
else changes.

## GAP-13: Rounding rules over time and per employee group
**Status:** `RESOLVED` for the MVP (2026-10-13, D2–D4 and D12 in [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md#decisions-2026-10-1213-storage-and-behaviour)): stored rounded rows keep history stable; schedules per group via its members; changes apply immediately (no future effective dates in the MVP).

1. **Requirement** (agreed rounding requirements; Figma `HR / Policies` `215:28`, `216:*`):
   a rounding/policy change applies immediately or from a scheduled date; historical
   approved registrations keep the rule that was applied; a policy applies to an employee
   group (e.g. "Office" → White collar).
2. **Considered:** `tblRoundingRule`, `tblScheduleRoundingRule`, `tblSchedule`,
   `tblUserSchedule`, `tblGroup`, `tblTimeReg`, `tblEventLog`.
3. **Why not:** no effective dates on rules, schedule-rule links or user schedules; no
   stored registered time or applied rule (GAP-01), so recomputing after a change silently
   rewrites history; no approval state on `tblTimeReg`; nothing links a group to schedules
   or rules (only users, via `tblUserSchedule`). (Both junction tables do have Active/MFD,
   confirmed 2026-10-09, so links can be removed without deleting rows.)
4. **Missing:** effective dating (or stored registered time + applied rule), an approval
   state, and a group → schedule/rule relationship. Analysis:
   [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md).

---

# Clarifications

## CLARIFY-01: Password and PIN hashing · `OPEN` · IT CLARIFICATION, blocks production auth only

**Implementation:** Argon2id (RFC 9106) via `PasswordHasher`, stored as the standard PHC
string `$argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>` (verified against libsodium).
Default parameters are OWASP's (19 MiB, 2 iterations, 1 lane), about 140 ms per hash on
the development machine (compiled); they are configurable (`JITAN_ARGON2_*`) and must be
measured on the production server with `tool/bench_argon2.dart`. The format is
self-identifying, so if IT requires another algorithm, existing hashes can be recognised
and re-hashed at the next sign-in. The default format is 97 characters long.
**Width: answered** by IT's database (2026-10-09): `userPassword` and `userPINCode` are
`VARCHAR(255)` NULL, wide enough. **Still open for IT:**
is anything else already writing or reading `tblUser.userPassword` / `userPINCode`? If so,
Jitan must use **the same hashing algorithm and parameters**, or existing users can't log
in. If not, Jitan uses Argon2id as above. Plaintext is not an option either way.

## CLARIFY-02: What `tblTimeRegType` encodes · `RESOLVED` (2026-10-13, D5b in [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md#decisions-2026-10-1213-storage-and-behaviour))
Ten types: Start/Finish – actual – Geofence/QR/Manual, Start/Finish – rounded, Start/Finish – corrected ([reference_data.sql](reference_data.sql)). Original question:
Roadmap §15 wants both an **event kind** (arrival / departure / break) and a **source**
(geofence / QR / manual). `tblTimeReg` has one type FK plus `timeRegManualEntry`. Do the
seeded type values encode the kind, the source, or both combined (e.g. `QR-In`,
`Geofence-Out`)? Please share the seeded rows.

## CLARIFY-03: Rounding semantics · `RESOLVED` (2026-10-13, D10–D11 in [TIME_ENGINE_ANALYSIS.md](../TIME_ENGINE_ANALYSIS.md#decisions-2026-10-1213-storage-and-behaviour))
Start and finish are separate schedule rows ("Work – start" / "Work – finish"), each with its rule; `roundingRuleValueInMin` = grid (nearest); `roundingRuleRoundUp` = halfway rounds up; `scheduleMarginMin` = tolerance either side, inclusive. Original question:
- Does `roundingRuleRoundUp` decide whether a rule is a **start** rule
  (`false` → 08:03 rounds down to 08:00) or an **end** rule (`true` → 16:22 rounds up to
  16:30)? Or is it a pure direction flag, with start/end decided elsewhere?
- Is `roundingRuleValueInMin` an interval (round to the nearest 15 min) or a window around
  the schedule boundary?
- Is `scheduleMarginMin` the "±15 min" rounding window from §17? Example: arrival within
  the margin of a scheduled start snaps to that start, and outside it the interval rule
  applies.

A worked example from IT for each rule type would settle this.

## CLARIFY-04: `geofenceCorrectionInMin` · `OPEN`
Is it walking time from the geofence edge to the workstation, the short-exit threshold
(GAP-06), a dwell time before arrival counts, or something else?

## CLARIFY-05: `addressCoordinates` format · `RESOLVED` (IT's creation script, 2026-10-13)
`"latitude,longitude"` in decimal degrees with a dot and one comma, e.g. `"50.7436,3.2167"`
(IT's comment on the column). Every geofence evaluation parses it in this format.

## CLARIFY-06: `tblTimeReg.addressID` nullability · `RESOLVED` (IT, 2026-10-09 and 2026-10-13)
**Nullable: yes.** `tblTimeReg.addressID` is `INT NULL`; IT's creation script says it is
NULL for a manual entry without a location. (A QR scan in a van follows the Terminal design,
GAP-09.)

## CLARIFY-07: User language · `RESOLVED` (product decision 2026-10-08)
`tblUserLanguage` allows several languages per user. Decision: **one current preferred
language per user**, changed by updating that row (employee: `PUT /me/language`; HR/Admin:
Manage assignments → Language). No row means English. Several rows are reported as a data
error (409), never silently resolved.

## CLARIFY-08: Translation key uniqueness · `RESOLVED` by ERD.jpg
ERD.jpg marks `(languageID, translationUIName)` as a unique pair (yellow; legend "in same
table, Unique Pair"), so a key appears once per language. Integration tests check it
against whichever database they run on. Jitan still tolerates duplicates (lowest
`translationID` wins, logged) in case a database does not enforce the pair.

## CLARIFY-09: Junction row removal · `RESOLVED` for the schema (IT, 2026-10-08 and 2026-10-09)

**Schema:** every junction table has Active/MFD (approved 2026-10-08, confirmed in IT's
development database 2026-10-09). Removing a link sets `Active = false, MFD = true` (row
kept, audited); re-adding reactivates the same row. A removed link never counts: every read
filters on both columns. Built for `tblUserCompany` and `tblUserGroup` (remove and
re-add), `tblUserCredGroup` (a removed row is not held; granting again reactivates it) and
`tblUserLanguage` (only the current row counts).

**Still open (product and IT), does not block other work:** may HR/Admin *remove* a
credential group (`tblUserCredGroup`) or a function (`tblUserFunction`) through Jitan, and
under which rules (e.g. never the last Admin, never one's own)? Until decided, Jitan only
adds credential groups. Removal of schedule and rounding-rule links (`tblUserSchedule`,
`tblScheduleRoundingRule`) follows the same soft-delete pattern when those screens are
built.

## CLARIFY-10: Authorization model · `OPEN` · IT CLARIFICATION, blocks production authorization only
Does performing a function require **both** module access (via credential group) **and**
a `tblUserFunction` grant, or does a function grant work on its own? Is
`credGroupLevel` used for anything beyond ordering?

**Product decision (2026-10-13):** in V1, **HR and Admin have the same rights**, including
access to **all companies** (not only the ones they are a member of). More
roles may be added later, as rows in `tblCredGroup` with their modules and functions (data,
not code). The production evaluator is still to be built on these tables.

Raised by EMP-07 (2026-10-08), for the production evaluator:

- `tblUserCredGroup` has no company: a credential group applies in **every** company the
  user belongs to. Jitan therefore requires `manageEmployeeAccess` in each of the
  employee's companies before adding one. Is a user-wide role the intended model?
- Which credential groups may an actor grant (e.g. may HR grant Admin)? Is
  `credGroupLevel` a hierarchy, and in which direction? **Interim rule (decision
  2026-10-08, no hierarchy invented):** an actor may grant only credential groups they
  hold themselves, so nobody can give more access than they have or raise their own.
  Every other grant is refused (403) until IT defines the rules.

## CLARIFY-11: Seed data · `OPEN` · IT CLARIFICATION, blocks production authorization only
Please share current rows of `tblCredGroup`, `tblAppModules`, `tblFunction`, `tblGroup`,
`tblScheduleType`, `tblTimeRegType`, `tblLocationType`, `tblEventType`, `tblDays`,
`tblLanguage`. Jitan reads these from the database and must not invent values.

**Audit event types.** Every audited change writes a `tblEventLog` row and links it to the
`tblEventType` row whose `eventTypeName` equals the code-side name (`AuditEventType` in
`server/jitan_api/lib/src/audit/audit_event.dart`), e.g. `employee.created`. Until such a
row exists, the event is stored **without** a type link and a warning is logged. Either
IT adds rows with these names, or the code adopts IT's names; nothing else changes.
Names in use: `employee.created`, `employee.onboarding.completed`,
`employee.password.changed`, `employee.access.reset`, `employee.access.recovered`,
`employee.onboarding_qr.generated`, `employee.recovery_qr.generated`,
`employee.company.assigned`, `employee.company.removed`, `employee.group.assigned`,
`employee.group.removed`, `employee.credential_group.assigned`,
`employee.language.changed`. (`employee.personal_qr.generated` is no longer written: the
permanent QR is no longer shown to HR/Admin.) **These need rows in
IT's `tblEventType`.** Jitan looks them up by name and never assumes an ID; the IDs in
`dev/local-db/seed.sql` exist only in the disposable local database.
Recovery after a reset has its own endpoints and event (`employee.access.recovered`).

## CLARIFY-12: Personal QR value (`tblUser.userQRcode`) · `OPEN` · IT CLARIFICATION, does not block development
Since 2026-10-08 this is the **Terminal QR only** (onboarding and recovery use temporary
QRs, GAP-04).
`userQRcode` is unique and is filled when an employee is created (EMP-02). Jitan
generates 18 cryptographically random bytes, base64url-encoded to **24 characters**, so
one employee's QR reveals nothing about another's. Questions for IT: does an existing
system expect a specific format or length for this column? (Maximum length: answered by
IT's database, `VARCHAR(255)` NULL, unique.) If the format must change, codes can be
regenerated: no QR has been issued yet.

## CLARIFY-13: Onboarding vs recovery state · `OPEN` · IT CLARIFICATION (decided interim rule, safe)

Onboarding and recovery both set `userPassword`, but must stay separate operations, and an
account without a password may only recover after an HR-authorized reset. `tblUser` has no
column saying *why* a password is NULL (never activated vs reset). The persisted record of
an HR/Admin reset is its `employee.access.reset` row in `tblEventLog`, written in the same
transaction that clears the password. Jitan therefore derives the state from the newest of
the user's `employee.onboarding.completed` / `employee.access.reset` /
`employee.access.recovered` events (`AccountSetupRules`):

| `userPassword` | Newest access event | State | Allowed |
|---|---|---|---|
| set | any | activated | neither (sign-in, change password) |
| NULL | none | never activated | **onboarding only** (onboarding QR) |
| NULL | `employee.access.reset` | reset pending | **recovery only** (recovery QR) |
| NULL | onboarding / recovery | unexplained (cleared outside Jitan) | neither: HR/Admin and IT must look |

Checked when HR/Admin generates a QR, when a QR is scanned, and again under the row lock
when the password is stored. **Dependency:** the rule needs the `tblEventType` rows of
CLARIFY-11. Without them no event has a type: recovery is then refused (fails closed) and a
reset employee looks "never activated". Questions for IT: is reading the audit trail for
this acceptable, or should a column record the reset state?

## CLARIFY-14: Which ERD version is authoritative · `RESOLVED` (IT's database, 2026-10-09)

A newer diagram was reported to add `tblSchedule.companyID` and
`tblUserSchedule.userCompanyID`. IT's development database (inspected 2026-10-09) has
**neither**: `tblSchedule` and `tblUserSchedule` match `ERD.jpg`, plus Active/MFD on
`tblUserSchedule`. **Decision: schedules are global and reusable, and a schedule assignment
is user-wide** (it applies in every company the employee works for). The schedules module
is not company-scoped through these tables. If company-specific schedules are needed
later, that is a schema change for IT to approve (see GAP-03 for registrations).
`ERD.jpg` stays the logical reference; the physical schema (types, lengths, defaults,
junction Active/MFD) is IT's database, mirrored in `dev/local-db/schema.sql`.
