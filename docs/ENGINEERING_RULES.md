# Jitan Engineering Rules

**Never optimize for finishing a ticket quickly at the cost of architectural correctness. A smaller feature completed end-to-end is preferred over a larger feature implemented with shortcuts.**

These rules are mandatory for all implementation work.

## 0. Keep moving: classify uncertainty, don't stall

Nothing should block progress unnecessarily. Unresolved production details (final login,
password hashing, production permissions, real data, credentials, integrations) do **not**
stop development. Use safe, development-only substitutes and continue.

Stop work on a **specific feature** only when continuing would corrupt the architecture,
misuse the fixed ERD, require inventing a business rule, require an irreversible wrong
assumption, or require data the ERD cannot represent. Even then, stop only that feature,
document it, and continue with unrelated work.

### Classifying an issue

| Class | Meaning | Action |
|---|---|---|
| **DEV TEMPORARY** | A safe development substitute exists (test user, test company, dev identity, mock external adapter) | Use it, isolated from production. Continue. |
| **PRODUCT CLARIFICATION** | Product behaviour is undefined | Stop only that behaviour. Record it in [PRODUCT_CLARIFICATIONS.md](PRODUCT_CLARIFICATIONS.md). Continue elsewhere. |
| **IT CLARIFICATION** | Production infrastructure/configuration/authorization detail missing | Use a dev substitute where safe. Record it in [database/ERD_GAPS.md](database/ERD_GAPS.md). Continue. |
| **ERD GAP** | The fixed database cannot represent the requirement | No workaround. Stop only that part. Record it in [database/ERD_GAPS.md](database/ERD_GAPS.md). Continue elsewhere. |

### Development data is allowed

Fake/test records (users, companies, groups, schedules, registrations, addresses,
geofences, …) may be inserted into a **development/test database**.

- They are clearly identifiable as development data (e.g. names prefixed `[DEV]`).
- Production code never depends on a specific fake record.
- Automated tests create deterministic fixtures and remove them or roll them back afterwards.
- Fake credentials or secrets never go in production configuration.

The rule against hardcoded data (§3) means: **do not hardcode business data into
production application behaviour.** It does not forbid development fixtures.

### Development identity

Until final authentication is built, a development-only identity mechanism supplies the
acting user. It must:

- work only when the environment is `development` or `test`
- be impossible to enable accidentally in production (the server refuses to start)
- produce the **same** request identity that real authentication will produce later
- be easy to disable and remove, with no endpoint redesign needed
- bypass nothing except authentication itself

Final authentication (login UI, password verification, sessions/tokens, middleware,
permission evaluation, logout, expiry, secure production configuration) is still
required before production. It just doesn't gate feature work now.

Production permissions are not invented. Development uses an explicitly dev-only
permission evaluator. The real evaluator, built on the ERD's credential-group / module /
function model, plugs into the same interface later.

## 1. One file, one responsibility

Each file must have one clear responsibility.

Do not create large files that mix:
- UI
- business logic
- API calls
- database mapping
- validation
- state management
- platform-specific code

Examples:

Good:
- `employee_repository.dart`
- `employee_service.dart`
- `employee_model.dart`
- `employee_screen.dart`
- `employee_controller.dart`

Bad:
- `employee.dart` containing UI, API calls, parsing, validation, and business rules together.

If a file starts handling multiple unrelated responsibilities, split it.

---

## 2. Implement every feature end-to-end

A feature is not complete because the UI exists.

Every feature must be implemented through the complete path where applicable:

```text
User interface
→ state/controller
→ API client
→ backend route
→ service/business logic
→ repository/data access
→ database
→ response
→ UI state
→ error handling
→ audit logging where required
```

Do not create fake completion by implementing only one layer.

For example:

"Add employee" is not complete until:

1. The form exists.
2. Client validation exists.
3. The Flutter app sends the request.
4. The backend endpoint exists.
5. Authorization is checked.
6. Business validation is performed.
7. The correct existing ERD tables are used.
8. The employee is written successfully.
9. Required relationships are created.
10. The event is logged.
11. Errors are returned correctly.
12. The UI shows success/error states.
13. The employee list reflects the change.

