# Jitan — Development Roadmap

> Status: source-of-truth roadmap. No calendar dates — ordered by dependency.
> Platform priority: **Android first**, iOS after Android is stable.

## Product Description

**Jitan** is a workforce time-registration platform for white-collar and blue-collar employees.

Tagline: **Time tracking without the tracking.**

Core principle:

> **If Jitan already knows, don't ask the worker.**

Jitan is designed to reduce the amount of manual time registration employees need to perform.

Employees can register work through:

- automatic geofencing
- QR scanning at a Jitan Terminal
- manual time entry or correction

Jitan supports:

- office workers
- field workers
- employees moving between companies or worksites
- workers using company vans
- employees staying at hotels during projects
- shared terminals at offices/workshops/vans
- visitors
- HR/Admin workforce management

### User-facing applications

1. **Employee Android app** — first mobile priority
2. **Employee iOS app** — after Android is stable
3. **Employee Web app**
4. **HR/Admin Web app**
5. **Jitan Terminal** — shared tablet/kiosk

Backend is a separate **Dart backend/API**; **Flutter** is used for the client applications.
Database is **MySQL**, already provided externally.

---

## 1. Technical Architecture

```text
Android / iOS Employee App
Employee Web
HR/Admin Web
Jitan Terminal
        ↓
      HTTPS
        ↓
    Jitan Dart API
        ↓
       MySQL
```

Flutter clients must **never connect directly to MySQL**.

The backend controls:

- authentication
- employee/company access
- QR token generation
- time-registration logic
- geofence processing
- rounding
- work-session calculations
- policies
- exceptions
- audit logging
- reports
- visitor handling

---

## 2. Repository / Project Structure

```text
jitan/
│
├── apps/
│   ├── employee_mobile/
│   ├── employee_web/
│   ├── admin_web/
│   └── terminal/
│
├── packages/
│   ├── jitan_ui/
│   ├── jitan_models/
│   ├── jitan_api_client/
│   └── jitan_core/
│
└── server/
    └── jitan_api/
```

### `apps/employee_mobile`

Flutter mobile application. First target **Android**, then **iOS**. Both share as much Flutter code as possible.

### `apps/employee_web`

Flutter Web application for employees.

### `apps/admin_web`

Single HR/Admin Flutter Web application. HR and Admin use the **same screens for V1**; permissions can differ later.

### `apps/terminal`

Flutter tablet application for:

- employee QR scans
- visitor registration
- visitor check-out

### `packages/jitan_ui`

Shared UI components: buttons, text fields, cards, modals, colors, typography, tables, loaders, dialogs.

### `packages/jitan_models`

Shared models:

```text
User
Company
Address
Geofence
TimeRegistration
Schedule
RoundingRule
Policy
Terminal
Visitor
Event
```

### `packages/jitan_api_client`

Shared API client used by all Flutter applications.

### `packages/jitan_core`

Shared non-authoritative client-side helpers. Final payroll/time calculation is always done by the backend.

---

## 3. Development Phase — Foundation

Get the entire system architecture running before building advanced features.

### Backend foundation

Build the Dart API application with:

- environment configuration
- MySQL connection pool
- JSON serialization
- request validation
- error handling
- logging
- authentication middleware
- authorization middleware
- health endpoints

```text
GET /health
GET /health/database
```

The database health endpoint verifies:

```text
Dart API → MySQL → SELECT 1
```

Then verify a real Jitan query such as:

```text
GET /companies
```

---

## 4. Authentication

### Employee Web login

Primary login:

```text
Employee code
+
Password
```

Example:

```text
SBW
********
```

No employee email is required.

### QR Web login

Alternative login inspired by WhatsApp/GitHub:

```text
Web browser
→ Sign in with Jitan app
→ temporary QR appears
→ employee scans it with authenticated mobile app
→ mobile asks employee to approve browser
→ browser signs in
```

The QR represents the **browser session**, not the employee.

### Password management

Employees can:

- set password during onboarding
- change password
- reset forgotten password

HR/Admin must never see employee passwords. Passwords are securely hashed on the backend.

---

## 5. Companies

HR/Admin can:

- see all companies
- add company
- edit company
- disable company
- soft-delete company

Company fields:

- company name
- country
- timezone

No company code is required.

---

## 6. Primary Workplace + Geofencing

The primary workplace is configured during company creation.

Fields:

- workplace name
- address
- coordinates
- geofence radius

Example:

```text
Almeco office
Mouscron, Belgium
50 m
```

Geofence radius is configurable. UI range approximately:

```text
25 m → 200 m
```

with:

```text
50–100 m recommended
```

Additional workplaces can later be added under **Locations**.

---

## 7. Employee Management

Employees belong to a company.

```text
Disan Ssebowa → Almeco
```

PCA employees must not appear when HR is managing Almeco.

Employee fields:

- first name
- last name
- employee code
- employee type
- location
- work policy
- phone (optional)
- active status

---

## 8. Employee Creation

