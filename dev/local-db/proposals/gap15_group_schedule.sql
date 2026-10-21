-- PROPOSAL, NOT IN IT'S DATABASE. ERD_GAPS.md GAP-15 (2026-10-21), sent to IT for
-- approval. Local development database only: lets Jitan try "a group owns its
-- schedule" before IT decides. If IT approves a different structure, this file
-- changes to match; if IT declines, it is deleted. Never run it against IT's
-- databases. schema.sql stays IT's export and does not contain this.

CREATE TABLE IF NOT EXISTS tblGroupSchedule (
  groupScheduleID     INT NOT NULL AUTO_INCREMENT,
  groupID             INT NOT NULL,
  scheduleID          INT NOT NULL,
  groupScheduleActive TINYINT(1) NOT NULL DEFAULT 1,
  groupScheduleMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (groupScheduleID),
  UNIQUE KEY uk_tblGroupSchedule_groupID_scheduleID (groupID, scheduleID),
  CONSTRAINT fk_tblGroupSchedule_groupID FOREIGN KEY (groupID) REFERENCES tblGroup (groupID),
  CONSTRAINT fk_tblGroupSchedule_scheduleID FOREIGN KEY (scheduleID) REFERENCES tblSchedule (scheduleID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Audit of the link, like tblEventLog.userGroupID / userScheduleID.
SET @has_column = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tblEventLog' AND COLUMN_NAME = 'groupScheduleID'
);
SET @sql = IF(@has_column = 0,
  'ALTER TABLE tblEventLog ADD COLUMN groupScheduleID INT NULL, '
  'ADD CONSTRAINT fk_tblEventLog_groupScheduleID FOREIGN KEY (groupScheduleID) REFERENCES tblGroupSchedule (groupScheduleID)',
  'SELECT 1');
PREPARE statement FROM @sql;
EXECUTE statement;
DEALLOCATE PREPARE statement;