---

## 3. No shortcuts

Do not use temporary shortcuts that become hidden architecture.

Forbidden examples:

- hardcoded employees
- hardcoded companies
- hardcoded roles
- hardcoded schedules
- hardcoded translation strings where the DB translation system should be used
- mock API responses in production code
- local-only state pretending to be persisted
- bypassing the backend and connecting Flutter directly to MySQL
- storing business rules only in the UI
- duplicating backend rules in several clients
- silently creating fallback logic because the ERD lacks something
- using an unrelated database field because it is "close enough"
- adding TODO implementations and treating the feature as complete

If something cannot be implemented correctly, stop and report the blocker.

Temporary development mechanisms (§0) are allowed only when explicitly isolated from
production. "Hardcoded" here means hardcoded into production behaviour. Development
fixtures in a dev/test database are fine.

---

## 4. The ERD is fixed

The existing database ERD is the source of truth.

Do not:
- create tables
- add columns
- rename columns
- remove columns
- repurpose existing columns
- invent relationships
- generate migrations that alter the ERD

unless explicitly approved after discussion with IT.

If a required concept cannot be represented:

`ERD GAP — requires clarification with IT`

Document:
- the requirement
- affected feature
- tables inspected
- why the existing schema is insufficient
- what information or relationship is missing

Do not hide an ERD gap in backend code.

---

## 5. Use the ERD semantically, not just structurally

Understand what each table means before using it.

Current known meanings include:

- `tblGroup` = employee grouping/category, e.g. Blue collar / White collar
- `tblCredGroup` = access/credential group, e.g. Employee / HR / Admin
- `tblFunction` = specific user capability
- `tblScheduleType` = type of schedule period
- `tblSchedule` = reusable/global schedule period
- `tblUserSchedule` = schedule assigned to user
- `tblUserCompany` = user/company membership
- `tblTimeReg` = time registration records
- `tblRoundingRule` = rounding rules
- `tblScheduleRoundingRule` = schedule ↔ rounding rule relationship

Do not reinterpret these concepts to make implementation easier.

---

## 6. Backend is authoritative

Flutter clients must never be the authority for:

- working-time calculations
- rounding
- authorization
- schedule interpretation
- permissions
- time-registration validation
- correction approval
- audit decisions

The backend is the authoritative source.

Clients may display and collect information, but important business decisions must be validated server-side.

---

## 7. Flutter must never connect directly to MySQL

Architecture:

```text
Flutter apps
→ HTTPS API
→ Dart backend
→ MySQL
```

Never:

```text
Flutter
→ MySQL
```

Database credentials must never exist in mobile, web, or terminal Flutter builds.

---

## 8. Business logic belongs in one canonical place

A rule must not be implemented differently in:

- employee mobile
- employee web
- HR/Admin web
- terminal

If all clients need the same rule, implement the authoritative rule in the backend.

For example:

Bad:

Employee app calculates rounded time one way.
Admin app calculates it another way.

Good:

Backend calculates registered time once.
All clients display the backend result.

---

## 9. Preserve actual and registered time separately

Never overwrite the real observed timestamp with the rounded value.

Conceptually preserve:

- actual/detected time
- registered/rounded time

Rounding must not destroy source data.

Historical information must remain auditable.

---

## 10. Never invent observed facts

For geofencing and automatic registration:

Do not infer:
- lunch
- travel destination
- personal reason
- customer/project
- break type

unless Jitan has reliable information from:
- the employee
- a trusted system
- an explicitly configured location/source

Observed facts and interpreted facts must remain distinguishable.

---

## 11. Audit important changes

Important mutations must use the existing event-log architecture where applicable.

Examples:

- employee creation
- employee changes
- schedule changes
- time corrections
- role/access changes
- group changes
- geofence changes
- manual time entries
- exception resolution