### Manual

Popup: `Add Employee` with fields.

### Bulk import

Excel / CSV:

```text
Upload → preview → validate → correct errors → import
```

Validation examples:

- duplicate employee code
- missing first name
- unknown policy
- invalid data

---

## 9. Employee Onboarding QR

HR/Admin generates the onboarding QR. The employee **does not generate it**.

```text
HR creates employee
→ HR generates onboarding QR
→ employee opens Jitan
→ scans QR
→ Jitan identifies employee/company
→ onboarding begins
```

The QR is:

- employee-specific
- temporary
- one-time use
- invalidated after activation

---

## 10. Employee Mobile App — Android First

First mobile platform: **Android**. Once Android is stable, produce **iOS** from the same Flutter codebase.

Platform-specific work remains for:

- background location
- permissions
- geofencing
- notifications
- secure storage
- app lifecycle handling

---

## 11. Mobile Onboarding

```text
Welcome
→ scan employee onboarding QR
→ confirm account
→ choose language
→ choose registration method
→ location permission if needed
→ notifications
→ set password
→ ready
```

---

## 12. Language Support

Jitan may eventually support 50+ languages. Schema already has:

```text
tblLanguage
tblTranslation
tblUserLanguage
```

The mobile app should:

- load selected language
- remember user preference
- support fallback language

---

## 13. Registration Methods

- **Automatic** — geofence-based
- **QR** — employee shows personal QR to a Jitan Terminal
- **Manual** — employee enters or corrects times manually

Admin/HR controls which methods are available; the employee chooses among available methods.

---

## 14. Automatic Geofencing

One of the most important parts of Jitan.

```text
Employee enters geofence
→ dwell/accuracy validation
→ Jitan detects arrival
→ work session starts
```

On leaving:

```text
leave geofence
→ do NOT immediately finish work
→ mark temporary away
→ start threshold timer
```

If the employee returns:

```text
return before threshold → continue same work session
```

If the employee enters another recognized work location:

```text
leave Almeco → enter PCA → work session continues
```

If no recognized destination appears and the threshold expires, ask the employee:

```text
Finished work?
Break/personal?
Travelling for work?
Other?
```

---

## 15. Work Session Engine

Jitan must distinguish between a `location session` and a `work session`.
Moving between workplaces must not automatically end the workday.

Backend maintains:

```text
TimeEvent
WorkSession
```

Each event contains:

```text
employee
event type
source
actual timestamp
registered timestamp
location
comment
```

---

## 16. Actual vs Registered Time

Fundamental rule.

```text
Actual arrival:       08:03
Registered start:     08:00

Actual departure:     16:22
Registered finish:    16:30
```

Never overwrite the actual detected time. Keep both.

---

## 17. Rounding Rules

Backend applies schedule-based rounding. Schema contains:

```text
tblRoundingRule
tblScheduleRoundingRule
```

Rules include:

- rounding value in minutes
- round up/down behavior
- schedule relationship

Example:

```text
scheduled start = 08:00
rounding window = ±15 min
```

Arrival `08:03` becomes `08:00` registered, while `08:03` remains in the audit trail.

---

## 18. Schedules

Schema supports:

```text
tblSchedule
tblScheduleType
tblDays
tblUserSchedule
```

Schedules define planned start, planned end, margin, day, schedule type.

These feed planning, rounding, employee calendar and reports.

---

## 19. Policies

Policies combine:

- employee scope
- break duration
- short-exit threshold
- start rounding
- end rounding
- available registration methods

Examples: `Office`, `Field`, `QR-only`.

---

## 20. Employee Home

```text
You're working
Since 08:00
Almeco
Registered today: 4h 18m
```

States: working · temporarily away · needs confirmation · day complete

---

## 21. Employee Personal QR

Every employee has a personal QR, distinct from the onboarding QR and the web-login QR.
Used only for **Jitan Terminal time registration**.

---

## 22. Employee Period / Calendar

Views: `Today`, `Week`, `Month`.

Month calendar states: Worked · Planned · Needs attention.

Employee can click a day to see details.

---

## 23. Missing Time Corrections

Example — missing finish time. Employee enters:

```text
Actual finish
Comment
```

The comment is required or strongly encouraged depending on policy.

```text
Actual finish: 16:22
Comment: Forgot to scan before leaving.
```

Jitan then calculates:

```text
Registered finish: 16:30
```

The comment is preserved in the audit trail.

---

## 24. Employee Web App

- login
- QR browser login
- Home
- My QR
- Period (calendar, day detail, missing-time correction)
- Profile (password/web login, registration method, notifications, privacy, sign out)

---

## 25. Employee Privacy / Security

Employee can manage:

- registration method
- active web sessions
- trusted devices
- data export request
- privacy notice

These open as modals.

---

## 26. Jitan Terminal

Shared tablet application supporting two user types:

```text
Employees
Visitors
```

---

## 27. Employee Terminal Flow

```text
Welcome
→ I am an employee
→ scan employee personal QR
```

