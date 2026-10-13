-- Jitan: LOCAL, DISPOSABLE development database. Not the IT database.
--
-- Mirrors IT's development database (`jitandev`, exported from
-- information_schema on 2026-10-09): every table, column, type, length,
-- NULL/NOT NULL, default, primary key, unique key/pair and foreign key, with
-- IT's constraint names. Nothing else. docs/database/ERD.jpg remains the
-- logical model; this file is its physical form as IT built it.
--
-- Regenerate from a fresh export when IT changes the schema; never add
-- anything IT's database does not have. Character set, collation and the two
-- non-key indexes come from IT's creation script (jitandev_schema.sql, received
-- 2026-10-13): utf8mb4 / utf8mb4_0900_ai_ci.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ── People and organisation ───────────────────────────────────────────────

CREATE TABLE tblUser (
  userID          INT NOT NULL AUTO_INCREMENT,
  userName        VARCHAR(100) NOT NULL,
  userSurname     VARCHAR(100) NOT NULL,
  userEmail       VARCHAR(255) NULL,
  cellphoneNumber VARCHAR(30) NULL,
  userCode        VARCHAR(50) NOT NULL,
  userQRcode      VARCHAR(255) NULL,
  userPassword    VARCHAR(255) NULL,
  userKioskMode   TINYINT(1) NOT NULL DEFAULT 0,
  userPINCode     VARCHAR(255) NULL,
  userActive      TINYINT(1) NOT NULL DEFAULT 1,
  userMFD         TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (userID),
  UNIQUE KEY uk_tblUser_userCode (userCode),
  UNIQUE KEY uk_tblUser_userQRcode (userQRcode)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblCompany (
  companyID     INT NOT NULL AUTO_INCREMENT,
  companyName   VARCHAR(150) NOT NULL,
  companyActive TINYINT(1) NOT NULL DEFAULT 1,
  companyMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (companyID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserCompany (
  userCompanyID     INT NOT NULL AUTO_INCREMENT,
  userID            INT NOT NULL,
  companyID         INT NOT NULL,
  userCompanyActive TINYINT(1) NOT NULL DEFAULT 1,
  userCompanyMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (userCompanyID),
  UNIQUE KEY uk_tblUserCompany_userID_companyID (userID, companyID),
  CONSTRAINT fk_tblUserCompany_companyID FOREIGN KEY (companyID) REFERENCES tblCompany (companyID),
  CONSTRAINT fk_tblUserCompany_userID FOREIGN KEY (userID) REFERENCES tblUser (userID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblGroup (
  groupID     INT NOT NULL AUTO_INCREMENT,
  groupName   VARCHAR(100) NOT NULL,
  groupActive TINYINT(1) NOT NULL DEFAULT 1,
  groupMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (groupID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserGroup (
  userGroupID     INT NOT NULL AUTO_INCREMENT,
  userID          INT NOT NULL,
  groupID         INT NOT NULL,
  userGroupActive TINYINT(1) NOT NULL DEFAULT 1,
  userGroupMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (userGroupID),
  UNIQUE KEY uk_tblUserGroup_userID_groupID (userID, groupID),
  CONSTRAINT fk_tblUserGroup_groupID FOREIGN KEY (groupID) REFERENCES tblGroup (groupID),
  CONSTRAINT fk_tblUserGroup_userID FOREIGN KEY (userID) REFERENCES tblUser (userID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Authorization ─────────────────────────────────────────────────────────

CREATE TABLE tblCredGroup (
  credGroupID     INT NOT NULL AUTO_INCREMENT,
  credGroupName   VARCHAR(100) NOT NULL,
  credGroupLevel  INT NOT NULL DEFAULT 0,
  credGroupActive TINYINT(1) NOT NULL DEFAULT 1,
  credGroupMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (credGroupID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserCredGroup (
  userCredGroupID     INT NOT NULL AUTO_INCREMENT,
  userID              INT NOT NULL,
  credGroupID         INT NOT NULL,
  userCredGroupActive TINYINT(1) NOT NULL DEFAULT 1,
  userCredGroupMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (userCredGroupID),
  UNIQUE KEY uk_tblUserCredGroup_userID_credGroupID (userID, credGroupID),
  CONSTRAINT fk_tblUserCredGroup_credGroupID FOREIGN KEY (credGroupID) REFERENCES tblCredGroup (credGroupID),
  CONSTRAINT fk_tblUserCredGroup_userID FOREIGN KEY (userID) REFERENCES tblUser (userID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblAppModules (
  appModulesID    INT NOT NULL AUTO_INCREMENT,
  appModuleName   VARCHAR(100) NOT NULL,
  appModuleActive TINYINT(1) NOT NULL DEFAULT 1,
  appModuleMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (appModulesID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblAppModulesCredGroup (
  appModulesCredGroupID     INT NOT NULL AUTO_INCREMENT,
  appModulesID              INT NOT NULL,
  credGroupID               INT NOT NULL,
  appModulesCredGroupActive TINYINT(1) NOT NULL DEFAULT 1,
  appModulesCredGroupMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (appModulesCredGroupID),
  UNIQUE KEY uk_tblAppModulesCredGroup_appModulesID_credGroupID (appModulesID, credGroupID),
  CONSTRAINT fk_tblAppModulesCredGroup_appModulesID FOREIGN KEY (appModulesID) REFERENCES tblAppModules (appModulesID),
  CONSTRAINT fk_tblAppModulesCredGroup_credGroupID FOREIGN KEY (credGroupID) REFERENCES tblCredGroup (credGroupID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblFunction (
  functionID     INT NOT NULL AUTO_INCREMENT,
  functionName   VARCHAR(100) NOT NULL,
  functionActive TINYINT(1) NOT NULL DEFAULT 1,
  functionMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (functionID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserFunction (
  userFunctionID     INT NOT NULL AUTO_INCREMENT,
  userID             INT NOT NULL,
  functionID         INT NOT NULL,
  userFunctionActive TINYINT(1) NOT NULL DEFAULT 1,
  userFunctionMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (userFunctionID),
  UNIQUE KEY uk_tblUserFunction_userID_functionID (userID, functionID),
  CONSTRAINT fk_tblUserFunction_functionID FOREIGN KEY (functionID) REFERENCES tblFunction (functionID),
  CONSTRAINT fk_tblUserFunction_userID FOREIGN KEY (userID) REFERENCES tblUser (userID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Languages ─────────────────────────────────────────────────────────────

CREATE TABLE tblLanguage (
  languageID     INT NOT NULL AUTO_INCREMENT,
  languageName   VARCHAR(100) NOT NULL,
  languageCode   VARCHAR(10) NOT NULL,
  languageActive TINYINT(1) NOT NULL DEFAULT 1,
  languageMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (languageID),
  UNIQUE KEY uk_tblLanguage_languageCode (languageCode)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserLanguage (
  userLanguageID     INT NOT NULL AUTO_INCREMENT,
  userID             INT NOT NULL,
  languageID         INT NOT NULL,
  userLanguageActive TINYINT(1) NOT NULL DEFAULT 1,
  userLanguageMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (userLanguageID),
  UNIQUE KEY uk_tblUserLanguage_userID_languageID (userID, languageID),
  CONSTRAINT fk_tblUserLanguage_languageID FOREIGN KEY (languageID) REFERENCES tblLanguage (languageID),
  CONSTRAINT fk_tblUserLanguage_userID FOREIGN KEY (userID) REFERENCES tblUser (userID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblTranslation (
  translationID     INT NOT NULL AUTO_INCREMENT,
  languageID        INT NOT NULL,
  translationUIName VARCHAR(150) NOT NULL,
  translationUIText TEXT NOT NULL,
  PRIMARY KEY (translationID),
  UNIQUE KEY uk_tblTranslation_languageID_UIName (languageID, translationUIName),
  CONSTRAINT fk_tblTranslation_languageID FOREIGN KEY (languageID) REFERENCES tblLanguage (languageID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Schedules and rounding ────────────────────────────────────────────────

CREATE TABLE tblScheduleType (
  scheduleTypeID     INT NOT NULL AUTO_INCREMENT,
  scheduleTypeName   VARCHAR(100) NOT NULL,
  scheduleTypeActive TINYINT(1) NOT NULL DEFAULT 1,
  scheduleTypeMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (scheduleTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblDays (
  dayID     INT NOT NULL AUTO_INCREMENT,
  dayName   VARCHAR(50) NOT NULL,
  dayActive TINYINT(1) NOT NULL DEFAULT 1,
  dayMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (dayID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblSchedule (
  scheduleID        INT NOT NULL AUTO_INCREMENT,
  scheduleTypeID    INT NOT NULL,
  dayID             INT NOT NULL,
  scheduleHrStart   INT NOT NULL,
  scheduleMinStart  INT NOT NULL,
  scheduleHrStop    INT NOT NULL,
  scheduleMinStop   INT NOT NULL,
  scheduleMarginMin INT NOT NULL DEFAULT 0,
  scheduleActive    TINYINT(1) NOT NULL DEFAULT 1,
  scheduleMFD       TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (scheduleID),
  CONSTRAINT fk_tblSchedule_dayID FOREIGN KEY (dayID) REFERENCES tblDays (dayID),
  CONSTRAINT fk_tblSchedule_scheduleTypeID FOREIGN KEY (scheduleTypeID) REFERENCES tblScheduleType (scheduleTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserSchedule (
  userScheduleID     INT NOT NULL AUTO_INCREMENT,
  userID             INT NOT NULL,
  scheduleID         INT NOT NULL,
  userScheduleActive TINYINT(1) NOT NULL DEFAULT 1,
  userScheduleMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (userScheduleID),
  UNIQUE KEY uk_tblUserSchedule_userID_scheduleID (userID, scheduleID),
  CONSTRAINT fk_tblUserSchedule_scheduleID FOREIGN KEY (scheduleID) REFERENCES tblSchedule (scheduleID),
  CONSTRAINT fk_tblUserSchedule_userID FOREIGN KEY (userID) REFERENCES tblUser (userID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblRoundingRule (
  roundingRuleID         INT NOT NULL AUTO_INCREMENT,
  roundingRuleValueInMin INT NOT NULL,
  roundingRuleRoundUp    TINYINT(1) NOT NULL DEFAULT 0,
  roundingRuleActive     TINYINT(1) NOT NULL DEFAULT 1,
  roundingRuleMFD        TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (roundingRuleID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblScheduleRoundingRule (
  scheduleRoundingRuleID     INT NOT NULL AUTO_INCREMENT,
  scheduleID                 INT NOT NULL,
  roundingRuleID             INT NOT NULL,
  scheduleRoundingRuleActive TINYINT(1) NOT NULL DEFAULT 1,
  scheduleRoundingRuleMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (scheduleRoundingRuleID),
  UNIQUE KEY uk_tblScheduleRoundingRule_scheduleID_roundingRuleID (scheduleID, roundingRuleID),
  CONSTRAINT fk_tblScheduleRoundingRule_roundingRuleID FOREIGN KEY (roundingRuleID) REFERENCES tblRoundingRule (roundingRuleID),
  CONSTRAINT fk_tblScheduleRoundingRule_scheduleID FOREIGN KEY (scheduleID) REFERENCES tblSchedule (scheduleID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Locations, geofences, time registration ───────────────────────────────

CREATE TABLE tblAddress (
  addressID          INT NOT NULL AUTO_INCREMENT,
  addressStreet      VARCHAR(150) NOT NULL,
  addressNumber      VARCHAR(20) NULL,
  addressZipcode     VARCHAR(20) NULL,
  addressCity        VARCHAR(100) NULL,
  addressLogicalName VARCHAR(100) NOT NULL,
  addressBoxNumber   VARCHAR(20) NULL,
  addressCoordinates VARCHAR(50) NULL,
  addressActive      TINYINT(1) NOT NULL DEFAULT 1,
  addressMFD         TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (addressID),
  UNIQUE KEY uk_tblAddress_addressLogicalName (addressLogicalName)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblLocationType (
  locationTypeID     INT NOT NULL AUTO_INCREMENT,
  locationTypeName   VARCHAR(100) NOT NULL,
  locationTypeActive TINYINT(1) NOT NULL DEFAULT 1,
  locationTypeMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (locationTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblAddressLocationType (
  addressLocationTypeID     INT NOT NULL AUTO_INCREMENT,
  addressID                 INT NOT NULL,
  locationTypeID            INT NOT NULL,
  addressLocationTypeActive TINYINT(1) NOT NULL DEFAULT 1,
  addressLocationTypeMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (addressLocationTypeID),
  UNIQUE KEY uk_tblAddressLocationType_addressID_locationTypeID (addressID, locationTypeID),
  CONSTRAINT fk_tblAddressLocationType_addressID FOREIGN KEY (addressID) REFERENCES tblAddress (addressID),
  CONSTRAINT fk_tblAddressLocationType_locationTypeID FOREIGN KEY (locationTypeID) REFERENCES tblLocationType (locationTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblGeofence (
  geofenceID              INT NOT NULL AUTO_INCREMENT,
  geofenceRadiusInMeter   DOUBLE NOT NULL,
  geofenceCorrectionInMin INT NOT NULL DEFAULT 0,
  geofenceActive          TINYINT(1) NOT NULL DEFAULT 1,
  geofenceMFD             TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (geofenceID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblGeofenceAddress (
  geofenceAddressID     INT NOT NULL AUTO_INCREMENT,
  geofenceID            INT NOT NULL,
  addressID             INT NOT NULL,
  geofenceAddressActive TINYINT(1) NOT NULL DEFAULT 1,
  geofenceAddressMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (geofenceAddressID),
  UNIQUE KEY uk_tblGeofenceAddress_geofenceID_addressID (geofenceID, addressID),
  CONSTRAINT fk_tblGeofenceAddress_addressID FOREIGN KEY (addressID) REFERENCES tblAddress (addressID),
  CONSTRAINT fk_tblGeofenceAddress_geofenceID FOREIGN KEY (geofenceID) REFERENCES tblGeofence (geofenceID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblTimeRegType (
  timeRegTypeID     INT NOT NULL AUTO_INCREMENT,
  timeRegTypeName   VARCHAR(100) NOT NULL,
  timeRegTypeActive TINYINT(1) NOT NULL DEFAULT 1,
  timeRegTypeMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (timeRegTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblTimeReg (
  timeRegID           INT NOT NULL AUTO_INCREMENT,
  userID              INT NOT NULL,
  addressID           INT NULL,
  timeRegTypeID       INT NOT NULL,
  timeRegTimestamp    DATETIME NOT NULL,
  timeRegManualEntry  TINYINT(1) NOT NULL DEFAULT 0,
  timeRegComment      VARCHAR(500) NULL,
  timeRegWhenModified DATETIME NULL,
  timeRegActive       TINYINT(1) NOT NULL DEFAULT 1,
  timeRegMFD          TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (timeRegID),
  INDEX ix_tblTimeReg_user_timestamp (userID, timeRegTimestamp),
  CONSTRAINT fk_tblTimeReg_addressID FOREIGN KEY (addressID) REFERENCES tblAddress (addressID),
  CONSTRAINT fk_tblTimeReg_timeRegTypeID FOREIGN KEY (timeRegTypeID) REFERENCES tblTimeRegType (timeRegTypeID),
  CONSTRAINT fk_tblTimeReg_userID FOREIGN KEY (userID) REFERENCES tblUser (userID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Audit ─────────────────────────────────────────────────────────────────

CREATE TABLE tblEventType (
  eventTypeID   INT NOT NULL AUTO_INCREMENT,
  eventTypeName VARCHAR(100) NOT NULL,
  PRIMARY KEY (eventTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblEventLog (
  eventLogID             INT NOT NULL AUTO_INCREMENT,
  eventLogTimestamp      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  userIDInit             INT NULL,
  userIDTarget           INT NULL,
  roundingRuleID         INT NULL,
  scheduleRoundingRuleID INT NULL,
  appModulesCredGroupID  INT NULL,
  appModulesID           INT NULL,
  credGroupID            INT NULL,
  userCredGroupID        INT NULL,
  functionID             INT NULL,
  userfunctionID         INT NULL,
  userScheduleID         INT NULL,
  scheduleID             INT NULL,
  scheduleTypeID         INT NULL,
  dayID                  INT NULL,
  geofenceID             INT NULL,
  geofenceAddressID      INT NULL,
  groupID                INT NULL,
  userGroupID            INT NULL,
  companyID              INT NULL,
  userCompanyID          INT NULL,
  timeRegID              INT NULL,
  addressID              INT NULL,
  timeRegTypeID          INT NULL,
  locationTypeID         INT NULL,
  addressLocationTypeID  INT NULL,
  PRIMARY KEY (eventLogID),
  INDEX ix_tblEventLog_timestamp (eventLogTimestamp),
  CONSTRAINT fk_tblEventLog_addressID FOREIGN KEY (addressID) REFERENCES tblAddress (addressID),
  CONSTRAINT fk_tblEventLog_addressLocationTypeID FOREIGN KEY (addressLocationTypeID) REFERENCES tblAddressLocationType (addressLocationTypeID),
  CONSTRAINT fk_tblEventLog_appModulesCredGroupID FOREIGN KEY (appModulesCredGroupID) REFERENCES tblAppModulesCredGroup (appModulesCredGroupID),
  CONSTRAINT fk_tblEventLog_appModulesID FOREIGN KEY (appModulesID) REFERENCES tblAppModules (appModulesID),
  CONSTRAINT fk_tblEventLog_companyID FOREIGN KEY (companyID) REFERENCES tblCompany (companyID),
  CONSTRAINT fk_tblEventLog_credGroupID FOREIGN KEY (credGroupID) REFERENCES tblCredGroup (credGroupID),
  CONSTRAINT fk_tblEventLog_dayID FOREIGN KEY (dayID) REFERENCES tblDays (dayID),
  CONSTRAINT fk_tblEventLog_functionID FOREIGN KEY (functionID) REFERENCES tblFunction (functionID),
  CONSTRAINT fk_tblEventLog_geofenceAddressID FOREIGN KEY (geofenceAddressID) REFERENCES tblGeofenceAddress (geofenceAddressID),
  CONSTRAINT fk_tblEventLog_geofenceID FOREIGN KEY (geofenceID) REFERENCES tblGeofence (geofenceID),
  CONSTRAINT fk_tblEventLog_groupID FOREIGN KEY (groupID) REFERENCES tblGroup (groupID),
  CONSTRAINT fk_tblEventLog_locationTypeID FOREIGN KEY (locationTypeID) REFERENCES tblLocationType (locationTypeID),
  CONSTRAINT fk_tblEventLog_roundingRuleID FOREIGN KEY (roundingRuleID) REFERENCES tblRoundingRule (roundingRuleID),
  CONSTRAINT fk_tblEventLog_scheduleID FOREIGN KEY (scheduleID) REFERENCES tblSchedule (scheduleID),
  CONSTRAINT fk_tblEventLog_scheduleRoundingRuleID FOREIGN KEY (scheduleRoundingRuleID) REFERENCES tblScheduleRoundingRule (scheduleRoundingRuleID),
  CONSTRAINT fk_tblEventLog_scheduleTypeID FOREIGN KEY (scheduleTypeID) REFERENCES tblScheduleType (scheduleTypeID),
  CONSTRAINT fk_tblEventLog_timeRegID FOREIGN KEY (timeRegID) REFERENCES tblTimeReg (timeRegID),
  CONSTRAINT fk_tblEventLog_timeRegTypeID FOREIGN KEY (timeRegTypeID) REFERENCES tblTimeRegType (timeRegTypeID),
  CONSTRAINT fk_tblEventLog_userCompanyID FOREIGN KEY (userCompanyID) REFERENCES tblUserCompany (userCompanyID),
  CONSTRAINT fk_tblEventLog_userCredGroupID FOREIGN KEY (userCredGroupID) REFERENCES tblUserCredGroup (userCredGroupID),
  CONSTRAINT fk_tblEventLog_userGroupID FOREIGN KEY (userGroupID) REFERENCES tblUserGroup (userGroupID),
  CONSTRAINT fk_tblEventLog_userIDInit FOREIGN KEY (userIDInit) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblEventLog_userIDTarget FOREIGN KEY (userIDTarget) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblEventLog_userScheduleID FOREIGN KEY (userScheduleID) REFERENCES tblUserSchedule (userScheduleID),
  CONSTRAINT fk_tblEventLog_userfunctionID FOREIGN KEY (userfunctionID) REFERENCES tblUserFunction (userFunctionID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblEventLogEventType (
  eventLogEventTypeID     INT NOT NULL AUTO_INCREMENT,
  eventTypeID             INT NOT NULL,
  eventLogID              INT NOT NULL,
  eventLogEventTypeActive TINYINT(1) NOT NULL DEFAULT 1,
  eventLogEventTypeMFD    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (eventLogEventTypeID),
  UNIQUE KEY uk_tblEventLogEventType_eventLogID_eventTypeID (eventLogID, eventTypeID),
  CONSTRAINT fk_tblEventLogEventType_eventLogID FOREIGN KEY (eventLogID) REFERENCES tblEventLog (eventLogID),
  CONSTRAINT fk_tblEventLogEventType_eventTypeID FOREIGN KEY (eventTypeID) REFERENCES tblEventType (eventTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

SET FOREIGN_KEY_CHECKS = 1;
