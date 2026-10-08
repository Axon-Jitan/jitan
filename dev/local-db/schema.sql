-- Jitan: LOCAL, DISPOSABLE development database. Not the IT database.
--
-- Built from docs/database/ERD.jpg (authoritative) and ERD.md. Every table,
-- column, primary key, unique key (UK), foreign key and unique pair (yellow
-- fields) of the ERD is here; nothing else is.
--
-- The ERD gives logical types only. Physical choices made here (to confirm
-- against the real IT database, see dev/local-db/README.md):
--   int      -> INT, primary keys AUTO_INCREMENT
--   String   -> VARCHAR(255)
--   bool     -> BOOLEAN (TINYINT(1))
--   DateTime -> DATETIME
--   double   -> DOUBLE
--   non-key columns are NULL-able and have no defaults: Jitan must set
--   every value it relies on.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ── People and organisation ──────────────────────────────────────────────

CREATE TABLE tblUser (
  userID          INT          NOT NULL AUTO_INCREMENT,
  userName        VARCHAR(255) NULL,
  userSurname     VARCHAR(255) NULL,
  userEmail       VARCHAR(255) NULL,
  cellphoneNumber VARCHAR(255) NULL,
  userCode        VARCHAR(255) NULL,
  userQRcode      VARCHAR(255) NULL,
  userPassword    VARCHAR(255) NULL,
  userKioskMode   BOOLEAN      NULL,
  userPINCode     VARCHAR(255) NULL,
  userActive      BOOLEAN      NULL,
  userMFD         BOOLEAN      NULL,
  PRIMARY KEY (userID),
  UNIQUE KEY uk_tblUser_userCode (userCode),
  UNIQUE KEY uk_tblUser_userQRcode (userQRcode)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblCompany (
  companyID     INT          NOT NULL AUTO_INCREMENT,
  companyName   VARCHAR(255) NULL,
  companyActive BOOLEAN      NULL,
  companyMFD    BOOLEAN      NULL,
  PRIMARY KEY (companyID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Active/MFD approved by IT (2026-10-08). Column names follow the ERD's
-- <entity>Active / <entity>MFD convention; confirm against IT's updated spec.
CREATE TABLE tblUserCompany (
  userCompanyID     INT     NOT NULL AUTO_INCREMENT,
  userID            INT     NOT NULL,
  companyID         INT     NOT NULL,
  userCompanyActive BOOLEAN NULL,
  userCompanyMFD    BOOLEAN NULL,
  PRIMARY KEY (userCompanyID),
  UNIQUE KEY uk_tblUserCompany_pair (userID, companyID),
  CONSTRAINT fk_tblUserCompany_user FOREIGN KEY (userID) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblUserCompany_company FOREIGN KEY (companyID) REFERENCES tblCompany (companyID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblGroup (
  groupID     INT          NOT NULL AUTO_INCREMENT,
  groupName   VARCHAR(255) NULL,
  groupActive BOOLEAN      NULL,
  groupMFD    BOOLEAN      NULL,
  PRIMARY KEY (groupID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Active/MFD approved by IT (2026-10-08); names as for tblUserCompany.
CREATE TABLE tblUserGroup (
  userGroupID     INT     NOT NULL AUTO_INCREMENT,
  userID          INT     NOT NULL,
  groupID         INT     NOT NULL,
  userGroupActive BOOLEAN NULL,
  userGroupMFD    BOOLEAN NULL,
  PRIMARY KEY (userGroupID),
  UNIQUE KEY uk_tblUserGroup_pair (userID, groupID),
  CONSTRAINT fk_tblUserGroup_user FOREIGN KEY (userID) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblUserGroup_group FOREIGN KEY (groupID) REFERENCES tblGroup (groupID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Authorization ────────────────────────────────────────────────────────

CREATE TABLE tblCredGroup (
  credGroupID     INT          NOT NULL AUTO_INCREMENT,
  credGroupName   VARCHAR(255) NULL,
  credGroupLevel  INT          NULL,
  credGroupActive BOOLEAN      NULL,
  credGroupMFD    BOOLEAN      NULL,
  PRIMARY KEY (credGroupID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserCredGroup (
  userCredGroupID INT NOT NULL AUTO_INCREMENT,
  userID          INT NOT NULL,
  credGroupID     INT NOT NULL,
  PRIMARY KEY (userCredGroupID),
  UNIQUE KEY uk_tblUserCredGroup_pair (userID, credGroupID),
  CONSTRAINT fk_tblUserCredGroup_user FOREIGN KEY (userID) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblUserCredGroup_credGroup FOREIGN KEY (credGroupID) REFERENCES tblCredGroup (credGroupID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblAppModules (
  appModulesID    INT          NOT NULL AUTO_INCREMENT,
  appModuleName   VARCHAR(255) NULL,
  appModuleActive BOOLEAN      NULL,
  appModuleMFD    BOOLEAN      NULL,
  PRIMARY KEY (appModulesID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblAppModulesCredGroup (
  appModulesCredGroupID INT NOT NULL AUTO_INCREMENT,
  appModulesID          INT NOT NULL,
  credGroupID           INT NOT NULL,
  PRIMARY KEY (appModulesCredGroupID),
  UNIQUE KEY uk_tblAppModulesCredGroup_pair (appModulesID, credGroupID),
  CONSTRAINT fk_tblAppModulesCredGroup_module FOREIGN KEY (appModulesID) REFERENCES tblAppModules (appModulesID),
  CONSTRAINT fk_tblAppModulesCredGroup_credGroup FOREIGN KEY (credGroupID) REFERENCES tblCredGroup (credGroupID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblFunction (
  functionID     INT          NOT NULL AUTO_INCREMENT,
  functionName   VARCHAR(255) NULL,
  functionActive BOOLEAN      NULL,
  functionMFD    BOOLEAN      NULL,
  PRIMARY KEY (functionID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserFunction (
  userFunctionID INT NOT NULL AUTO_INCREMENT,
  userID         INT NOT NULL,
  functionID     INT NOT NULL,
  PRIMARY KEY (userFunctionID),
  UNIQUE KEY uk_tblUserFunction_pair (userID, functionID),
  CONSTRAINT fk_tblUserFunction_user FOREIGN KEY (userID) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblUserFunction_function FOREIGN KEY (functionID) REFERENCES tblFunction (functionID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Languages ────────────────────────────────────────────────────────────

CREATE TABLE tblLanguage (
  languageID     INT          NOT NULL AUTO_INCREMENT,
  languageName   VARCHAR(255) NULL,
  languageCode   VARCHAR(255) NULL,
  languageActive BOOLEAN      NULL,
  languageMFD    BOOLEAN      NULL,
  PRIMARY KEY (languageID),
  UNIQUE KEY uk_tblLanguage_languageCode (languageCode)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserLanguage (
  userLanguageID INT NOT NULL AUTO_INCREMENT,
  userID         INT NOT NULL,
  languageID     INT NOT NULL,
  PRIMARY KEY (userLanguageID),
  UNIQUE KEY uk_tblUserLanguage_pair (userID, languageID),
  CONSTRAINT fk_tblUserLanguage_user FOREIGN KEY (userID) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblUserLanguage_language FOREIGN KEY (languageID) REFERENCES tblLanguage (languageID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ERD.jpg marks languageID + translationUIName as a unique pair.
CREATE TABLE tblTranslation (
  translationID     INT          NOT NULL AUTO_INCREMENT,
  languageID        INT          NOT NULL,
  translationUIName VARCHAR(255) NOT NULL,
  translationUIText VARCHAR(255) NULL,
  PRIMARY KEY (translationID),
  UNIQUE KEY uk_tblTranslation_pair (languageID, translationUIName),
  CONSTRAINT fk_tblTranslation_language FOREIGN KEY (languageID) REFERENCES tblLanguage (languageID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Schedules and rounding ───────────────────────────────────────────────

CREATE TABLE tblScheduleType (
  scheduleTypeID     INT          NOT NULL AUTO_INCREMENT,
  scheduleTypeName   VARCHAR(255) NULL,
  scheduleTypeActive BOOLEAN      NULL,
  scheduleTypeMFD    BOOLEAN      NULL,
  PRIMARY KEY (scheduleTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblDays (
  dayID     INT          NOT NULL AUTO_INCREMENT,
  dayName   VARCHAR(255) NULL,
  dayActive BOOLEAN      NULL,
  dayMFD    BOOLEAN      NULL,
  PRIMARY KEY (dayID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblSchedule (
  scheduleID        INT     NOT NULL AUTO_INCREMENT,
  scheduleTypeID    INT     NULL,
  dayID             INT     NULL,
  scheduleHrStart   INT     NULL,
  scheduleMinStart  INT     NULL,
  scheduleHrStop    INT     NULL,
  scheduleMinStop   INT     NULL,
  scheduleMarginMin INT     NULL,
  scheduleActive    BOOLEAN NULL,
  scheduleMFD       BOOLEAN NULL,
  PRIMARY KEY (scheduleID),
  CONSTRAINT fk_tblSchedule_type FOREIGN KEY (scheduleTypeID) REFERENCES tblScheduleType (scheduleTypeID),
  CONSTRAINT fk_tblSchedule_day FOREIGN KEY (dayID) REFERENCES tblDays (dayID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblUserSchedule (
  userScheduleID INT NOT NULL AUTO_INCREMENT,
  userID         INT NOT NULL,
  scheduleID     INT NOT NULL,
  PRIMARY KEY (userScheduleID),
  UNIQUE KEY uk_tblUserSchedule_pair (userID, scheduleID),
  CONSTRAINT fk_tblUserSchedule_user FOREIGN KEY (userID) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblUserSchedule_schedule FOREIGN KEY (scheduleID) REFERENCES tblSchedule (scheduleID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblRoundingRule (
  roundingRuleID         INT     NOT NULL AUTO_INCREMENT,
  roundingRuleValueInMin INT     NULL,
  roundingRuleRoundUp    BOOLEAN NULL,
  roundingRuleActive     BOOLEAN NULL,
  roundingRuleMFD        BOOLEAN NULL,
  PRIMARY KEY (roundingRuleID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblScheduleRoundingRule (
  scheduleRoundingRuleID INT NOT NULL AUTO_INCREMENT,
  scheduleID             INT NOT NULL,
  roundingRuleID         INT NOT NULL,
  PRIMARY KEY (scheduleRoundingRuleID),
  UNIQUE KEY uk_tblScheduleRoundingRule_pair (scheduleID, roundingRuleID),
  CONSTRAINT fk_tblScheduleRoundingRule_schedule FOREIGN KEY (scheduleID) REFERENCES tblSchedule (scheduleID),
  CONSTRAINT fk_tblScheduleRoundingRule_rule FOREIGN KEY (roundingRuleID) REFERENCES tblRoundingRule (roundingRuleID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Locations, geofences, time registration ──────────────────────────────

CREATE TABLE tblAddress (
  addressID          INT          NOT NULL AUTO_INCREMENT,
  addressStreet      VARCHAR(255) NULL,
  addressNumber      VARCHAR(255) NULL,
  addressBoxNumber   VARCHAR(255) NULL,
  addressZipcode     VARCHAR(255) NULL,
  addressCity        VARCHAR(255) NULL,
  addressLogicalName VARCHAR(255) NULL,
  addressCoordinates VARCHAR(255) NULL,
  addressActive      BOOLEAN      NULL,
  addressMFD         BOOLEAN      NULL,
  PRIMARY KEY (addressID),
  UNIQUE KEY uk_tblAddress_addressLogicalName (addressLogicalName)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblLocationType (
  locationTypeID     INT          NOT NULL AUTO_INCREMENT,
  locationTypeName   VARCHAR(255) NULL,
  locationTypeActive BOOLEAN      NULL,
  locationTypeMFD    BOOLEAN      NULL,
  PRIMARY KEY (locationTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblAddressLocationType (
  addressLocationTypeID INT NOT NULL AUTO_INCREMENT,
  addressID             INT NOT NULL,
  locationTypeID        INT NOT NULL,
  PRIMARY KEY (addressLocationTypeID),
  UNIQUE KEY uk_tblAddressLocationType_pair (addressID, locationTypeID),
  CONSTRAINT fk_tblAddressLocationType_address FOREIGN KEY (addressID) REFERENCES tblAddress (addressID),
  CONSTRAINT fk_tblAddressLocationType_type FOREIGN KEY (locationTypeID) REFERENCES tblLocationType (locationTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblGeofence (
  geofenceID              INT     NOT NULL AUTO_INCREMENT,
  geofenceRadiusInMeter   DOUBLE  NULL,
  geofenceCorrectionInMin INT     NULL,
  geofenceActive          BOOLEAN NULL,
  geofenceMFD             BOOLEAN NULL,
  PRIMARY KEY (geofenceID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblGeofenceAddress (
  geofenceAddressID INT NOT NULL AUTO_INCREMENT,
  geofenceID        INT NOT NULL,
  addressID         INT NOT NULL,
  PRIMARY KEY (geofenceAddressID),
  UNIQUE KEY uk_tblGeofenceAddress_pair (geofenceID, addressID),
  CONSTRAINT fk_tblGeofenceAddress_geofence FOREIGN KEY (geofenceID) REFERENCES tblGeofence (geofenceID),
  CONSTRAINT fk_tblGeofenceAddress_address FOREIGN KEY (addressID) REFERENCES tblAddress (addressID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblTimeRegType (
  timeRegTypeID     INT          NOT NULL AUTO_INCREMENT,
  timeRegTypeName   VARCHAR(255) NULL,
  timeRegTypeActive BOOLEAN      NULL,
  timeRegTypeMFD    BOOLEAN      NULL,
  PRIMARY KEY (timeRegTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblTimeReg (
  timeRegID           INT          NOT NULL AUTO_INCREMENT,
  userID              INT          NULL,
  addressID           INT          NULL,
  timeRegTypeID       INT          NULL,
  timeRegTimestamp    DATETIME     NULL,
  timeRegManualEntry  BOOLEAN      NULL,
  timeRegComment      VARCHAR(255) NULL,
  timeRegWhenModified DATETIME     NULL,
  timeRegActive       BOOLEAN      NULL,
  timeRegMFD          BOOLEAN      NULL,
  PRIMARY KEY (timeRegID),
  CONSTRAINT fk_tblTimeReg_user FOREIGN KEY (userID) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblTimeReg_address FOREIGN KEY (addressID) REFERENCES tblAddress (addressID),
  CONSTRAINT fk_tblTimeReg_type FOREIGN KEY (timeRegTypeID) REFERENCES tblTimeRegType (timeRegTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ── Audit ────────────────────────────────────────────────────────────────

CREATE TABLE tblEventType (
  eventTypeID   INT          NOT NULL AUTO_INCREMENT,
  eventTypeName VARCHAR(255) NULL,
  PRIMARY KEY (eventTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblEventLog (
  eventLogID             INT      NOT NULL AUTO_INCREMENT,
  eventLogTimestamp      DATETIME NULL,
  userIDInit             INT      NULL,
  userIDTarget           INT      NULL,
  roundingRuleID         INT      NULL,
  scheduleRoundingRuleID INT      NULL,
  appModulesCredGroupID  INT      NULL,
  appModulesID           INT      NULL,
  credGroupID            INT      NULL,
  userCredGroupID        INT      NULL,
  functionID             INT      NULL,
  userfunctionID         INT      NULL,
  userScheduleID         INT      NULL,
  scheduleID             INT      NULL,
  scheduleTypeID         INT      NULL,
  dayID                  INT      NULL,
  geofenceID             INT      NULL,
  geofenceAddressID      INT      NULL,
  groupID                INT      NULL,
  userGroupID            INT      NULL,
  companyID              INT      NULL,
  userCompanyID          INT      NULL,
  timeRegID              INT      NULL,
  addressID              INT      NULL,
  timeRegTypeID          INT      NULL,
  locationTypeID         INT      NULL,
  addressLocationTypeID  INT      NULL,
  PRIMARY KEY (eventLogID),
  CONSTRAINT fk_tblEventLog_userInit FOREIGN KEY (userIDInit) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblEventLog_userTarget FOREIGN KEY (userIDTarget) REFERENCES tblUser (userID),
  CONSTRAINT fk_tblEventLog_roundingRule FOREIGN KEY (roundingRuleID) REFERENCES tblRoundingRule (roundingRuleID),
  CONSTRAINT fk_tblEventLog_scheduleRoundingRule FOREIGN KEY (scheduleRoundingRuleID) REFERENCES tblScheduleRoundingRule (scheduleRoundingRuleID),
  CONSTRAINT fk_tblEventLog_appModulesCredGroup FOREIGN KEY (appModulesCredGroupID) REFERENCES tblAppModulesCredGroup (appModulesCredGroupID),
  CONSTRAINT fk_tblEventLog_appModules FOREIGN KEY (appModulesID) REFERENCES tblAppModules (appModulesID),
  CONSTRAINT fk_tblEventLog_credGroup FOREIGN KEY (credGroupID) REFERENCES tblCredGroup (credGroupID),
  CONSTRAINT fk_tblEventLog_userCredGroup FOREIGN KEY (userCredGroupID) REFERENCES tblUserCredGroup (userCredGroupID),
  CONSTRAINT fk_tblEventLog_function FOREIGN KEY (functionID) REFERENCES tblFunction (functionID),
  CONSTRAINT fk_tblEventLog_userFunction FOREIGN KEY (userfunctionID) REFERENCES tblUserFunction (userFunctionID),
  CONSTRAINT fk_tblEventLog_userSchedule FOREIGN KEY (userScheduleID) REFERENCES tblUserSchedule (userScheduleID),
  CONSTRAINT fk_tblEventLog_schedule FOREIGN KEY (scheduleID) REFERENCES tblSchedule (scheduleID),
  CONSTRAINT fk_tblEventLog_scheduleType FOREIGN KEY (scheduleTypeID) REFERENCES tblScheduleType (scheduleTypeID),
  CONSTRAINT fk_tblEventLog_day FOREIGN KEY (dayID) REFERENCES tblDays (dayID),
  CONSTRAINT fk_tblEventLog_geofence FOREIGN KEY (geofenceID) REFERENCES tblGeofence (geofenceID),
  CONSTRAINT fk_tblEventLog_geofenceAddress FOREIGN KEY (geofenceAddressID) REFERENCES tblGeofenceAddress (geofenceAddressID),
  CONSTRAINT fk_tblEventLog_group FOREIGN KEY (groupID) REFERENCES tblGroup (groupID),
  CONSTRAINT fk_tblEventLog_userGroup FOREIGN KEY (userGroupID) REFERENCES tblUserGroup (userGroupID),
  CONSTRAINT fk_tblEventLog_company FOREIGN KEY (companyID) REFERENCES tblCompany (companyID),
  CONSTRAINT fk_tblEventLog_userCompany FOREIGN KEY (userCompanyID) REFERENCES tblUserCompany (userCompanyID),
  CONSTRAINT fk_tblEventLog_timeReg FOREIGN KEY (timeRegID) REFERENCES tblTimeReg (timeRegID),
  CONSTRAINT fk_tblEventLog_address FOREIGN KEY (addressID) REFERENCES tblAddress (addressID),
  CONSTRAINT fk_tblEventLog_timeRegType FOREIGN KEY (timeRegTypeID) REFERENCES tblTimeRegType (timeRegTypeID),
  CONSTRAINT fk_tblEventLog_locationType FOREIGN KEY (locationTypeID) REFERENCES tblLocationType (locationTypeID),
  CONSTRAINT fk_tblEventLog_addressLocationType FOREIGN KEY (addressLocationTypeID) REFERENCES tblAddressLocationType (addressLocationTypeID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tblEventLogEventType (
  eventLogEventTypeID INT NOT NULL AUTO_INCREMENT,
  eventTypeID         INT NOT NULL,
  eventLogID          INT NOT NULL,
  PRIMARY KEY (eventLogEventTypeID),
  UNIQUE KEY uk_tblEventLogEventType_pair (eventTypeID, eventLogID),
  CONSTRAINT fk_tblEventLogEventType_type FOREIGN KEY (eventTypeID) REFERENCES tblEventType (eventTypeID),
  CONSTRAINT fk_tblEventLogEventType_log FOREIGN KEY (eventLogID) REFERENCES tblEventLog (eventLogID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

SET FOREIGN_KEY_CHECKS = 1;
