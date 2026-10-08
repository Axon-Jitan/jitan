# Time-registration engine: requirements vs the ERD

Analysis of 2026-10-08, before any engine persistence is built. Sources: the agreed rounding
requirements, ROADMAP §15–19 and §23, Figma `HR / Policies` (`215:28` Rounding interval
options, `216:*` Effective date / Scheduled change), [ERD.jpg](database/ERD.jpg),
[ERD.md](database/ERD.md) and [ERD_GAPS.md](database/ERD_GAPS.md).

## ERD version check (open)

The product team reports a newer IT-approved diagram with **`tblSchedule.companyID`** and
**`tblUserSchedule.userCompanyID`**. Neither the repository's [ERD.jpg](database/ERD.jpg)
(2026-10-07) nor the older draft `2026-09-24 - ERD-organized.drawio.png` contains them, and
the newer diagram has not been received. Until it is, company-scoped schedules are
**unconfirmed, not unsupported**: nothing here assumes either version, and the local
database keeps the repository ERD. Requested: the newer diagram, to replace `ERD.jpg`.

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
| `tblSchedule` | One period on one weekday (`dayID`): type, start/stop hour+minute, `scheduleMarginMin` (= the scheduled-time tolerance, decided), Active/MFD | company (**unconfirmed**: newer diagram); effective dates; date-specific exceptions |
| `tblDays` | Weekdays | — |
| `tblUserSchedule` | User ↔ schedule (unique pair) | Active/MFD; effective dates; membership (`userCompanyID`: **unconfirmed**, newer diagram) |
| `tblRoundingRule` | `roundingRuleValueInMin`, `roundingRuleRoundUp`, Active/MFD | start vs finish; effective dates; company |
| `tblScheduleRoundingRule` | Schedule ↔ rounding rule (unique pair) | Active/MFD; effective dates |
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
| R7 | HR/Admin manage Schedule Types, Schedules and their rounding rules | Tables exist with Active/MFD (`tblScheduleType`, `tblSchedule`, `tblRoundingRule`); audit FKs exist on `tblEventLog` (`scheduleTypeID`, `scheduleID`, `dayID`, `roundingRuleID`, `scheduleRoundingRuleID`, `userScheduleID`) | **Supported** for create / edit / deactivate. Removing a link in `tblScheduleRoundingRule` or `tblUserSchedule` (no Active/MFD) is **IT confirmation** (CLARIFY-09) |

## Further findings

1. **Policies vs schedules.** Figma's Policy ("Office", scope "White collar", break, short
   exit, start/finish interval, halfway, tolerance, registration methods) has no table, as
   documented ("There is no policy table"). Its parts map to: scope → `tblGroup`; break →
   a Break `tblSchedule` row; intervals → `tblRoundingRule`; tolerance →
   `scheduleMarginMin`?; short exit → GAP-06; methods → GAP-07. **But nothing links a group
   to schedules or rules**: `tblUserSchedule` links *users*. "The Office policy applies to
   White collar" cannot be stored; it would have to be copied to each user. **Business
   decision + IT** (in GAP-13).
2. **Multi-company employees** (IT, 2026-10-08): in the repository ERD, `tblUserSchedule`,
   `tblSchedule` and `tblTimeReg` have no company. A newer diagram reportedly adds
   `tblSchedule.companyID` and `tblUserSchedule.userCompanyID`; that would make schedules
   company-scoped. **Pending the diagram** (see "ERD version check"). `tblTimeReg` still has
   no company in any version seen (GAP-03).
3. **Timezone** (GAP-02): schedules are wall-clock times (`scheduleHrStart = 8`), and so
   are the stored timestamps as far as we know. The engine computes on wall-clock fields
   and never converts; comparing correctly needs GAP-02 answered.
4. **Approved registrations** (R6): `tblTimeReg` has no approval/status column.
   `timeRegActive`/`timeRegMFD` and `timeRegManualEntry` are not approval. An HR correction
   pattern (new manual row + old row inactive) was proposed in GAP-01 and is unanswered.
5. **What rounds.** Only the first start and last finish of a work session should round,
   not every event (a workplace change mid-session is not a boundary, roadmap §15).
   Deriving sessions needs the event kinds (CLARIFY-02) and is not built.

## Proposed GAP-13 (for ERD_GAPS.md)

**Rounding rules over time and per group.** Requirement: policy changes take effect
immediately or on a scheduled date, and approved registrations keep the rule that was
applied; a policy applies to an employee group. Missing: effective dating (from/to) on
`tblRoundingRule` / `tblScheduleRoundingRule` / `tblUserSchedule`, or stored registered
times with the applied rule (GAP-01); an approval state for registrations; a group →
schedule/rule relationship.

## What can be built without unresolved decisions

- **Done:** `RoundingCalculator` and `RoundingPolicy`, pure Dart, with worked examples
  from Figma and the roadmap, every case in the testing priorities that rounding alone can
  decide, and generated properties (on a mark, within half an interval, idempotent,
  monotonic, tolerance only within range).
- **Next, still without persistence:** read-only HR/Admin lists of Schedule Types,
  Schedules (with weekday and times) and Rounding Rules over the existing tables, which
  need no semantic decision. Create/edit of these needs CLARIFY-03 (what `RoundUp` and
  `MarginMin` mean) to avoid writing values whose meaning is guessed.
- **Blocked:** storing or showing registered times (GAP-01, GAP-13), work sessions and
  start/finish detection (CLARIFY-02), comparing with schedules (GAP-02), policy screens
  with scope and effective dates (GAP-13, GAP-06, GAP-07).
