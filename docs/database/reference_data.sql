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
-- required reason in timeRegComment (decision 6).

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
-- English is built into the apps; its row only makes it selectable.
-- OPEN: IT's script comment suggests region codes (nl-BE, fr-BE). The apps
-- name languages by code (translation keys language.name.<code>), so the
-- code style must be agreed before IT loads these rows.

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
) e WHERE NOT EXISTS (SELECT 1 FROM tblEventType x WHERE x.eventTypeName = e.name);

-- ---------- Not proposed yet -----------------------------------------
-- tblAppModules, tblFunction, tblAppModulesCredGroup: what each role may
-- open and do (CLARIFY-10/11).
-- tblLocationType: not used by any decided feature yet.
-- Event types for time registration (manual entry, correction, schedule
-- changes): added together with the code that writes them.
