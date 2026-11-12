# Tables and columns proposed to IT

**Status (2026-11-10, D44): nothing is proposed for projects, transport or terminals any
more.** Jitan now runs on IT's ERD of 2026-11-09:

- **Projects** are `tblAddress` rows of the kind "Project location"
  (`tblAddressLocationType`), named "<SAP number> <name>" (D43, D44). A client site has a
  geofence; internal work points at a workshop's coordinates. HR adds them on the Projects
  page until SAP's API delivers them.
- **Activities and transport** are `tblTimeReg` rows of an "Activity – …" type; their
  `addressID` is the project or the place (D19, D22, D44).
- **Terminals** are IT's `tblDevice` (GAP-09).
- The default company is in IT's ERD (`tblUserCompany.userCompanyDefault`).

The local project tables (`tblProject`, `tblUserProject`, `tblProjectType`,
`tblProjectStatus`) and the `tblTimeReg` / `tblEventLog` project and company columns are
gone. What they held and `tblAddress` cannot (a project's company, type, status, dates,
description and assigned employees) is left out of this version; SAP holds it.

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

## Lookup rows

IT adds no rows: Jitan completes the fixed lists itself (D48; before, HR did on the Lists page, D45). For the record,
the activity types are `Activity – Work`, `Activity – Client on site`,
`Activity – Client in-house`, `Activity – Internal` and `Activity – Transport` in
`tblTimeRegType` (D37), and projects need `Project location` in `tblLocationType`.

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
