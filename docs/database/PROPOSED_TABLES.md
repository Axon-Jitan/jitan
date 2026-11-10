# Tables and columns proposed to IT

Jitan needs these to support projects, transport and terminals. They do not exist in
IT's database. The product owner decided on 2026-10-31 to build on them locally and ask
IT to add them. SQL: [projects_terminals.sql](../../dev/local-db/proposals/projects_terminals.sql).

**Status: not yet sent to IT, and being revised** after IT's ERD of 2026-11-09: terminals are IT's `tblDevice` (GAP-09), the default company is in IT's ERD, projects come live from SAP and are `tblAddress` rows (D43, D44), so the project, terminal and `tblTimeReg` items below are no longer requested. The list is rewritten once IT confirms the ERD is in `jitandev`. They exist only in the local development database.
Features using them are off on IT's database until IT has added them; registering
starts and finishes keeps working there, because the server checks at startup. If IT
prefers another structure, Jitan changes to match.

## Questions for IT (parked)

Product owner, 2026-11-10: Jitan builds on what IT's database allows today, and these
questions wait. Nothing below blocks that work.

1. **Collation.** `jitandev` is `utf8mb4_0900_as_cs`. Jitan handles it itself
   (CLARIFY-16); ask only whether it was a deliberate choice.
2. **Transport.** May a trip be stored as a `tblTimeReg` row of type "Activity – Transport"
   (D22, D40)? HR adds the type in Jitan's Lists page; the question is only whether IT
   agrees with the meaning.
3. **SAP.** How does Jitan's server reach SAP's API for projects, and which fields does it
   return (D43)?
4. **Database certificate.** IT's CA certificate or fingerprint, so the API can verify the
   connection (SEC-01).

## New tables

| Table | Purpose | Why existing tables don't fit | Gap / decision |
|---|---|---|---|
| `tblProject` | A client or internal project of a company: name, reference, status, dates, description, client address | No project concept exists | D16, D17, D21 |
| `tblUserProject` | Who is assigned to a project | No link between employees and projects | D16, D27 |
| `tblProjectType` | Lookup: Client, Internal | Lookup values are read from the database, not hardcoded | D17 |
| `tblProjectStatus` | Lookup: Planned, Active, Completed | Same | Figma `647:3452` |
| `tblTerminal` | A shared tablet: name, type, company, location or plate number, QR enabled, device, last seen, device secret (hashed) | A kiosk user has no type, location, last seen or plate number | GAP-09, D18, D20 |
| `tblTerminalType` | Lookup: Office, Vehicle | Lookup values are read from the database | Figma `153:1389` |

Terminal pairing codes are temporary, so they stay out of the database, like
temporary QR codes.

## New columns on existing tables

| Column | Purpose | Gap / decision |
|---|---|---|
| `tblUserCompany.userCompanyDefault` | An employee's default company | D16 |
| `tblGroup.groupTravelIsWork` | Whether this group's travel counts as working time (White collar yes, Blue collar no) | D39 |
| `tblTimeReg.companyID` | Which company an activity counts for, for people in several companies | GAP-03, D16 |
| `tblTimeReg.projectID` | Which project an activity belongs to | D16, D19 |
| `tblTimeReg.terminalID` | Which terminal took the scan | GAP-09 |
| `tblEventLog.projectID`, `userProjectID`, `terminalID` | Audit of changes to these, like the existing ID columns | Rule 6 |

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
No address-to-company link is asked for (product owner, 2026-11-09): each company has one
workshop, the company of a registration is the employee's choice or default (D16), and
workplaces stay one shared `tblAddress` list (D36).
Visitors are left out of this version (product owner, 2026-11-01, GAP-10). The client
agreement about kilometres comes from SAP (question 2), so no agreement table is asked for.
