# Time-registration engine: requirements vs the ERD

Analysis of 2026-10-08, updated 2026-10-13 with the storage decisions (D1–D16). Sources: the agreed rounding
requirements, ROADMAP §15–19 and §23, Figma `HR / Policies` (`215:28` Rounding interval
options, `216:*` Effective date / Scheduled change), [ERD.jpg](database/ERD.jpg),
[ERD.md](database/ERD.md) and [ERD_GAPS.md](database/ERD_GAPS.md).

## ERD version check (resolved 2026-10-09)

A newer diagram was reported to add `tblSchedule.companyID` and
`tblUserSchedule.userCompanyID`. IT's development database has **neither** (CLARIFY-14
resolved): **schedules are global and reusable, and a schedule assignment is user-wide**,
applying in every company the employee works for. All junction tables, including
`tblUserSchedule` and `tblScheduleRoundingRule`, have Active/MFD.

## Confirmed product requirements

These are decided (product, 2026-10-08 and 2026-10-12). They say **what** Jitan must do;
**how** the fixed database stores each one is a separate question, listed under
"Database implementation questions for IT" below.

**Rounding**

1. Start and finish rounding are **configured separately**.
2. **Actual registration times are always preserved**; a rounded value never overwrites
   them.
3. **Historical approved records never change** when rounding policies change.
4. HR/Admin can **schedule when a new policy becomes effective** (for the MVP, changes apply
   immediately: D12).
