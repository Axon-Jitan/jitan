-- =====================================================================
--  Jitan: reference data (fixed lists) every Jitan database needs
--
--  Purpose: Jitan's own version of the default-data script, so we can
--  compare it with, and advise on, the script IT writes and runs.
--  Jitan never runs this file itself: the API makes no database changes on
--  its own. Only IT runs scripts on IT's databases.
--
--  - Only fixed lists (names). No people, companies, passwords or secrets.
--    Development people and companies live in dev/local-db/seed.sql.
--  - No IDs: Jitan always finds these rows by name, never by ID.
--  - Safe to run twice: a row is only added when its name is missing.
--  - Names here are the ones Jitan's code looks up. Changing one means
--    changing the code in the same commit.
--
--  Decisions behind these rows: docs/TIME_ENGINE_ANALYSIS.md
--  ("Decisions 2026-10-12/13").
-- =====================================================================

SET NAMES utf8mb4; -- the names below contain "–" (en dash)

-- ---------- Days (tblDays) -------------------------------------------

INSERT INTO tblDays (dayName, dayActive, dayMFD)
SELECT d.name, 1, 0 FROM (
  SELECT 'Monday' AS name UNION ALL SELECT 'Tuesday' UNION ALL SELECT 'Wednesday'
  UNION ALL SELECT 'Thursday' UNION ALL SELECT 'Friday' UNION ALL SELECT 'Saturday'
  UNION ALL SELECT 'Sunday'
) d WHERE NOT EXISTS (SELECT 1 FROM tblDays x WHERE x.dayName = d.name);

-- ---------- Schedule types (tblScheduleType) -------------------------
-- A working day is two rows: a start row and a finish row, each with its
-- own rounding rule and tolerance (decision 10). A break is deducted
-- automatically; its length is the row's stop minus start (decision 13).

INSERT INTO tblScheduleType (scheduleTypeName, scheduleTypeActive, scheduleTypeMFD)
SELECT t.name, 1, 0 FROM (
  SELECT 'Work – start' AS name UNION ALL SELECT 'Work – finish' UNION ALL SELECT 'Break'
) t WHERE NOT EXISTS (SELECT 1 FROM tblScheduleType x WHERE x.scheduleTypeName = t.name);

-- ---------- Registration types (tblTimeRegType) ----------------------
-- Every registration is stored as rows told apart by type (decisions 4, 5,
-- 7, 8): the actual time with how it was registered, the rounded time, and
-- HR's corrected time. Manual rows also have timeRegManualEntry = 1 and a
-- required reason in timeRegComment (decision 6). What the day is spent on
-- is an "Activity – …" row (D19, D22): its addressID is the project or the
-- place (D44). Transport is not working time (D46).

INSERT INTO tblTimeRegType (timeRegTypeName, timeRegTypeActive, timeRegTypeMFD)
SELECT t.name, 1, 0 FROM (
  SELECT 'Start – actual – Geofence' AS name
  UNION ALL SELECT 'Start – actual – QR'
  UNION ALL SELECT 'Start – actual – Manual'
  UNION ALL SELECT 'Finish – actual – Geofence'
  UNION ALL SELECT 'Finish – actual – QR'
  UNION ALL SELECT 'Finish – actual – Manual'
  UNION ALL SELECT 'Start – rounded'
  UNION ALL SELECT 'Finish – rounded'
  UNION ALL SELECT 'Start – corrected'
  UNION ALL SELECT 'Finish – corrected'
  UNION ALL SELECT 'Activity – Work'
  UNION ALL SELECT 'Activity – Client on site'
  UNION ALL SELECT 'Activity – Client in-house'
  UNION ALL SELECT 'Activity – Internal'
  UNION ALL SELECT 'Activity – Transport'
) t WHERE NOT EXISTS (SELECT 1 FROM tblTimeRegType x WHERE x.timeRegTypeName = t.name);

-- ---------- Employee groups (tblGroup) -------------------------------
-- Groups are universal across companies (IT, 2026-10-08). Schedules are set
-- per group (decision 2).

INSERT INTO tblGroup (groupName, groupActive, groupMFD)
SELECT g.name, 1, 0 FROM (
  SELECT 'White collar' AS name UNION ALL SELECT 'Blue collar'
) g WHERE NOT EXISTS (SELECT 1 FROM tblGroup x WHERE x.groupName = g.name);

-- ---------- Access roles (tblCredGroup) ------------------------------
-- credGroupLevel only orders the roles; what each role may do is still open
-- (CLARIFY-10), so no module or function links are proposed here.

INSERT INTO tblCredGroup (credGroupName, credGroupLevel, credGroupActive, credGroupMFD)
SELECT r.name, r.level, 1, 0 FROM (
  SELECT 'Employee' AS name, 1 AS level UNION ALL SELECT 'HR', 2 UNION ALL SELECT 'Admin', 3
) r WHERE NOT EXISTS (SELECT 1 FROM tblCredGroup x WHERE x.credGroupName = r.name);

