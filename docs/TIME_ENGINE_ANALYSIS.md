# Time-registration engine: requirements vs the ERD

Analysis of 2026-10-08, updated 2026-10-12, before any engine persistence is built. Sources: the agreed rounding
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
4. HR/Admin can **schedule when a new policy becomes effective**.
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
13. Resolving an issue in Time records **also resolves the corresponding exception**.

**Database restrictions**

14. The existing ERD and IT's database schema are not changed. No columns, tables or
    relationships are invented.
15. Anything the existing schema cannot support is **discussed with IT first**, and is not
    built until IT confirms how it is stored.

**Status:** the pure rounding calculation is built and tested
(`server/jitan_api/lib/src/time_registration/rounding/`). Nothing is stored or read for it
yet: no table, column or persistence behaviour was added or assumed. Corrections, breaks
per group, policy effective dates and exception resolution are **not built** and wait for
IT (below).

## Database implementation questions for IT

Open questions only; Jitan assumes none of the answers. Each requirement number refers to
the list above.

| # | Requirement | What the schema has | Question for IT | Ref |
|---|---|---|---|---|
| Q1 | 2: actual time preserved | `tblTimeReg.timeRegTimestamp`, one per row | Is `timeRegTimestamp` the actual time, never to be overwritten? | GAP-01 |
| Q2 | 3: approved records unchanged | No stored rounded time, applied rule or approval state on `tblTimeReg`; no dates on rules or links | Where is the rounded time (or the rule applied) of an approved record kept, and where is "approved" stored? | GAP-01, GAP-13 |
| Q3 | 4: scheduled policies | No valid-from/valid-to on `tblRoundingRule`, `tblScheduleRoundingRule`, `tblSchedule`, `tblUserSchedule` | Where does a policy's effective date go? | GAP-13 |
| Q4 | 1: separate start/finish rounding | A schedule can link several rules (`tblScheduleRoundingRule`); `tblRoundingRule` has `roundingRuleValueInMin` and `roundingRuleRoundUp` | How does the schema say which rule is the start rule and which the finish rule? What do `roundingRuleRoundUp` and `roundingRuleValueInMin` mean? | CLARIFY-03 |
| Q5 | 7–8: break durations, per group | A break can be a `tblSchedule` row of a Break type: weekday + start/stop clock time. No duration field. Schedules link to **users** (`tblUserSchedule`), not groups | Is a break a fixed time window (a schedule row) or a duration? How does a duration per employee group (45 / 30 min) get stored without a group → schedule link? | GAP-13 |
| Q6 | 9, 11: corrections keep the original | One timestamp per `tblTimeReg` row; `timeRegManualEntry`, `timeRegActive`/`MFD`, `timeRegWhenModified`, `timeRegComment` exist; nothing links an original row to its correction | How is a correction stored so the original stays, and how are the two linked? How is a *missing* start/finish added? | GAP-01 |
| Q7 | 10: reason required | `tblEventLog` has no text column; `tblTimeReg.timeRegComment` VARCHAR(500) exists but its intended use is not confirmed | Where is the correction reason stored? | GAP-01 |
| Q8 | 12: corrections audited | `tblEventLog` references `timeRegID`, actor and target, but has no old/new value | Is the event-log row (with the correction's `timeRegID`) enough, or must the old and new value be recorded somewhere? | GAP-01 |
| Q9 | 13: resolving resolves the exception | Exception state is not stored anywhere | Are exceptions purely derived from registrations (a correction then clears them by itself), or does "resolved"/"dismissed" need storing? | GAP-08 |
| Q10 | start/finish detection | `tblTimeReg.timeRegTypeID` → `tblTimeRegType` | Does a type mean the event kind (start/finish/break), the source, or both? | CLARIFY-02 |
| Q11 | comparing with schedules | Schedules are clock times; no timezone anywhere | Is `timeRegTimestamp` UTC or local, and where does a site's timezone come from? | GAP-02 |

## The tables involved

| Table | What it holds | Missing for the engine |
|---|---|---|
| `tblScheduleType` | Kind of period (Work, Break, Lunch, Travel), Active/MFD | — |
| `tblSchedule` | One period on one weekday (`dayID`): type, start/stop hour+minute, `scheduleMarginMin` (= the scheduled-time tolerance, decided), Active/MFD. Global: no company (confirmed) | effective dates; date-specific exceptions |
| `tblDays` | Weekdays | — |
| `tblUserSchedule` | User ↔ schedule (unique pair), Active/MFD. User-wide: no company (confirmed) | effective dates |
| `tblRoundingRule` | `roundingRuleValueInMin`, `roundingRuleRoundUp`, Active/MFD | start vs finish; effective dates; company |
| `tblScheduleRoundingRule` | Schedule ↔ rounding rule (unique pair), Active/MFD | effective dates |
| `tblTimeReg` | One event: user, address, type, **one** timestamp, manual flag, comment, when modified, Active/MFD | registered time; applied rule; approval state; company |
| `tblTimeRegType` | Configured event types | meaning (CLARIFY-02) |
| `tblEventLog` | Audit with FKs to all of the above | old/new values |

## Requirement by requirement

| # | Requirement | ERD support | Status |
|---|---|---|---|
| R1 | Admin-configurable intervals of 15, 30 or 60 minutes | `tblRoundingRule.roundingRuleValueInMin` holds the minutes; Jitan validates 15/30/60 (`RoundingInterval`) | **Supported directly** |
| R1b | Separate **start** and **finish** intervals (confirmed requirement 1; Figma "Start interval", "Finish interval") | A schedule can link several rules (`tblScheduleRoundingRule`), but no column is known to say which rule is the start one and which the finish one. Jitan does **not** assume `roundingRuleRoundUp` means this | **IT confirmation** (Q4, CLARIFY-03) |
| R1c | "Halfway rounding: Round forward" | No column is known to hold it. `roundingRuleRoundUp` is a candidate for R1b **or** R1c, not both; neither is assumed | **IT confirmation** (Q4, CLARIFY-03) |
| R2 | Actual timestamps preserved | `tblTimeReg.timeRegTimestamp` = the actual time; never overwritten | **Supported directly**, provided registered time is not written into it (GAP-01) |
| R3 | Registered times calculated automatically | Calculation: built (`RoundingCalculator`). Inputs: `tblUserSchedule` → `tblSchedule` (weekday, start/stop) → `tblScheduleRoundingRule` → `tblRoundingRule`. Whether the registered time is stored or computed on read is open | Calculation **supported**; storage **IT decision** (GAP-01) |
| R4 | Scheduled-time tolerance separate from interval rounding | **Decided:** the tolerance is per schedule, `tblSchedule.scheduleMarginMin`, inclusive. The engine takes it as a separate input | **Supported** (IT to confirm the column means minutes either side, CLARIFY-03) |
| R5 | Same rules for geofencing, QR and manual registration | The rule is chosen from the employee's schedule, not from the source; the engine has no source input, so it is identical by construction. Telling a start from a finish needs the event kind, which `tblTimeRegType` may or may not encode | Rounding **supported**; start/finish detection needs **CLARIFY-02** |
| R6 | Historical approved registrations never change silently when policies change | No effective dates on rules, schedule links or user schedules; no stored registered time; no "approved" state on `tblTimeReg`. If registered times are computed on read, editing a rule changes history. Figma's "Effective date: Scheduled … 12 Oct 2026" and "Existing approved registrations keep their original applied rules" have nowhere to live | **ERD GAP** (extends GAP-01; new GAP-13 below) |
| R8 | Configurable break durations per employee group (confirmed requirements 7–8) | A Break `tblSchedule` row holds a weekday and a start/stop **clock time**, not a duration; schedules link to users, not groups | **IT confirmation** (Q5, GAP-13) |
| R9 | HR corrections from Time records, with a required reason, original kept, audited (confirmed requirements 9–12) | One timestamp per row; no link between an original and its correction; no reason column known; no old/new values in `tblEventLog` | **IT confirmation** (Q6–Q8, GAP-01). Not built |
| R10 | Resolving in Time records resolves the exception (confirmed requirement 13) | Exception state is not stored (GAP-08); derived exceptions clear when the stream is complete | **IT confirmation** (Q9, GAP-08) |
| R7 | HR/Admin manage Schedule Types, Schedules and their rounding rules | Tables exist with Active/MFD (`tblScheduleType`, `tblSchedule`, `tblRoundingRule`); audit FKs exist on `tblEventLog` (`scheduleTypeID`, `scheduleID`, `dayID`, `roundingRuleID`, `scheduleRoundingRuleID`, `userScheduleID`) | **Supported** for create / edit / deactivate, and for removing a link in `tblScheduleRoundingRule` or `tblUserSchedule` (soft delete, CLARIFY-09). What the values mean still needs CLARIFY-03 |

## Further findings

1. **Policies vs schedules.** Figma's Policy ("Office", scope "White collar", break, short
   exit, start/finish interval, halfway, tolerance, registration methods) has no table, as
   documented ("There is no policy table"). Its parts map to: scope → `tblGroup`; break →
   a Break `tblSchedule` row; intervals → `tblRoundingRule`; tolerance →
   `scheduleMarginMin`?; short exit → GAP-06; methods → GAP-07. **But nothing links a group
   to schedules or rules**: `tblUserSchedule` links *users*. "The Office policy applies to
   White collar" cannot be stored; it would have to be copied to each user. **Business
   decision + IT** (in GAP-13).