Successful outcomes: `Checked in`, `Checked out`.

Grouped errors:

- Couldn't read QR
- Employee account problem
- Already registered
- Registration not allowed
- Terminal/network problem

---

## 28. Terminal Management

HR/Admin manages terminal devices.

Terminal types: `Office`, `Vehicle`.

Examples: `Almeco Reception`, `Workshop Entrance`, `Van 01`, `Van 02`.

Fields:

- terminal name
- type
- company
- location or vehicle
- online/offline
- last seen
- QR enabled
- pairing code

---

## 29. Visitors

Visitor fields:

- full name
- phone number
- person to meet
- number plate
- company (optional)
- face photo
- arrival time
- departure time

```text
Visitor registration → photo → check in → success
Visitor check-out → identify visit → check out
```

---

## 30. HR/Admin Web

HR and Admin use the same screens for V1.

```text
Dashboard
Companies
Employees
Locations
Terminals
Policies
Time Records
Exceptions
Reports
```

---

## 31. Dashboard

- companies
- employees
- terminals
- needs attention
- employees working now
- not started
- finished
- temporarily away
- onboarding progress
- terminal status
- recent activity
- system health

---

## 32. Time Records

Columns: employee · date · registered time · actual time · total hours · source · status

Filters: company · employee · period · status

---

## 33. Day Detail

```text
Actual event timeline
Registered timeline
Rounding
Source
Location
```

Example:

```text
07:58 arrival
08:00 registered start

16:31 departure
16:30 registered finish
```

---

## 34. Corrections

HR/Admin can correct a time record. A correction requires a `comment` and preserves:

```text
original values
corrected values
who changed it
when
```

---

## 35. Exceptions

Types: missing start · missing end · unfinished workday · conflicting registration · correction request

States: open · pending · resolved

HR can: resolve · dismiss · open day · set missing time

---

## 36. Reports

- registered hours
- planned hours
- overtime
- needs review
- company totals
- attendance
- weekly totals

Exports: `CSV`, `Excel`

---

## 37. Event Logging / Audit

Use the flexible `tblEventLog` to record important actions:

- company created
- employee created
- policy changed
- employee activated
- time corrected
- exception resolved
- schedule changed
- user/company relationship changed

---

## 38. Active + MFD

For master/configuration data:

```text
Active
MFD
```

MFD = **Marked For Deletion**.

```text
MFD = false → normal record
MFD = true  → hidden from Jitan UI, still retained in database
```

No physical SQL delete for normal business objects.

---

## 39. Android Development Priority

Build and validate before iOS:

- background location
- geofencing
- permissions
- notification handling
- app resume/background behavior
- secure token storage
- battery behavior

Android is the reference mobile implementation.

---

## 40. iOS Phase

Once Android behavior is stable:

- configure iOS project
- permissions
- background location
- notification permissions
- secure Keychain storage
- geofencing behavior
- App Store signing/build setup

UI code is largely shared.

---

## 41. Offline Handling

Mobile and Terminal tolerate temporary connectivity loss.

```text
record event locally → queue it → sync when internet returns
```

Local storage: SQLite. Store:

- employee identity
- current policy
- geofences
- current work session
- unsynced events

---

## 42. Backend API Modules

```text
auth/
companies/
employees/
onboarding/
devices/
languages/
locations/
geofences/
schedules/
policies/
time_registration/
work_sessions/
terminals/
visitors/
exceptions/
reports/
events/
```

Each module contains:

```text
controller / endpoint
service
repository
models
validation
```

---

## 43. Deployment

Development does not require Docker. Production can also run without Docker.

```text
Hyper-V
↓
Linux VM
↓
Nginx
↓
Dart backend
+
Flutter Web builds
↓
MySQL
```

The Dart API runs as a Linux `systemd` service.

Nginx handles HTTPS, Flutter Web, and API reverse proxying.

---

## 44. Recommended Development Order

```text
Foundation
↓
Database connectivity
↓
Authentication
↓
Companies
↓
Employees
↓
Employee onboarding
↓
Android mobile
↓
Employee Web authentication
↓
Core time engine
↓
QR registration
↓
Geofencing
↓
Schedules
↓
Policies
↓
Rounding
↓
Employee Home
↓
Period/calendar
↓
HR Time Records
↓
Corrections
↓
Exceptions
↓
Terminal
↓
Visitors
↓
Reports
↓
Dashboard
↓
iOS
↓
QA
↓
Deployment
```

The **core time engine, rounding and audit trail** receive the most careful testing, even where AI generates much of the implementation.

### Milestones

**Milestone 1**

> HR creates company → adds employee → generates QR → Android employee activates Jitan → sets password → logs into Employee Web.

**Milestone 2**

> Employee arrives/leaves → Jitan detects it → work session is calculated → rounding is applied correctly.

**MVP (final)**

> Android + Employee Web + HR/Admin + Terminal + Visitors + Reports all work end-to-end.
