# ERD Gaps & Clarifications

Jitan requirements that the fixed ERD ([ERD.md](ERD.md)) cannot represent cleanly, per the
**ERD Gap Policy**. Nothing here gets implemented as a workaround. Each item waits for IT.

Two kinds of entry:

- **GAP**: structural. The information or relationship has no place in the schema.
- **CLARIFY**: the schema probably covers it, but the intended meaning of a field must be
  confirmed before code depends on it.

Status values: `OPEN` · `RESOLVED (date, decision)` · `WITHDRAWN (reason)`

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
| Employees: list (Figma `153:137`) | PRODUCT-CLARIFY-EMPLOYEES-LIST (company context, Type, Policy), GAP-11 (Location), GAP-04 (Onboarding column) |
| Employee onboarding (**Milestone 1**) | GAP-04 |
| Employee Web QR login, privacy screens | GAP-05 |
| Core time engine | GAP-01, GAP-02, CLARIFY-02 |
| Geofencing | GAP-06, CLARIFY-04, CLARIFY-05 |
| Rounding (**Milestone 2**) | GAP-01, CLARIFY-03 |
| Registration method choice | GAP-07 |
| Time Records / Reports per company | GAP-03 |
| Exceptions | GAP-08 |
| Terminal | GAP-09 |
| Visitors | GAP-10 |

**Milestone 1 needs GAP-03 (primary workplace) and GAP-04 (onboarding QR) resolved.**
CLARIFY-01 (password hashing) is needed before production, not before development.
Everything else in Milestone 1 maps cleanly.

---

## Resolved without a gap

Recorded so they aren't raised again.

| Requirement | Maps to |
|---|---|
| Employee type (§7) | `tblGroup` via `tblUserGroup`: Blue collar / White collar |
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
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

1. **Requirement** (§16, §17, §23, §33, §34): every registration keeps the **actual**
   detected time (08:03) and the **registered** time (08:00) after rounding. The actual
   time is never overwritten. HR corrections preserve original and corrected values.
2. **Considered:** `tblTimeReg.timeRegTimestamp`, `timeRegWhenModified`,
   `timeRegManualEntry`, `timeRegComment`; `tblEventLog.timeRegID`.
3. **Why not:** `tblTimeReg` has **one** timestamp. `timeRegWhenModified` records *when* a
   row changed, not its previous value. `tblEventLog` can point at the `timeRegID` but has
   no column for old/new values.
4. **Missing:** a place for the registered time, or a confirmed rule that it is never
   stored. Questions for IT:
   - Is `timeRegTimestamp` the **actual** time, with registered time always computed at
     read time from `tblUserSchedule → tblSchedule → tblScheduleRoundingRule`?
   - If so: `tblUserSchedule` and `tblScheduleRoundingRule` have no effective dates. If a
     schedule or rule changes, historical registered times and past reports change too.
     Is that acceptable?
   - When HR corrects a registration, is the intended pattern to insert a new
     `tblTimeReg` row (`timeRegManualEntry = true`) and set the original
     `timeRegActive = false`, keeping both?
   - In an HR correction, is the value HR enters an *actual* time (still to be rounded)
     or a final *registered* time?

## GAP-02: Company timezone and country
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

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
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

1. **Requirement** (§6, §30, §32, §36): a primary workplace is configured during company
   creation. HR manages Locations per company. Time Records and Reports filter and total
   **per company**.
2. **Considered:** `tblAddress`, `tblAddressLocationType`, `tblLocationType`,
   `tblGeofenceAddress`, `tblUserCompany`, `tblTimeReg.addressID`.
3. **Why not:** no table links an address to a company. `tblUserCompany` links the *user*
   to companies, not individual registrations. For an employee in both Almeco and PCA,
   nothing says which company a given `tblTimeReg` row counts for, because the address
   would have told us and it has no company.
4. **Missing:**
   - an address → company relationship
   - which address is a company's *primary* workplace
   - for multi-company employees, how a registration is attributed to a company. Related:
     should their schedules differ per company? `tblUserSchedule` has no company.