Do not implement a second unofficial audit system.

---

## 12. Soft deletion means soft deletion

Respect:

- `...Active`
- `...MFD`

`MFD = Marked For Deletion`

Do not physically delete records where the ERD is designed for soft deletion.

Normal application queries should respect the intended Active/MFD state.

Historical/audit references must remain valid.

---

## 13. No duplicate domain models without reason

Shared concepts must live in shared packages.

For example:

- User
- Company
- Schedule
- Time registration
- API response models
- validation primitives

should not be independently redefined in every Flutter application.

Use the shared package structure.

Example:

```text
apps/
  employee_mobile/
  employee_web/
  admin_web/
  terminal/

packages/
  jitan_ui/
  jitan_models/
  jitan_api_client/
  jitan_core/

server/
  jitan_api/
```

---

## 14. Shared UI belongs in shared UI components

Do not rebuild the same:

- button
- input
- modal
- badge
- table
- loading state
- error state
- confirmation dialog

independently across applications.

If the design is shared, create a reusable component.

Application-specific screens can compose those shared components.

---

## 15. Do not over-abstract

Reuse is required, but abstraction must have a real purpose.

Do not create:
- generic factory systems
- unnecessary interfaces
- abstract classes with only one implementation
- deeply nested architecture purely for "clean code"

Prefer the simplest structure that keeps responsibilities clear.

---

## 16. Use clear naming

Names should describe domain meaning.

Good:

- `TimeRegistrationRepository`
- `ScheduleService`
- `EmployeeController`
- `RoundingCalculator`

Bad:

- `Manager`
- `Helper`
- `Utils2`
- `CommonService`
- `ThingHandler`

Avoid vague catch-all files such as:

`utils.dart`

unless they contain truly generic, tightly related utilities.

---

## 17. No magic values

Do not scatter values such as:

- 50 meter geofence radius
- 15 minute rounding
- 30 minute break
- 45 minute break
- 1 hour short-exit threshold
- role names

through the code.

If data exists in the database, read it from the database.

If it is a product constant, define it once in the appropriate configuration/domain location.

---

## 18. Do not hardcode role behavior by visible role name

Do not build authorization like:

`if role == "Admin"`

when the ERD provides credential groups, modules, and functions.

Authorization should use the existing permission model.

UI labels may say Admin or HR, but access checks should follow the backend authorization model.

---

## 19. Validate on both boundaries

Client-side validation improves UX.

Backend validation protects correctness.

Always validate important requests server-side even if Flutter has already validated them.

Examples:
- required fields
- time ranges
- user existence
- permissions
- active/MFD state
- duplicate relationships
- schedule validity

---

## 20. Fail explicitly

Never silently recover from invalid data in a way that changes business meaning.

Bad:

"If schedule missing, use 08:00–16:30."

Good:

Return a clear configuration error and log/report the issue.

Likewise, never silently select:
- the first company
- the first schedule
- the first role
- the first location

when multiple possibilities exist.

---

## 21. No fake success states

Do not show success before the authoritative operation succeeds.

Examples:

- employee created
- time corrected
- terminal paired
- schedule updated

The backend must confirm success first.

Optimistic UI may only be used where rollback behavior is explicitly designed.

---

## 22. Every API endpoint must have complete behavior

Each endpoint should include, where relevant:

- authentication
- authorization
- request validation
- business validation
- repository/data access
- transactions where needed
- event logging
- structured errors
- response models
- tests

Do not create routes that directly contain large amounts of SQL or business logic.

---

## 23. Keep SQL/data access isolated

Database queries should live in repository/data-access code.

Avoid SQL inside:
- API route files
- controllers
- UI code
- model files

This keeps database behavior reviewable and prevents duplication.

---

## 24. Use transactions for multi-step writes

If one logical operation modifies several records, use a DB transaction where consistency requires it.

Example:

Employee creation might involve:
- creating user
- company relationship
- group assignment
- credential assignment
- language assignment
- event log

If part of the operation fails, do not leave the database half-configured.

