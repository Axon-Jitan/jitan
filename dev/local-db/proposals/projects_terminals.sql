-- PROPOSAL, NOT IN IT'S DATABASE. Recorded in docs/database/PROPOSED_TABLES.md for
-- IT to add (product owner, 2026-10-31). Local development database only: never
-- run it against IT's databases. schema.sql stays IT's export and does not
-- contain this. If IT chooses another structure, this file changes to match.
-- Run once, after schema.sql.

SET NAMES utf8mb4; -- the names below contain "–" (en dash)

-- ── Defaults (GAP-03) ──────────────────────

-- tblUserCompany.userCompanyDefault is in IT's ERD since 2026-11-09.

-- ── Projects (D16, D17, D21, D27) ─────────

CREATE TABLE tblProjectType (
  projectTypeID     INT NOT NULL AUTO_INCREMENT,
  projectTypeName   VARCHAR(100) NOT NULL,
  projectTypeActive TINYINT(1) NOT NULL DEFAULT 1,
  projectTypeMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (projectTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblProjectStatus (
  projectStatusID     INT NOT NULL AUTO_INCREMENT,
  projectStatusName   VARCHAR(100) NOT NULL,
  projectStatusActive TINYINT(1) NOT NULL DEFAULT 1,
  projectStatusMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (projectStatusID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblProject (
  projectID          INT NOT NULL AUTO_INCREMENT,
  companyID          INT NOT NULL,
  projectTypeID      INT NOT NULL,
  projectStatusID    INT NOT NULL,
  addressID          INT NULL,
  projectName        VARCHAR(150) NOT NULL,
  projectReference   VARCHAR(50) NULL,
  projectStartDate   DATE NOT NULL,
  projectEndDate     DATE NULL,
  projectDescription VARCHAR(500) NULL,
  projectActive      TINYINT(1) NOT NULL DEFAULT 1,
  projectMFD         TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (projectID),
  CONSTRAINT fk_tblProject_companyID FOREIGN KEY (companyID) REFERENCES tblCompany (companyID),
  CONSTRAINT fk_tblProject_projectTypeID FOREIGN KEY (projectTypeID) REFERENCES tblProjectType (projectTypeID),
  CONSTRAINT fk_tblProject_projectStatusID FOREIGN KEY (projectStatusID) REFERENCES tblProjectStatus (projectStatusID),
  CONSTRAINT fk_tblProject_addressID FOREIGN KEY (addressID) REFERENCES tblAddress (addressID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserProject (
  userProjectID      INT NOT NULL AUTO_INCREMENT,
  userID             INT NOT NULL,
  projectID          INT NOT NULL,
  userProjectActive  TINYINT(1) NOT NULL DEFAULT 1,
  userProjectMFD     TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (userProjectID),
  UNIQUE KEY uk_tblUserProject_userID_projectID (userID, projectID),
  CONSTRAINT fk_tblUserProject_userID FOREIGN KEY (userID) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblUserProject_projectID FOREIGN KEY (projectID) REFERENCES tblProject (projectID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Terminals (GAP-09, D18, D20) ───────────

CREATE TABLE tblTerminalType (
  terminalTypeID     INT NOT NULL AUTO_INCREMENT,
  terminalTypeName   VARCHAR(100) NOT NULL,
  terminalTypeActive TINYINT(1) NOT NULL DEFAULT 1,
  terminalTypeMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (terminalTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblTerminal (
  terminalID          INT NOT NULL AUTO_INCREMENT,
  companyID           INT NOT NULL,
  terminalTypeID      INT NOT NULL,
  addressID           INT NULL,
  terminalName        VARCHAR(100) NOT NULL,
  terminalPlateNumber VARCHAR(20) NULL,
  terminalQrEnabled   TINYINT(1) NOT NULL DEFAULT 1,
  terminalDeviceName  VARCHAR(100) NULL,
  terminalSecretHash  VARCHAR(255) NULL,
  terminalLastSeen    DATETIME NULL,
  terminalActive      TINYINT(1) NOT NULL DEFAULT 1,
  terminalMFD         TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (terminalID),
  CONSTRAINT fk_tblTerminal_companyID FOREIGN KEY (companyID) REFERENCES tblCompany (companyID),
  CONSTRAINT fk_tblTerminal_terminalTypeID FOREIGN KEY (terminalTypeID) REFERENCES tblTerminalType (terminalTypeID),
  CONSTRAINT fk_tblTerminal_addressID FOREIGN KEY (addressID) REFERENCES tblAddress (addressID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Links on existing tables ───────────────

ALTER TABLE tblTimeReg
  ADD COLUMN companyID INT NULL,
  ADD COLUMN projectID INT NULL,
  ADD COLUMN terminalID INT NULL,
  ADD CONSTRAINT fk_tblTimeReg_companyID FOREIGN KEY (companyID) REFERENCES tblCompany (companyID),
  ADD CONSTRAINT fk_tblTimeReg_projectID FOREIGN KEY (projectID) REFERENCES tblProject (projectID),
  ADD CONSTRAINT fk_tblTimeReg_terminalID FOREIGN KEY (terminalID) REFERENCES tblTerminal (terminalID);

ALTER TABLE tblEventLog
  ADD COLUMN projectID INT NULL,
  ADD COLUMN userProjectID INT NULL,
  ADD COLUMN terminalID INT NULL,
  ADD CONSTRAINT fk_tblEventLog_projectID FOREIGN KEY (projectID) REFERENCES tblProject (projectID),
  ADD CONSTRAINT fk_tblEventLog_userProjectID FOREIGN KEY (userProjectID) REFERENCES tblUserProject (userProjectID),
  ADD CONSTRAINT fk_tblEventLog_terminalID FOREIGN KEY (terminalID) REFERENCES tblTerminal (terminalID);

-- ── Lookup rows ────────────────────────────

INSERT INTO tblProjectType (projectTypeName) VALUES ('Client'), ('Internal');
INSERT INTO tblProjectStatus (projectStatusName) VALUES ('Planned'), ('Active'), ('Completed');
INSERT INTO tblTerminalType (terminalTypeName) VALUES ('Office'), ('Vehicle');
INSERT INTO tblTimeRegType (timeRegTypeName) VALUES
  ('Activity – Work'), ('Activity – Client on site'), ('Activity – Client in-house'),
  ('Activity – Internal'), ('Activity – Transport');