## GAP-04: Employee onboarding QR
**ERD GAP — requires clarification with IT.** · Status: `OPEN` · **Blocks Milestone 1**

1. **Requirement** (§9, §11): HR generates an onboarding QR. It is employee-specific,
   **temporary**, **one-time use**, and **invalidated after activation**.
2. **Considered:** `tblUser.userQRcode`, `userPINCode`, `userPassword`, `userActive`.
3. **Why not:** `userQRcode` is the **permanent personal QR** (UK) used at terminals, so
   using it for onboarding would make the onboarding code permanent and reusable. No field
   stores an expiry, a used/invalidated flag, or an "activated" state that is separate from
   HR's `userActive`.
4. **Missing:** onboarding token, expiry, used flag, activation state. Question for IT: is
   "activated" meant to be inferred from something existing (e.g. `userPassword` being
   set)? If so, a signed, expiring token that is refused once a password exists would need
   no schema change. **This is a design choice that needs approval, not a default.**

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

## GAP-08: Exception state and correction requests
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

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

## GAP-10: Visitors
**ERD GAP — requires clarification with IT.** · Status: `OPEN`

1. **Requirement** (§29): visitor name, phone, person to meet, number plate, optional
   company, face photo, arrival and departure.
2. **Considered:** `tblUser`, `tblTimeReg`, `tblCompany`.
3. **Why not:** visitors are not users. Storing them as `tblUser` rows would mix them into
   employee lists and give them login fields. Nothing holds a number plate, photo, host or
   visit.
4. **Missing:** the entire visitor concept.

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

---

# Clarifications

## CLARIFY-01: Password and PIN hashing · `OPEN` · IT CLARIFICATION, blocks production auth only
Is anything else already writing or reading `tblUser.userPassword` / `userPINCode`? If so,
Jitan must use **the same hashing algorithm and parameters**, or existing users can't log
in. If not, Jitan will use a modern algorithm (argon2id or bcrypt). Plaintext is not an
option either way.

## CLARIFY-02: What `tblTimeRegType` encodes · `OPEN`
Roadmap §15 wants both an **event kind** (arrival / departure / break) and a **source**
(geofence / QR / manual). `tblTimeReg` has one type FK plus `timeRegManualEntry`. Do the
seeded type values encode the kind, the source, or both combined (e.g. `QR-In`,
`Geofence-Out`)? Please share the seeded rows.

## CLARIFY-03: Rounding semantics · `OPEN`
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

## CLARIFY-05: `addressCoordinates` format · `OPEN`
Exact string format (`"50.7436,3.2165"`? `"lat;lng"`? WKT?), and whether existing rows
already follow it. Every geofence evaluation parses it.

## CLARIFY-06: `tblTimeReg.addressID` nullability · `OPEN`
What address does a manual entry, or a QR scan in a van, carry? Is the column nullable?

## CLARIFY-07: User language · `OPEN`
`tblUserLanguage` allows several languages per user. Is the rule one row per user (the
selected language), with the fallback being a system default? Or are several rows
ranked somehow?

## CLARIFY-08: Translation key uniqueness · `OPEN`
`(languageID, translationUIName)` is not marked unique. Should Jitan treat duplicates as
an error, or take the lowest `translationID`?

## CLARIFY-09: Junction row removal · `OPEN`
Junction tables have no Active/MFD. Does removing an assignment (e.g. an employee leaving
a group) physically delete the junction row, with the change preserved in
`tblEventLog`? Or should junction rows never be deleted?

## CLARIFY-10: Authorization model · `OPEN` · IT CLARIFICATION, blocks production authorization only
Does performing a function require **both** module access (via credential group) **and**
a `tblUserFunction` grant, or does a function grant work on its own? Is
`credGroupLevel` used for anything beyond ordering?

## CLARIFY-11: Seed data · `OPEN` · IT CLARIFICATION, blocks production authorization only
Please share current rows of `tblCredGroup`, `tblAppModules`, `tblFunction`, `tblGroup`,
`tblScheduleType`, `tblTimeRegType`, `tblLocationType`, `tblEventType`, `tblDays`,
`tblLanguage`. Jitan reads these from the database and must not invent values.