---

## 25. Idempotency where duplicate actions are dangerous

Protect operations that may be retried because of:

- bad network
- app retry
- double tap
- terminal reconnect

Do not accidentally create duplicate:
- time registrations
- employee relations
- onboarding records
- corrections

Use the ERD's unique constraints and appropriate backend logic.

---

## 26. Offline behaviour must be explicit

Especially for Jitan Terminal and mobile registration.

Never silently behave as if server confirmation happened while offline.

Define:
- what can be queued
- what cannot
- what timestamp is authoritative
- how retries work
- how conflicts are resolved
- how the user sees pending state

---

## 27. Platform-specific code stays isolated

Android/iOS implementation details such as:

- background geofencing
- permissions
- secure storage
- notifications

must not leak throughout shared application code.

Wrap platform-specific functionality behind clear services/interfaces.

---

## 28. Security is not optional

Never:
- log passwords
- log secrets
- expose DB credentials
- return password hashes
- expose unrestricted internal errors
- trust client role claims
- trust client-supplied user IDs without authorization checks

Use environment variables for secrets.

### 28a. Database security and data isolation

Product owner, 2026-10-21. **Priority: prevent SQL injection, unauthorized database
access, and accidental exposure of company or employee information.** Do not assume a
query is secure because it works: verify that user-controlled input cannot alter SQL
execution and that every database operation is authorized.

1. **Prevent SQL injection.** Every value goes in as a bound parameter (`:name`).
   Never concatenate or interpolate user-provided input into SQL. Only fixed strings
   written in the code may be built into a statement: column and table names from
   enums or constants (e.g. `EventLogReference`), filters such as
   `MembershipFilters`, and placeholder lists generated from a count (`:s0, :s1, …`).
   An `IN (…)` list is built from placeholders, never from the values themselves.
2. **Review dynamic SQL.** Any query whose text changes at run time (optional
   conditions, placeholder lists, sort order) must show where each piece comes from;
   none may come from a request. Audit existing queries the same way when they change.
3. **No direct database access.** The database is never reachable from the public
   internet or from a client. Every operation goes through the backend (rule 7).
4. **No data leakage.** API responses never contain database structure, SQL, stack
   traces, credentials, password or PIN hashes, or internal error details; failures
   are mapped to the structured error model. Logs never contain secrets, QR values or
   personal data beyond what is needed.
5. **Company isolation.** A user of one company never reads, changes or receives
   another company's data without explicit authorization. Company-scoped endpoints take
   the company in the path, query only that company and pass it to
   `Authorizer.require(…, companyId:)`; cross-company actions (e.g. adding an employee
   to several companies, group members from every company) check the right in **each**
   company concerned.
6. **Strict access control on the backend.** Authentication, permission and resource
   ownership are checked in the backend before any database operation, never only in
   the UI.
7. **Credentials stay secret.** Passwords, connection strings and secrets never appear
   in frontend or mobile code, logs or the repository; they come from environment
   variables or IT's configuration file.
8. **Encrypted connections.** HTTPS between clients and the API; TLS with certificate
   verification between the API and MySQL (required in production, SEC-01).
9. **Least privilege.** The application's database account has only the rights its
   operations need (SEC-01, to agree with IT).
10. **Test for it.** Before deployment: SQL injection tests (hostile input in every
    text field and search), unauthorized-access tests, and cross-company isolation
    tests.

---

## 29. No destructive changes without explicit approval

The agent may refactor internally when behaviour is preserved.

But do not:
- delete existing features
- redesign database semantics
- change API contracts
- change Figma-approved behaviour
- change product rules

just because another design looks cleaner.

Raise the proposed change first.

---

## 30. Design implementation must match Figma

The approved Figma flows are the product reference for UI/UX. **The ERD comes first:** when
a Figma flow needs data the ERD cannot store, the flow is changed in Figma (decided
2026-10-12), never the database.