-- ---------- Languages (tblLanguage) ----------------------------------
-- English is the default and built into the apps (decision 2026-10-13); it
-- always works without the database, and its row only makes it selectable.
-- Other languages: the code style (nl or nl-BE, as IT's comment suggests) is
-- decided when they are added; the apps name languages by code
-- (translation keys language.name.<code>).

INSERT INTO tblLanguage (languageName, languageCode, languageActive, languageMFD)
SELECT l.name, l.code, 1, 0 FROM (
  SELECT 'English' AS name, 'en' AS code
  UNION ALL SELECT 'Nederlands', 'nl'
  UNION ALL SELECT 'Français', 'fr'
) l WHERE NOT EXISTS (SELECT 1 FROM tblLanguage x WHERE x.languageCode = l.code);

-- ---------- Audit event types (tblEventType) -------------------------
-- Exactly the names in AuditEventType (server/jitan_api/lib/src/audit/
-- audit_event.dart). Without a row the event is still logged, but without
-- its type, and the reset/recovery check (CLARIFY-13) depends on
-- employee.access.reset, employee.access.recovered and
-- employee.onboarding.completed.

INSERT INTO tblEventType (eventTypeName)
SELECT e.name FROM (
  SELECT 'employee.created' AS name
  UNION ALL SELECT 'employee.onboarding_qr.generated'
  UNION ALL SELECT 'employee.recovery_qr.generated'
  UNION ALL SELECT 'employee.onboarding.completed'
  UNION ALL SELECT 'employee.password.changed'
  UNION ALL SELECT 'employee.access.reset'
  UNION ALL SELECT 'employee.access.recovered'
  UNION ALL SELECT 'employee.company.assigned'
  UNION ALL SELECT 'employee.company.removed'
  UNION ALL SELECT 'employee.group.assigned'
  UNION ALL SELECT 'employee.group.removed'
  UNION ALL SELECT 'employee.credential_group.assigned'
  UNION ALL SELECT 'employee.language.changed'
  UNION ALL SELECT 'group.created'
  UNION ALL SELECT 'group.renamed'
  UNION ALL SELECT 'group.deactivated'
  UNION ALL SELECT 'group.reactivated'
  UNION ALL SELECT 'employee.schedule_source.changed'
  UNION ALL SELECT 'schedule.created'
  UNION ALL SELECT 'schedule.deactivated'
  UNION ALL SELECT 'employee.removed'
  UNION ALL SELECT 'time.registered'
  UNION ALL SELECT 'time.correction.requested'
  UNION ALL SELECT 'time.correction.approved'
  UNION ALL SELECT 'time.correction.rejected'
  UNION ALL SELECT 'time.corrected'
  UNION ALL SELECT 'time.marked_non_work'
  UNION ALL SELECT 'employee.password.first_set'
  UNION ALL SELECT 'location.created'
  UNION ALL SELECT 'location.changed'
  UNION ALL SELECT 'location.deactivated'
  UNION ALL SELECT 'location.reactivated'
  UNION ALL SELECT 'terminal.created'
  UNION ALL SELECT 'terminal.changed'
  UNION ALL SELECT 'terminal.pairing.started'
  UNION ALL SELECT 'terminal.paired'
  UNION ALL SELECT 'terminal.deactivated'
  UNION ALL SELECT 'terminal.reactivated'
  UNION ALL SELECT 'terminal.removed'
  UNION ALL SELECT 'list.entry.added'
  UNION ALL SELECT 'company.created'
  UNION ALL SELECT 'company.renamed'
  UNION ALL SELECT 'company.deactivated'
  UNION ALL SELECT 'company.reactivated'
) e WHERE NOT EXISTS (SELECT 1 FROM tblEventType x WHERE x.eventTypeName = e.name);

-- ---------- Kinds of place (tblLocationType) ------------------------
-- A project is an address of this kind (D44).

INSERT INTO tblLocationType (locationTypeName, locationTypeActive, locationTypeMFD)
SELECT 'Project location', 1, 0 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM tblLocationType x WHERE x.locationTypeName = 'Project location');

-- ---------- Terminal kinds (tblDeviceType) ---------------------------
-- A terminal is a shared tablet (tblDevice, deviceMultiUser = 1) of one of
-- these kinds (GAP-09). Phones and other devices would be other rows.

INSERT INTO tblDeviceType (deviceTypeName, deviceTypeOS, deviceTypeActive, deviceTypeMFD)
SELECT d.name, 'Android', 1, 0 FROM (
  SELECT 'Office terminal' AS name UNION ALL SELECT 'Vehicle terminal'
) d WHERE NOT EXISTS (SELECT 1 FROM tblDeviceType x WHERE x.deviceTypeName = d.name);

-- ---------- Not proposed yet -----------------------------------------
-- tblAppModules, tblFunction, tblAppModulesCredGroup: what each role may
-- open and do (CLARIFY-10/11).
