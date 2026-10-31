# Tables and columns proposed to IT

Jitan needs these to support projects, transport, terminals and visitors. They do not
exist in IT's database. The product owner decided on 2026-10-31 to build on them locally
and ask IT to add them. SQL: [projects_terminals_visitors.sql](../../dev/local-db/proposals/projects_terminals_visitors.sql).

**Status: not yet sent to IT.** They exist only in the local development database.
Features using them are off on IT's database until IT has added them; registering
starts and finishes keeps working there, because the server checks at startup. If IT
prefers another structure, Jitan changes to match.

## Questions for IT

1. Can these be added as written, or do you prefer another structure? You said you would
   update the ERD with projects and default companies (2026-10-13); this may overlap.
2. Should projects be imported from SAP (D21)? How, and which fields does SAP give?
3. Is a terminal meant to be a `tblUser` with `userKioskMode = 1` (GAP-09)? We propose its
   own table, because a user has no type, location, last-seen time or plate number.
4. Should visitor photos be stored in the database, and how long may visitors be kept?
   This is personal data, so a retention period needs deciding.

## New tables

| Table | Purpose | Why existing tables don't fit | Gap / decision |
|---|---|---|---|
| `tblCompanyAddress` | Links an address to a company | Nothing links an address to a company | GAP-03, D36 |
| `tblProject` | A client or internal project of a company: name, reference, status, dates, description, client address, kilometre agreement | No project concept exists | D16, D17, D21, D26 |
| `tblUserProject` | Who is assigned to a project | No link between employees and projects | D16, D27 |
| `tblProjectType` | Lookup: Client, Internal | Lookup values are read from the database, not hardcoded | D17 |
| `tblProjectStatus` | Lookup: Planned, Active, Completed | Same | Figma `647:3452` |
| `tblProjectAgreement` | Lookup: who gets the kilometres (charge the customer, pay the employee, both) | Same | D26 |
| `tblTerminal` | A shared tablet: name, type, company, location or plate number, QR enabled, device, last seen, device secret (hashed) | A kiosk user has no type, location, last seen or plate number | GAP-09, D18, D20 |
| `tblTerminalType` | Lookup: Office, Vehicle | Lookup values are read from the database | Figma `153:1389` |
| `tblVisitor` | One visit: name, phone, person to meet, plate, company, photo, arrival, departure, terminal | Visitors are not users: `tblUser` would mix them into employee lists | GAP-10 |

Terminal pairing codes are temporary, so they stay out of the database, like
temporary QR codes.

## New columns on existing tables

| Column | Purpose | Gap / decision |
|---|---|---|
| `tblUserCompany.userCompanyDefault` | An employee's default company | D16 |
| `tblTimeReg.companyID` | Which company an activity counts for, for people in several companies | GAP-03, D16 |
| `tblTimeReg.projectID` | Which project an activity belongs to | D16, D19 |
| `tblTimeReg.terminalID` | Which terminal took the scan | GAP-09 |
| `tblEventLog.projectID`, `userProjectID`, `terminalID`, `visitorID` | Audit of changes to these, like the existing ID columns | Rule 6 |

## New lookup rows

| Table | Rows | Why |
|---|---|---|
| `tblTimeRegType` | `Activity – Work`, `Activity – Client on site`, `Activity – Client in-house`, `Activity – Internal`, `Activity – Transport` | One row per switch, so Start and Finish rows stay as they are (D37). Transport is recorded but is not working time (D22) |
| `tblEventType` | Event names for the new changes, added as they are built | Audit |

## Already proposed

`tblGroupSchedule` and `tblEventLog.groupScheduleID` (GAP-15), sent to IT on 2026-10-21:
[gap15_group_schedule.sql](../../dev/local-db/proposals/gap15_group_schedule.sql).

## Not needed

Kilometres are calculated, never stored (D23). Reports are calculated when opened (D24).