**Build exactly what Figma shows, nothing more and nothing less** (product owner,
2026-10-21). Same layout, components, copy, spacing, colours and states as the Figma
frame. Do not add sections, buttons, texts or steps that are not in Figma, and do not
leave out what is there. Do not design from your own head. Before building or changing a
screen, open its Figma frame and compare the result with it side by side. When Figma has
no frame for a needed state, or the frame cannot be built because of the ERD, ask the
product owner first; never fill the gap with your own design.

Do not simplify a complete flow into a generic screen.

Implement:
- loading
- empty
- error
- success
- confirmation
- disabled
- needs-attention
- modal/bottom-sheet
- responsive

states shown or implied by the product flow.

**Responsive before the next phase** (product owner, 2026-10-21). Every page and dialog
must fit well at every width, from a phone (390 px) to a wide screen (2400 px): no
overflow, no horizontal page scroll, no cramped or stretched layout. Cover each page and
its dialogs in `test/app/responsive_test.dart`, and check it in the browser. A phase is
not finished, and the next phase does not start, until its pages pass.

---

## 31. No dead screens

Every implemented screen must be reachable through the intended navigation or flow.

Do not create visual screens that are never wired into the application.

Likewise, navigation buttons must lead to working destinations.

---

## 32. No dead backend endpoints

Do not build endpoints that nothing calls unless they are explicitly part of a staged backend milestone.

If intentionally staged, document the consumer that will use them.

Foundation endpoints such as `/health` and `/health/database` are allowed when documented
as infrastructure that upcoming slices and deployment monitoring depend on.

---

## 33. Finish vertical slices before spreading horizontally

Prefer:

```text
Company list
→ API
→ DB
→ UI
→ errors
→ tests
```

before implementing half of:
- Companies
- Employees
- Schedules
- Reports
- Exceptions

at the same time.

A completed vertical slice is more valuable than five partially connected features.

Foundational infrastructure that later slices require (config, database pool, request
pipeline, identity context, error model) may be built first.

---

## 34. Definition of Done

A feature is only "done" when applicable parts of all of these are complete:

- [ ] Matches the Figma frames exactly, compared side by side (§30)
- [ ] UI implemented
- [ ] Responsive behavior handled: fits from 390 px to 2400 px, covered by the responsive test (§30)
- [ ] State management implemented
- [ ] API integration implemented
- [ ] Backend endpoint implemented
- [ ] Authorization hook in place (dev evaluator now, production evaluator pluggable)
- [ ] Development identity works where auth is not final yet
- [ ] Production auth integration point is preserved
- [ ] Business rules implemented
- [ ] Existing ERD used correctly
- [ ] Database persistence verified
- [ ] Transactions used where required
- [ ] Audit logging implemented where required
- [ ] Error states handled
- [ ] Loading states handled
- [ ] Empty states handled
- [ ] Success state confirmed by backend
- [ ] Soft deletion respected
- [ ] Every query uses bound parameters; no request value is built into SQL (§28a)
- [ ] Company isolation and permissions checked in the backend for every company touched (§28a)
- [ ] No internal detail, hash, secret or other company's data in responses or logs (§28a)
- [ ] No hardcoded production data
- [ ] No production dependency on fake test data
- [ ] No mock implementation remains in the production path
- [ ] Tests added
- [ ] Existing tests pass
- [ ] Relevant documentation updated
- [ ] No unresolved shortcut/TODO hidden in the feature
- [ ] Any unresolved product/IT/ERD issue is explicitly documented

If one of these is intentionally not applicable, that should be clear from the feature design.

---

## 35. Stop instead of guessing

When uncertain about:

- ERD semantics
- a Figma flow
- a product rule
- permission behavior
- rounding
- geofencing
- schedule meaning
- time registration semantics

do not invent a rule.

Report the exact ambiguity and request clarification. Classify it (§0) and stop only the
affected behaviour. Keep building everything that doesn't depend on it.

The goal is not merely to make the application compile.

The goal is to implement Jitan correctly, end-to-end, against the approved architecture, ERD, and product behavior.