2. **Multi-company employees** (IT, 2026-10-08): `tblUserSchedule`, `tblSchedule` and
   `tblTimeReg` have no company, confirmed in IT's database (CLARIFY-14 resolved). An
   employee's schedules apply in every company they work for. Attributing a registration
   to a company remains open (GAP-03).
3. **Timezone** (GAP-02): schedules are wall-clock times (`scheduleHrStart = 8`), and so
   are the stored timestamps as far as we know. The engine computes on wall-clock fields
   and never converts; comparing correctly needs GAP-02 answered.
4. **Approved registrations** (R6): `tblTimeReg` has no approval/status column.
   `timeRegActive`/`timeRegMFD` and `timeRegManualEntry` are not approval. How a correction
   is stored (for example a new manual row with the original made inactive) is **not
   assumed**; it is asked in Q6.
5. **What rounds.** Only the first start and last finish of a work session should round,
   not every event (a workplace change mid-session is not a boundary, roadmap §15).
   Deriving sessions needs the event kinds (CLARIFY-02) and is not built.

## GAP-13

Recorded in [ERD_GAPS.md](database/ERD_GAPS.md#gap-13-rounding-rules-over-time-and-per-employee-group):
effective dating, stored registered time with the applied rule (GAP-01), an approval state,
and a group → schedule/rule relationship.

## What can be built without unresolved decisions

- **Done:** `RoundingCalculator` and `RoundingPolicy`, pure Dart, with worked examples
  from Figma and the roadmap, every case in the testing priorities that rounding alone can
  decide, and generated properties (on a mark, within half an interval, idempotent,
  monotonic, tolerance only within range).
- **Next, still without persistence:** read-only HR/Admin lists of Schedule Types,
  Schedules (with weekday and times) and Rounding Rules over the existing tables, which
  need no semantic decision. Schedules are global (CLARIFY-14 resolved), so these lists are
  not company-scoped. Create/edit of these needs CLARIFY-03 (what `RoundUp` and
  `MarginMin` mean) to avoid writing values whose meaning is guessed.
- **Blocked until IT confirms the storage:** storing or showing registered times (GAP-01,
  GAP-13), HR corrections and their reasons (Q6–Q8), break durations per group (Q5),
  exception resolution (Q9, GAP-08), work sessions and start/finish detection
  (CLARIFY-02), comparing with schedules (GAP-02), policy screens with scope and effective
  dates (GAP-13, GAP-06, GAP-07).