5. Scheduled-time tolerance is **inclusive** (±15 min around 08:00 includes 07:45 and 08:15)
   and belongs to the **schedule** (`tblSchedule.scheduleMarginMin`, product decision
   2026-10-08; IT still to confirm the column's meaning, CLARIFY-03).
6. Rounding applies the same way to geofencing, Terminal QR and manual registration.

**Breaks**

7. HR/Admin **configure break durations**; nothing is hardcoded. Examples: White collar
   45 minutes, Blue collar 30 minutes.
8. Breaks use the existing schedule types (`tblScheduleType`, e.g. "Break") **where the ERD
   supports it**.

**Time corrections**

9. HR/Admin correct registrations **directly from Time records**: missing or incorrect
   start and finish times.
10. **A reason is required** for every correction.
11. **The original registration data is preserved.**
12. **Every correction is audited.**
13. Resolving an issue in Time records **also resolves the corresponding exception** (there is
    no separate Exceptions screen: D14).

**Database restrictions**

14. The existing ERD and IT's database schema are not changed. No columns, tables or
    relationships are invented.
15. Anything the existing schema cannot support is **discussed with IT first**, and is not
    built until IT confirms how it is stored.

**Status:** the pure rounding calculation is built and tested
(`server/jitan_api/lib/src/time_registration/rounding/`). Nothing is stored or read for it
yet. How everything is stored is now decided (D1–D16 below); corrections, breaks per group
and registration storage are **not built yet**.

## Decisions 2026-10-12/13 (storage and behaviour)

Decided by the product owner after talking with IT, question by question. They say how
the requirements above are stored **in the existing ERD**; nothing here adds a table or
column. The ERD comes first: where Figma asks for something the ERD can't store, Figma
changes.

| # | Topic | Decision |
|---|---|---|
| D1 | ERD | The ERD is complete. What it doesn't hold is either not needed or asked of IT. There is no policy table and none is needed: HR creates **schedules** (the word "policy" is dropped). |
| D2 | Schedules per group | Schedules are set **per employee group**, never per employee. An employee gets their group's schedules as `tblUserSchedule` rows. A group's schedules are the ones its members have who are **only in that group** (D3b). A new member gets them copied from those members. |
| D2b | How a save is stored (2026-10-20) | Saving a group's work hours or breaks creates **fresh** `tblSchedule` rows (each day: a "Work – start" and a "Work – finish" row, both holding the day's window, e.g. 08:00–16:30, with their own tolerance and rounding rule; a break row holds its usual start and end) and gives them to the employees only in the group **and** to employees in several groups whose current schedule of that kind is the group's (they follow it). Old links and rows nobody uses are switched off (`Active = 0, MFD = 1`), never changed or deleted. Saving identical values changes nothing. Each created or switched-off row is audited (`schedule.created`, `schedule.deactivated`). |
| D2d | Schedules follow group changes (2026-10-20) | After every change of an employee's groups (Manage assignments, or Add employee with a group): **one group**: the employee gets that group's schedule (what its other employees only in it have; when those differ nothing is picked and the employee keeps what they had); **no group**: no schedule; **several groups**: the schedule is kept while it still belongs to one of them, otherwise switched off and HR chooses with **"Schedules come from"** (`…/assignments/schedule-source`, audited `employee.schedule_source.changed`). Returning to a schedule reactivates the old link. Known narrow race: assignment transactions lock only the employee row (DB-DRIVER-01), so a group schedule saved at the same moment may leave a new member on the previous rows until the next save. |
| D2e | V1 limits accepted (2026-10-21) | For the first version a group's schedule stays **derived from its employees** (D2). Accepted limits: an empty group can't hold a schedule ("Add an employee who is only in Drivers first"); differing employees are shown, not guessed; a group saved at the exact moment someone joins may leave that person on the previous rows until the next save. Later option (not V1): read the group of each schedule row from the `schedule.created` events in `tblEventLog` (`groupID` + `scheduleID`), which needs IT to confirm event-log rows are never deleted. |
| D2c | Empty group | HR can link a schedule to a group only when the group has at least one member who is only in that group ("Add an employee who is only in Blue collar first"). |
| D3 | Several groups | An employee may be in several groups, but their schedules come from **one** of them, chosen by HR. |
| D3b | Finding a group's schedules | Only members who are in that group **alone** count. A group whose members are all also in other groups is treated as empty. |
| D4 | Actual and rounded time | Every registration is stored as **two `tblTimeReg` rows**, told apart by type: the actual time (never changed) and the rounded time. Approved records therefore keep their rounded time when a rule changes later. |
| D5 | Registration method | Each employee uses one method (geofence or Terminal QR), and can also register **manually** in the app, with a reason. The method is part of the "actual" type. |
| D5b | Registration types | `tblTimeRegType` rows: Start/Finish – actual – Geofence/QR/Manual (6), Start/Finish – rounded (2), Start/Finish – corrected (2). Listed in [reference_data.sql](database/reference_data.sql). |
| D6 | Reason | Every time entered by hand (by the employee or by HR) has `timeRegManualEntry = 1` and a **required** reason in `timeRegComment` (max 500 characters). |
| D7 | HR corrections are rounded | HR's corrected time is treated as an actual time and rounded with the same rules ("Start – corrected" 08:07 → new "Start – rounded" 08:00). |
| D8 | After a correction | The old rounded row is set `timeRegActive = 0` with `timeRegWhenModified`; the actual row stays active as history; the newest active rounded row counts. Nothing is deleted. Each change is audited in `tblEventLog` (actor, target, `timeRegID`). |
| D9 | Time zone | `timeRegTimestamp` is stored in **UTC**. The workplace time zone (Europe/Brussels) is set once in the server configuration; schedules are compared in that local time. |
| D10 | Start vs finish rule | `tblScheduleType` has **"Work – start"** and **"Work – finish"**. A working day is two `tblSchedule` rows, each with its own rounding rule (`tblScheduleRoundingRule`) and tolerance. `roundingRuleRoundUp` means what its name says: **1 = round up, 0 = round down** (updated 2026-10-20, see D11a). |
| D11a | Rounding (updated 2026-10-21) | HR chooses, **separately for the start and the finish**: **Up**, **Down** or **No rounding**, and the interval (5, 10, 15, 30 or 60 minutes). Example: arrives 08:04, start Up every 15 → 08:15; Up every 30 → 08:30; Down every 15 → 08:00. Stored as one `tblRoundingRule` per start/finish row (`roundingRuleValueInMin`, `roundingRuleRoundUp` 1 = up, 0 = down); no rule = no rounding. **No "Nearest"** (not needed; it would have needed two rules per row). Replaces "favours the company / the employee". The actual time is always kept; payable time effects need an approved business policy. |
| D11b | Tolerance (updated 2026-10-21) | **Attendance only, one-sided, never changes a time.** **Arrival tolerance** (`scheduleMarginMin` of the "Work – start" row): arriving more than that many minutes after the scheduled start is **late** (start 08:00, tolerance 1: 08:01 on time, 08:02 late). **Leaving tolerance** (`scheduleMarginMin` of the "Work – finish" row): leaving more than that many minutes before the scheduled finish is an **early departure** (finish 16:30, tolerance 5: 16:25 within tolerance, 16:24 early). The status is calculated from the actual time, not stored. Replaces snapping to the scheduled time. |
| D12 | When changes apply | A schedule or rule change applies **immediately** when HR saves it. "Schedule for a later date" is removed from Figma for the MVP (no field for a future date). |
| D13 | Breaks | Automatic. HR creates a Break schedule per group (e.g. White collar 45 min, Blue collar 30 min, examples only). Its length (stop − start) is deducted from the working day; the employee never registers a break. |
| D14 | Exceptions | Problems (e.g. missing finish) are **calculated** from the registrations and shown in **Time records**, where HR fixes them; a complete day has no problem. **No separate Exceptions screen**, no "dismiss" state. |
| D15 | Lookup rows | IT writes and runs the default-data script. Jitan keeps its own version, [reference_data.sql](database/reference_data.sql), to advise IT. |
| D16 | Company and project | When registering, the employee **may** choose a company and project; if not, Jitan uses the employee's **default company and default project**. Waits for IT's ERD update with projects and default companies (GAP-03); nothing is built for it before. |
| D17 | Two kinds of project | Each company has **client projects** (work for a customer; the employee's default) and **internal projects** (e.g. cleaning the workshop or office). Part of IT's ERD update (D16). |
| D18 | Two terminals | **Workshop terminal** for Blue collar employees; **front-desk terminal** for White collar employees and visitors. Both work the same: the employee scans their Terminal QR (`userQRcode`) and the default project applies; they can choose another project. Waits for GAP-09 (terminals) and GAP-10 (visitors). |
| D20 | Van terminals | Besides the workshop and front-desk terminals, **vans** have a terminal for workers at external (client) companies. It works like the workshop terminal: scan the QR code, client project by default, switch possible, no visitors. Waits for GAP-09. |
| D21 | External projects | External (client) projects come from **SAP**, each with the client's **address**. The employee picks one in the morning; leaving the company and arriving at the client are registered by geofence (the project address is a known workplace), or manually with a reason when automatic registration is off. Needs IT's ERD update for projects and an SAP import (IT). |
| D22 | Transport | A working day is a **sequence of activities**, each clocked in and out: internal work, **transport**, a client project, transport again. "Clock out X + clock in Y" at the same moment is one switch (D19). **Transport** is an activity like a project: its time is recorded but **not working time**; it is paid or charged **per kilometre** (D23, D26). Geofencing can switch by itself (leaving the company's area → Transport; arriving at the project address → the project); otherwise the employee switches on the terminal or in the app. Only the day's first start and last finish are rounded. |
| D23 | Kilometres | **Calculated, never stored:** for each transport, the driving distance of the **normal route** from where the employee was before (e.g. the company) to where they arrive (e.g. the project's address), from `tblAddress.addressCoordinates` via a routing API (provider to choose with IT). The actual route is not tracked (privacy; "time tracking without the tracking"). A work-related detour is an HR correction with a reason. |
| D24 | Reports | **Employee monthly report** (days, hours, transports, kilometres, totals) and **project report** (the employees who worked on it, their hours, its transports and kilometres, each van trip counted once). Both are **calculated when opened**, never stored. HR downloads them (Excel/CSV or PDF); the file payroll or invoicing keeps is the record. Rule: store a calculated value only if recalculating later would give a different answer that may not change (rounded times: yes, D4; kilometres between fixed addresses: no). |
| D25 | Van journey (example) | 07:45–08:00 load the van at Almeco (internal work) · 08:00–09:00 transport to customer X · 09:00–16:30 customer project "ProjectXYZ" · 16:30–17:15 transport back. Working hours 7:45 (minus the group's break); transport 1:45 is not working time, paid or charged per km. |
| D26 | Who gets the kilometres | It depends on the **agreement with the client company**: charged to the customer per van trip, or paid to the employee per trip (or both). The agreement comes with the project from SAP; Jitan records the trips once and both reports show them, the agreement deciding which counts. Part of IT's projects update. |
| D27 | Workers on a project | Each project shows the employees who worked on it or chose it (also who rode in the van). IT will add what's needed to the ERD with the projects update. |
| D19 | Switching project during the day | The employee switches project in the **app or at a terminal**, with no rules per group. The working day continues; only the project changes from that moment. One server action serves both. |
| D28 | Setting a group's schedule | HR sets a group's **whole schedule in one wizard** (2026-10-20): group → working days and hours → break → attendance rules (tolerance, rounding) → review, saved **once**, hours and break in one transaction (`PUT /schedules/groups/{id}`). **Every schedule has a break**; HR only chooses its **length** (15/30/45/60 min). Jitan places it in the **middle of each working day**: start = (day start + day finish − length) / 2, whole minutes (08:00–16:30, 30 min → 12:00–12:30). Only the length counts (D13: deducted automatically); the stored time exists because a `tblSchedule` row is a time from–to, and is not shown to HR. A break as long as the working day is refused. |
| D31 | Employee corrections need HR approval (2026-10-22) | Product owner: approval only if no ERD change is needed, and none is. An employee's corrected time is stored as its **actual** row only (reason in `timeRegComment`, manual entry), with **no rounded row**: it does not count, and the day shows **Pending review**. **Approve**: HR's "Start/Finish – corrected" row at that time plus its rounded row (D7), so it counts; the employee's row stays as history. **Reject**: the employee's row is set `timeRegActive = 0` (kept). Audited: `time.correction.requested`, `time.correction.approved`, `time.correction.rejected`. HR's own corrections count at once (`time.corrected`). **Mark as non-work** (Figma `273:166`): the day's active rows are switched off (kept), the reason on its rounded rows, audited `time.marked_non_work`; a day without any registration cannot be marked (no row to hold it, GAP-16). |
| D30 | When a reason is asked (2026-10-22) | Product owner. At launch every method works: geofence, Terminal QR, and **manual** for employees who don't want location tracking. A manual start or finish comes in one of three ways: **tapped when it happens** ("Start work" at 08:00): no reason, `timeRegManualEntry = 0` (like a scan); **corrected afterwards** (forgot to register: at 10:00 enters "started 08:00"): a **reason is required**, `timeRegManualEntry = 1`; **first day** ("When did you arrive?" right after onboarding, Figma `22:2`): no reason, allowed only while the employee has no registration yet, `timeRegManualEntry = 1`. D6 now reads: a reason is required for a time **corrected** by the employee or by HR. |
| D29 | Every group has work hours (**reversed** later on 2026-10-21: employees and hours are optional in Create group) | Product owner, 2026-10-21. **Create group** (Figma 1340:160, 1352:2, 1352:175) saves the name, the employees and the work hours and break **together, in one transaction** (`POST /groups`, `CreateGroupRequest`). The ERD keeps a group's hours on the employees whose only group it is (`tblUserSchedule`; there is no group–schedule link), so step 2 needs **at least one chosen employee who is in no other group**; Continue stays disabled until then. Tolerance is 0 and there is no rounding at creation; HR changes them later with Edit work hours. Consequence: HR cannot create an empty group and fill it later. |
| D32 | Leaving a workplace (geofencing, 2026-10-31) | Product owner. After leaving, Jitan waits **1 hour**, the same for everyone in V1, with the day running; coming back in time changes nothing and asks nothing. After that hour Jitan asks "What happened?". Where the hour is stored is open (GAP-06, CLARIFY-04); until then it is one constant in the code. |
| D33 | Arriving at a workplace (geofencing, 2026-10-31) | Product owner. Arrival counts after **5 minutes** inside; the actual time saved is the moment of entering. Arrival on a day **with no schedule** also starts the day by itself; HR can see and correct it. |
| D34 | Answers to "What happened?" (2026-10-31) | Product owner. **Finished work:** the finish is the time they left, saved as actual and rounded as usual. **Break / personal:** the time away is not work; HR sees it and can correct it. **Travelling for work:** the employee enters the travel time themselves with a reason and it waits for HR (D31), because travelling is work for white collar and transport for blue collar, and the ERD holds no such setting in V1. **Other:** the employee writes a reason, it goes to HR, and the time away does not count unless HR approves. |
| D35 | No answer (2026-10-31) | Product owner. Jitan never guesses: the day stays open and shows as missing finish, fixed through the existing flow (D30, D31). |
| D36 | Workplaces (2026-10-31) | Product owner. A company has **one address**, shared by its blue collar employees (workplace) and white collar employees (offices). So V1 has one geofence per address and no geofence per employee group. |

**Still open**

- Projects (client/internal) and default companies: IT's ERD update (D16, D17, GAP-03).
  How a project switch (D19) is stored depends on it.
- Terminals and visitors (D18): GAP-09, GAP-10.
- Language codes for languages other than English (English is built in): decided when
  they are added.
- Access roles: HR and Admin have the same rights in V1; more roles later (CLARIFY-10).
- The configuration tables in the 2026-10-12 `ERD.jpg` are not in IT's creation script
  (2026-10-13).

**Figma changes these decisions need** (Figma follows the ERD): "Policy" becomes
"Schedule"; remove "Schedule for a later date" (D12); remove the Exceptions screen and show
problems in Time records (D14); add a reason field to the employee's manual registration
(D5, D6); add a company/project choice to registration, defaulted (D16, once IT's ERD
update exists). The halfway setting is removed; HR chooses "favours the company" or "favours the employee" instead (D11a).

## The tables involved

| Table | What it holds |
|---|---|
| `tblScheduleType` | Work – start, Work – finish, Break (D10, D13) |
| `tblSchedule` | One period on one weekday: type, start/stop hour and minute, `scheduleMarginMin` (tolerance, D11b), Active/MFD. Global: no company |
| `tblDays` | Weekdays |
| `tblUserSchedule` | Employee ↔ schedule, Active/MFD; filled per group (D2) |
| `tblRoundingRule` | `roundingRuleValueInMin` (grid, D11a), `roundingRuleRoundUp` (1 = round up, 0 = round down, D11a), Active/MFD |
| `tblScheduleRoundingRule` | Schedule ↔ rounding rule, Active/MFD |
| `tblTimeReg` | One row per time: actual, rounded or corrected (D4–D8), user, address (NULL for a manual entry without a location), type, UTC timestamp (D9), manual flag, reason, when modified, Active/MFD |
| `tblTimeRegType` | The 10 registration types (D5b) |
| `tblEventLog` | Audit of every change (actor, target, `timeRegID`, `scheduleID`, …) |

## Requirement by requirement

| # | Requirement | How it is stored | Status |
|---|---|---|---|
| R1 | Rounding grid of 15, 30 or 60 minutes | `roundingRuleValueInMin` (D11a) | **Decided** |
| R1b | Separate start and finish rounding | "Work – start" / "Work – finish" schedule rows, each with its rule (D10) | **Decided** |
| R1c | Halfway rounding | Dropped: rounding is up or down (D11a) | **Dropped** |
| R2 | Actual time preserved | "… – actual – …" row, never changed (D4) | **Decided** |
| R3 | Rounded time calculated automatically | `RoundingCalculator` (built) writes the "… – rounded" row (D4) | **Decided**; calculator built, storage not built |
| R4 | Tolerance separate from rounding | `scheduleMarginMin`, inclusive (D11b) | **Decided** |
| R5 | Same rules for geofence, QR and manual | The rule comes from the schedule, not the method (D5, D7) | **Decided** |
| R6 | Approved records never change | Rounded time is stored, not recalculated (D4) | **Decided** |
| R7 | HR manages schedule types, schedules, rounding rules | Existing tables, soft delete, audited | **Decided** |
| R8 | Configurable breaks per group | Break schedule rows per group (D2, D13) | **Decided** |
| R9 | HR corrections with reason, original kept, audited | D6–D8 | **Decided** |
| R10 | Fixing a day resolves its problem | Problems are calculated (D14) | **Decided** |
| R11 | Policy from a future date | Not in the MVP (D12) | **Dropped for the MVP** |
| R12 | Company and project per registration | Employee's choice or defaults (D16) | **Waits for IT's ERD update** |

## Further findings

1. **What rounds.** Only the first start and last finish of a work session round, not
   every event (a workplace change mid-session is not a boundary, roadmap §15).
2. **Multi-company employees:** schedules have no company; an employee's schedules apply
   in every company. A registration's company comes from D16.
3. **Time zone:** Belgium only for now (D9). A workplace outside Belgium would need its
   time zone stored somewhere: a question for IT then.

## What can be built now

- **Done:** `RoundingCalculator` and `RoundingPolicy` (pure, tested).
- **Next, with no open question** (the rounding calculator, built for nearest rounding, is changed to up/down rounding with phase 2, D11a): schedule types, schedules and rounding rules for HR
  (D2, D10–D13); registrations stored as actual + rounded rows (D4–D9); HR corrections
  and the employee's manual registration with reason (D5–D8); problems in Time records
  (D14). Each still goes slice by slice, with its Figma screens updated first.
- **Waits:** company/project on registrations (D16, IT's ERD update); access-role
  permissions (CLARIFY-10/11).
