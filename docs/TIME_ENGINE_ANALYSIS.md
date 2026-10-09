# Time-registration engine: requirements vs the ERD

Analysis of 2026-10-08, before any engine persistence is built. Sources: the agreed rounding
requirements, ROADMAP §15–19 and §23, Figma `HR / Policies` (`215:28` Rounding interval
options, `216:*` Effective date / Scheduled change), [ERD.jpg](database/ERD.jpg),
[ERD.md](database/ERD.md) and [ERD_GAPS.md](database/ERD_GAPS.md).

## ERD version check (resolved 2026-10-09)

A newer diagram was reported to add `tblSchedule.companyID` and
`tblUserSchedule.userCompanyID`. IT's development database has **neither** (CLARIFY-14
resolved): **schedules are global and reusable, and a schedule assignment is user-wide**,
applying in every company the employee works for. All junction tables, including
`tblUserSchedule` and `tblScheduleRoundingRule`, have Active/MFD.

## Product decisions (2026-10-08)

1. Scheduled-time tolerance is **inclusive** (±15 min around 08:00 includes 07:45 and 08:15).
2. The tolerance belongs to the **schedule**: `tblSchedule.scheduleMarginMin`.
3. Rounding applies the same way to geofencing, Terminal QR and manual registration.
4. Actual timestamps are always preserved.
5. Approved registrations never change silently when rounding rules change.
6. HR/Admin will schedule future policy changes, but only once effective-date persistence
   is resolved (GAP-13).

**Status:** the pure rounding calculation is built and tested
(`server/jitan_api/lib/src/time_registration/rounding/`). Nothing is stored or read for it
yet: no table, column or persistence behaviour was added or assumed.

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
| R1b | Separate **start** and **finish** intervals (Figma "Start interval", "Finish interval") | A schedule can link several rules (`tblScheduleRoundingRule`), but nothing says which rule is the start one and which the finish one. `roundingRuleRoundUp` may mean it (CLARIFY-03) | **IT confirmation** (CLARIFY-03) |
| R1c | "Halfway rounding: Round forward" | Possibly `roundingRuleRoundUp` (forward = up). Same column as R1b: it cannot mean both | **IT confirmation** (CLARIFY-03) |
| R2 | Actual timestamps preserved | `tblTimeReg.timeRegTimestamp` = the actual time; never overwritten | **Supported directly**, provided registered time is not written into it (GAP-01) |
| R3 | Registered times calculated automatically | Calculation: built (`RoundingCalculator`). Inputs: `tblUserSchedule` → `tblSchedule` (weekday, start/stop) → `tblScheduleRoundingRule` → `tblRoundingRule`. Whether the registered time is stored or computed on read is open | Calculation **supported**; storage **IT decision** (GAP-01) |
| R4 | Scheduled-time tolerance separate from interval rounding | **Decided:** the tolerance is per schedule, `tblSchedule.scheduleMarginMin`, inclusive. The engine takes it as a separate input | **Supported** (IT to confirm the column means minutes either side, CLARIFY-03) |
| R5 | Same rules for geofencing, QR and manual registration | The rule is chosen from the employee's schedule, not from the source; the engine has no source input, so it is identical by construction. Telling a start from a finish needs the event kind, which `tblTimeRegType` may or may not encode | Rounding **supported**; start/finish detection needs **CLARIFY-02** |
| R6 | Historical approved registrations never change silently when policies change | No effective dates on rules, schedule links or user schedules; no stored registered time; no "approved" state on `tblTimeReg`. If registered times are computed on read, editing a rule changes history. Figma's "Effective date: Scheduled … 12 Oct 2026" and "Existing approved registrations keep their original applied rules" have nowhere to live | **ERD GAP** (extends GAP-01; new GAP-13 below) |
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
   `timeRegActive`/`timeRegMFD` and `timeRegManualEntry` are not approval. An HR correction
   pattern (new manual row + old row inactive) was proposed in GAP-01 and is unanswered.
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
- **Blocked:** storing or showing registered times (GAP-01, GAP-13), work sessions and
  start/finish detection (CLARIFY-02), comparing with schedules (GAP-02), policy screens
  with scope and effective dates (GAP-13, GAP-06, GAP-07).
