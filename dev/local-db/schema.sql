-- Jitan: LOCAL, DISPOSABLE development database. Not the IT database.
--
-- Mirrors IT's development database (`jitandev`) exactly: generated on 2026-11-10 from
-- `SHOW CREATE TABLE` of every table there (read-only), after IT applied its ERD of
-- 2026-11-09 (39 tables). Every table, column, type, length, NULL/NOT NULL, default,
-- collation (utf8mb4_0900_as_cs), primary key, unique key and foreign key, with IT's
-- constraint names. Nothing else. docs/database/ERD.jpg remains the logical model.
--
-- Regenerate the same way when IT changes the schema; never add anything IT's database
-- does not have (local-only proposals live in proposals/).

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE `tblAddress` (
  `addressID` int NOT NULL AUTO_INCREMENT,
  `addressStreet` varchar(150) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `addressNumber` varchar(20) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `addressZipcode` varchar(20) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `addressCity` varchar(100) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `addressLogicalName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `addressBoxNumber` varchar(20) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `addressCoordinates` varchar(50) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `addressActive` tinyint(1) NOT NULL DEFAULT '1',
  `addressMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`addressID`),
  UNIQUE KEY `uk_tblAddress_addressLogicalName` (`addressLogicalName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblAddressLocationType` (
  `addressLocationTypeID` int NOT NULL AUTO_INCREMENT,
  `addressID` int NOT NULL,
  `locationTypeID` int NOT NULL,
  `addressLocationTypeActive` tinyint(1) NOT NULL DEFAULT '1',
  `addressLocationTypeMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`addressLocationTypeID`),
  UNIQUE KEY `uk_tblAddressLocationType_addressID_locationTypeID` (`addressID`,`locationTypeID`),
  KEY `fk_tblAddressLocationType_locationTypeID` (`locationTypeID`),
  CONSTRAINT `fk_tblAddressLocationType_addressID` FOREIGN KEY (`addressID`) REFERENCES `tblAddress` (`addressID`),
  CONSTRAINT `fk_tblAddressLocationType_locationTypeID` FOREIGN KEY (`locationTypeID`) REFERENCES `tblLocationType` (`locationTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblAppModules` (
  `appModulesID` int NOT NULL AUTO_INCREMENT,
  `appModuleName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `appModuleActive` tinyint(1) NOT NULL DEFAULT '1',
  `appModuleMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`appModulesID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblAppModulesCredGroup` (
  `appModulesCredGroupID` int NOT NULL AUTO_INCREMENT,
  `appModulesID` int NOT NULL,
  `credGroupID` int NOT NULL,
  `appModulesCredGroupActive` tinyint(1) NOT NULL DEFAULT '1',
  `appModulesCredGroupMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`appModulesCredGroupID`),
  UNIQUE KEY `uk_tblAppModulesCredGroup_appModulesID_credGroupID` (`appModulesID`,`credGroupID`),
  KEY `fk_tblAppModulesCredGroup_credGroupID` (`credGroupID`),
  CONSTRAINT `fk_tblAppModulesCredGroup_appModulesID` FOREIGN KEY (`appModulesID`) REFERENCES `tblAppModules` (`appModulesID`),
  CONSTRAINT `fk_tblAppModulesCredGroup_credGroupID` FOREIGN KEY (`credGroupID`) REFERENCES `tblCredGroup` (`credGroupID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblCompany` (
  `companyID` int NOT NULL AUTO_INCREMENT,
  `companyName` varchar(150) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `companyActive` tinyint(1) NOT NULL DEFAULT '1',
  `companyMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`companyID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblConfigType` (
  `configTypeID` int NOT NULL AUTO_INCREMENT,
  `configType` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `configTypeActive` tinyint(1) NOT NULL DEFAULT '1',
  `configTypeMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`configTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblConfiguration` (
  `configurationID` int NOT NULL AUTO_INCREMENT,
  `configTypeID` int NOT NULL,
  `configurationKey` varchar(150) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `configurationValue` text COLLATE utf8mb4_0900_as_cs,
  `configurationActive` tinyint(1) NOT NULL DEFAULT '1',
  `configurationMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`configurationID`),
  UNIQUE KEY `uk_tblConfiguration_configurationKey` (`configurationKey`),
  KEY `fk_tblConfiguration_configTypeID` (`configTypeID`),
  CONSTRAINT `fk_tblConfiguration_configTypeID` FOREIGN KEY (`configTypeID`) REFERENCES `tblConfigType` (`configTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblCredGroup` (
  `credGroupID` int NOT NULL AUTO_INCREMENT,
  `credGroupName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `credGroupLevel` int NOT NULL DEFAULT '0',
  `credGroupActive` tinyint(1) NOT NULL DEFAULT '1',
  `credGroupMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`credGroupID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblDays` (
  `dayID` int NOT NULL AUTO_INCREMENT,
  `dayName` varchar(50) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `dayActive` tinyint(1) NOT NULL DEFAULT '1',
  `dayMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`dayID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblDevice` (
  `deviceID` int NOT NULL AUTO_INCREMENT,
  `deviceName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `deviceSN` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `deviceMultiUser` tinyint(1) NOT NULL DEFAULT '0',
  `deviceActive` tinyint(1) NOT NULL DEFAULT '1',
  `deviceMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`deviceID`),
  UNIQUE KEY `uk_tblDevice_deviceSN` (`deviceSN`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblDeviceDeviceType` (
  `deviceDeviceTypeID` int NOT NULL AUTO_INCREMENT,
  `deviceID` int NOT NULL,
  `deviceTypeID` int NOT NULL,
  `deviceDeviceTypeActive` tinyint(1) NOT NULL DEFAULT '1',
  `deviceDeviceTypeMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`deviceDeviceTypeID`),
  UNIQUE KEY `uk_tblDeviceDeviceType_deviceID_deviceTypeID` (`deviceID`,`deviceTypeID`),
  KEY `fk_tblDeviceDeviceType_deviceTypeID` (`deviceTypeID`),
  CONSTRAINT `fk_tblDeviceDeviceType_deviceID` FOREIGN KEY (`deviceID`) REFERENCES `tblDevice` (`deviceID`),
  CONSTRAINT `fk_tblDeviceDeviceType_deviceTypeID` FOREIGN KEY (`deviceTypeID`) REFERENCES `tblDeviceType` (`deviceTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblDeviceType` (
  `deviceTypeID` int NOT NULL AUTO_INCREMENT,
  `deviceTypeName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `deviceTypeOS` varchar(50) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `deviceTypeActive` tinyint(1) NOT NULL DEFAULT '1',
  `deviceTypeMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`deviceTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblEventLog` (
  `eventLogID` int NOT NULL AUTO_INCREMENT,
  `eventLogTimestamp` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `userIDInit` int DEFAULT NULL,
  `userIDTarget` int DEFAULT NULL,
  `roundingRuleID` int DEFAULT NULL,
  `scheduleRoundingRuleID` int DEFAULT NULL,
  `appModulesCredGroupID` int DEFAULT NULL,
  `appModulesID` int DEFAULT NULL,
  `credGroupID` int DEFAULT NULL,
  `userCredGroupID` int DEFAULT NULL,
  `functionID` int DEFAULT NULL,
  `userfunctionID` int DEFAULT NULL,
  `userScheduleID` int DEFAULT NULL,
  `scheduleID` int DEFAULT NULL,
  `scheduleTypeID` int DEFAULT NULL,
  `dayID` int DEFAULT NULL,
  `geofenceID` int DEFAULT NULL,
  `geofenceAddressID` int DEFAULT NULL,
  `groupID` int DEFAULT NULL,
  `userGroupID` int DEFAULT NULL,
  `companyID` int DEFAULT NULL,
  `userCompanyID` int DEFAULT NULL,
  `timeRegID` int DEFAULT NULL,
  `addressID` int DEFAULT NULL,
  `timeRegTypeID` int DEFAULT NULL,
  `locationTypeID` int DEFAULT NULL,
  `addressLocationTypeID` int DEFAULT NULL,
  `userConfigurationID` int DEFAULT NULL,
  `configurationID` int DEFAULT NULL,
  `configTypeID` int DEFAULT NULL,
  `visitorID` int DEFAULT NULL,
  `deviceTypeID` int DEFAULT NULL,
  `deviceID` int DEFAULT NULL,
  `userVisitorID` int DEFAULT NULL,
  `userDeviceID` int DEFAULT NULL,
  `deviceDeviceTypeID` int DEFAULT NULL,
  PRIMARY KEY (`eventLogID`),
  KEY `ix_tblEventLog_timestamp` (`eventLogTimestamp`),
  KEY `fk_tblEventLog_userIDInit` (`userIDInit`),
  KEY `fk_tblEventLog_userIDTarget` (`userIDTarget`),
  KEY `fk_tblEventLog_roundingRuleID` (`roundingRuleID`),
  KEY `fk_tblEventLog_scheduleRoundingRuleID` (`scheduleRoundingRuleID`),
  KEY `fk_tblEventLog_appModulesCredGroupID` (`appModulesCredGroupID`),
  KEY `fk_tblEventLog_appModulesID` (`appModulesID`),
  KEY `fk_tblEventLog_credGroupID` (`credGroupID`),
  KEY `fk_tblEventLog_userCredGroupID` (`userCredGroupID`),
  KEY `fk_tblEventLog_functionID` (`functionID`),
  KEY `fk_tblEventLog_userfunctionID` (`userfunctionID`),
  KEY `fk_tblEventLog_userScheduleID` (`userScheduleID`),
  KEY `fk_tblEventLog_scheduleID` (`scheduleID`),
  KEY `fk_tblEventLog_scheduleTypeID` (`scheduleTypeID`),
  KEY `fk_tblEventLog_dayID` (`dayID`),
  KEY `fk_tblEventLog_geofenceID` (`geofenceID`),
  KEY `fk_tblEventLog_geofenceAddressID` (`geofenceAddressID`),
  KEY `fk_tblEventLog_groupID` (`groupID`),
  KEY `fk_tblEventLog_userGroupID` (`userGroupID`),
  KEY `fk_tblEventLog_companyID` (`companyID`),
  KEY `fk_tblEventLog_userCompanyID` (`userCompanyID`),
  KEY `fk_tblEventLog_timeRegID` (`timeRegID`),
  KEY `fk_tblEventLog_addressID` (`addressID`),
  KEY `fk_tblEventLog_timeRegTypeID` (`timeRegTypeID`),
  KEY `fk_tblEventLog_locationTypeID` (`locationTypeID`),
  KEY `fk_tblEventLog_addressLocationTypeID` (`addressLocationTypeID`),
  KEY `fk_tblEventLog_userConfigurationID` (`userConfigurationID`),
  KEY `fk_tblEventLog_configurationID` (`configurationID`),
  KEY `fk_tblEventLog_configTypeID` (`configTypeID`),
  KEY `fk_tblEventLog_visitorID` (`visitorID`),
  KEY `fk_tblEventLog_deviceTypeID` (`deviceTypeID`),
  KEY `fk_tblEventLog_deviceID` (`deviceID`),
  KEY `fk_tblEventLog_userVisitorID` (`userVisitorID`),
  KEY `fk_tblEventLog_userDeviceID` (`userDeviceID`),
  KEY `fk_tblEventLog_deviceDeviceTypeID` (`deviceDeviceTypeID`),
  CONSTRAINT `fk_tblEventLog_addressID` FOREIGN KEY (`addressID`) REFERENCES `tblAddress` (`addressID`),
  CONSTRAINT `fk_tblEventLog_addressLocationTypeID` FOREIGN KEY (`addressLocationTypeID`) REFERENCES `tblAddressLocationType` (`addressLocationTypeID`),
  CONSTRAINT `fk_tblEventLog_appModulesCredGroupID` FOREIGN KEY (`appModulesCredGroupID`) REFERENCES `tblAppModulesCredGroup` (`appModulesCredGroupID`),
  CONSTRAINT `fk_tblEventLog_appModulesID` FOREIGN KEY (`appModulesID`) REFERENCES `tblAppModules` (`appModulesID`),
  CONSTRAINT `fk_tblEventLog_companyID` FOREIGN KEY (`companyID`) REFERENCES `tblCompany` (`companyID`),
  CONSTRAINT `fk_tblEventLog_configTypeID` FOREIGN KEY (`configTypeID`) REFERENCES `tblConfigType` (`configTypeID`),
  CONSTRAINT `fk_tblEventLog_configurationID` FOREIGN KEY (`configurationID`) REFERENCES `tblConfiguration` (`configurationID`),
  CONSTRAINT `fk_tblEventLog_credGroupID` FOREIGN KEY (`credGroupID`) REFERENCES `tblCredGroup` (`credGroupID`),
  CONSTRAINT `fk_tblEventLog_dayID` FOREIGN KEY (`dayID`) REFERENCES `tblDays` (`dayID`),
  CONSTRAINT `fk_tblEventLog_deviceDeviceTypeID` FOREIGN KEY (`deviceDeviceTypeID`) REFERENCES `tblDeviceDeviceType` (`deviceDeviceTypeID`),
  CONSTRAINT `fk_tblEventLog_deviceID` FOREIGN KEY (`deviceID`) REFERENCES `tblDevice` (`deviceID`),
  CONSTRAINT `fk_tblEventLog_deviceTypeID` FOREIGN KEY (`deviceTypeID`) REFERENCES `tblDeviceType` (`deviceTypeID`),
  CONSTRAINT `fk_tblEventLog_functionID` FOREIGN KEY (`functionID`) REFERENCES `tblFunction` (`functionID`),
  CONSTRAINT `fk_tblEventLog_geofenceAddressID` FOREIGN KEY (`geofenceAddressID`) REFERENCES `tblGeofenceAddress` (`geofenceAddressID`),
  CONSTRAINT `fk_tblEventLog_geofenceID` FOREIGN KEY (`geofenceID`) REFERENCES `tblGeofence` (`geofenceID`),
  CONSTRAINT `fk_tblEventLog_groupID` FOREIGN KEY (`groupID`) REFERENCES `tblGroup` (`groupID`),
  CONSTRAINT `fk_tblEventLog_locationTypeID` FOREIGN KEY (`locationTypeID`) REFERENCES `tblLocationType` (`locationTypeID`),
  CONSTRAINT `fk_tblEventLog_roundingRuleID` FOREIGN KEY (`roundingRuleID`) REFERENCES `tblRoundingRule` (`roundingRuleID`),
  CONSTRAINT `fk_tblEventLog_scheduleID` FOREIGN KEY (`scheduleID`) REFERENCES `tblSchedule` (`scheduleID`),
  CONSTRAINT `fk_tblEventLog_scheduleRoundingRuleID` FOREIGN KEY (`scheduleRoundingRuleID`) REFERENCES `tblScheduleRoundingRule` (`scheduleRoundingRuleID`),
  CONSTRAINT `fk_tblEventLog_scheduleTypeID` FOREIGN KEY (`scheduleTypeID`) REFERENCES `tblScheduleType` (`scheduleTypeID`),
  CONSTRAINT `fk_tblEventLog_timeRegID` FOREIGN KEY (`timeRegID`) REFERENCES `tblTimeReg` (`timeRegID`),
  CONSTRAINT `fk_tblEventLog_timeRegTypeID` FOREIGN KEY (`timeRegTypeID`) REFERENCES `tblTimeRegType` (`timeRegTypeID`),
  CONSTRAINT `fk_tblEventLog_userCompanyID` FOREIGN KEY (`userCompanyID`) REFERENCES `tblUserCompany` (`userCompanyID`),
  CONSTRAINT `fk_tblEventLog_userConfigurationID` FOREIGN KEY (`userConfigurationID`) REFERENCES `tblUserConfiguration` (`userConfigurationID`),
  CONSTRAINT `fk_tblEventLog_userCredGroupID` FOREIGN KEY (`userCredGroupID`) REFERENCES `tblUserCredGroup` (`userCredGroupID`),
  CONSTRAINT `fk_tblEventLog_userDeviceID` FOREIGN KEY (`userDeviceID`) REFERENCES `tblUserDevice` (`userDeviceID`),
  CONSTRAINT `fk_tblEventLog_userfunctionID` FOREIGN KEY (`userfunctionID`) REFERENCES `tblUserFunction` (`userFunctionID`),
  CONSTRAINT `fk_tblEventLog_userGroupID` FOREIGN KEY (`userGroupID`) REFERENCES `tblUserGroup` (`userGroupID`),
  CONSTRAINT `fk_tblEventLog_userIDInit` FOREIGN KEY (`userIDInit`) REFERENCES `tblUser` (`userID`),
  CONSTRAINT `fk_tblEventLog_userIDTarget` FOREIGN KEY (`userIDTarget`) REFERENCES `tblUser` (`userID`),
  CONSTRAINT `fk_tblEventLog_userScheduleID` FOREIGN KEY (`userScheduleID`) REFERENCES `tblUserSchedule` (`userScheduleID`),
  CONSTRAINT `fk_tblEventLog_userVisitorID` FOREIGN KEY (`userVisitorID`) REFERENCES `tblUserVisitor` (`userVisitorID`),
  CONSTRAINT `fk_tblEventLog_visitorID` FOREIGN KEY (`visitorID`) REFERENCES `tblVisitor` (`visitorID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblEventLogEventType` (
  `eventLogEventTypeID` int NOT NULL AUTO_INCREMENT,
  `eventTypeID` int NOT NULL,
  `eventLogID` int NOT NULL,
  `eventLogEventTypeActive` tinyint(1) NOT NULL DEFAULT '1',
  `eventLogEventTypeMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`eventLogEventTypeID`),
  UNIQUE KEY `uk_tblEventLogEventType_eventLogID_eventTypeID` (`eventLogID`,`eventTypeID`),
  KEY `fk_tblEventLogEventType_eventTypeID` (`eventTypeID`),
  CONSTRAINT `fk_tblEventLogEventType_eventLogID` FOREIGN KEY (`eventLogID`) REFERENCES `tblEventLog` (`eventLogID`),
  CONSTRAINT `fk_tblEventLogEventType_eventTypeID` FOREIGN KEY (`eventTypeID`) REFERENCES `tblEventType` (`eventTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblEventType` (
  `eventTypeID` int NOT NULL AUTO_INCREMENT,
  `eventTypeName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  PRIMARY KEY (`eventTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblFunction` (
  `functionID` int NOT NULL AUTO_INCREMENT,
  `functionName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `functionActive` tinyint(1) NOT NULL DEFAULT '1',
  `functionMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`functionID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblGeofence` (
  `geofenceID` int NOT NULL AUTO_INCREMENT,
  `geofenceRadiusInMeter` double NOT NULL,
  `geofenceCorrectionInMin` int NOT NULL DEFAULT '0',
  `geofenceActive` tinyint(1) NOT NULL DEFAULT '1',
  `geofenceMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`geofenceID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblGeofenceAddress` (
  `geofenceAddressID` int NOT NULL AUTO_INCREMENT,
  `geofenceID` int NOT NULL,
  `addressID` int NOT NULL,
  `geofenceAddressActive` tinyint(1) NOT NULL DEFAULT '1',
  `geofenceAddressMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`geofenceAddressID`),
  UNIQUE KEY `uk_tblGeofenceAddress_geofenceID_addressID` (`geofenceID`,`addressID`),
  KEY `fk_tblGeofenceAddress_addressID` (`addressID`),
  CONSTRAINT `fk_tblGeofenceAddress_addressID` FOREIGN KEY (`addressID`) REFERENCES `tblAddress` (`addressID`),
  CONSTRAINT `fk_tblGeofenceAddress_geofenceID` FOREIGN KEY (`geofenceID`) REFERENCES `tblGeofence` (`geofenceID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblGroup` (
  `groupID` int NOT NULL AUTO_INCREMENT,
  `groupName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `groupActive` tinyint(1) NOT NULL DEFAULT '1',
  `groupMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`groupID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblLanguage` (
  `languageID` int NOT NULL AUTO_INCREMENT,
  `languageName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `languageCode` varchar(10) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `languageActive` tinyint(1) NOT NULL DEFAULT '1',
  `languageMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`languageID`),
  UNIQUE KEY `uk_tblLanguage_languageCode` (`languageCode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblLocationType` (
  `locationTypeID` int NOT NULL AUTO_INCREMENT,
  `locationTypeName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `locationTypeActive` tinyint(1) NOT NULL DEFAULT '1',
  `locationTypeMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`locationTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblRoundingRule` (
  `roundingRuleID` int NOT NULL AUTO_INCREMENT,
  `roundingRuleValueInMin` int NOT NULL,
  `roundingRuleRoundUp` tinyint(1) NOT NULL DEFAULT '0',
  `roundingRuleActive` tinyint(1) NOT NULL DEFAULT '1',
  `roundingRuleMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`roundingRuleID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblSchedule` (
  `scheduleID` int NOT NULL AUTO_INCREMENT,
  `scheduleTypeID` int NOT NULL,
  `dayID` int NOT NULL,
  `scheduleHrStart` int NOT NULL,
  `scheduleMinStart` int NOT NULL,
  `scheduleHrStop` int NOT NULL,
  `scheduleMinStop` int NOT NULL,
  `scheduleMarginMin` int NOT NULL DEFAULT '0',
  `scheduleActive` tinyint(1) NOT NULL DEFAULT '1',
  `scheduleMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`scheduleID`),
  KEY `fk_tblSchedule_scheduleTypeID` (`scheduleTypeID`),
  KEY `fk_tblSchedule_dayID` (`dayID`),
  CONSTRAINT `fk_tblSchedule_dayID` FOREIGN KEY (`dayID`) REFERENCES `tblDays` (`dayID`),
  CONSTRAINT `fk_tblSchedule_scheduleTypeID` FOREIGN KEY (`scheduleTypeID`) REFERENCES `tblScheduleType` (`scheduleTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblScheduleRoundingRule` (
  `scheduleRoundingRuleID` int NOT NULL AUTO_INCREMENT,
  `scheduleID` int NOT NULL,
  `roundingRuleID` int NOT NULL,
  `scheduleRoundingRuleActive` tinyint(1) NOT NULL DEFAULT '1',
  `scheduleRoundingRuleMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`scheduleRoundingRuleID`),
  UNIQUE KEY `uk_tblScheduleRoundingRule_scheduleID_roundingRuleID` (`scheduleID`,`roundingRuleID`),
  KEY `fk_tblScheduleRoundingRule_roundingRuleID` (`roundingRuleID`),
  CONSTRAINT `fk_tblScheduleRoundingRule_roundingRuleID` FOREIGN KEY (`roundingRuleID`) REFERENCES `tblRoundingRule` (`roundingRuleID`),
  CONSTRAINT `fk_tblScheduleRoundingRule_scheduleID` FOREIGN KEY (`scheduleID`) REFERENCES `tblSchedule` (`scheduleID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblScheduleType` (
  `scheduleTypeID` int NOT NULL AUTO_INCREMENT,
  `scheduleTypeName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `scheduleTypeActive` tinyint(1) NOT NULL DEFAULT '1',
  `scheduleTypeMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`scheduleTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblTimeReg` (
  `timeRegID` int NOT NULL AUTO_INCREMENT,
  `userID` int NOT NULL,
  `addressID` int DEFAULT NULL,
  `timeRegTypeID` int NOT NULL,
  `timeRegTimestamp` datetime NOT NULL,
  `timeRegManualEntry` tinyint(1) NOT NULL DEFAULT '0',
  `timeRegComment` varchar(500) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `timeRegWhenModified` datetime DEFAULT NULL,
  `timeRegActive` tinyint(1) NOT NULL DEFAULT '1',
  `timeRegMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`timeRegID`),
  KEY `ix_tblTimeReg_user_timestamp` (`userID`,`timeRegTimestamp`),
  KEY `fk_tblTimeReg_addressID` (`addressID`),
  KEY `fk_tblTimeReg_timeRegTypeID` (`timeRegTypeID`),
  CONSTRAINT `fk_tblTimeReg_addressID` FOREIGN KEY (`addressID`) REFERENCES `tblAddress` (`addressID`),
  CONSTRAINT `fk_tblTimeReg_timeRegTypeID` FOREIGN KEY (`timeRegTypeID`) REFERENCES `tblTimeRegType` (`timeRegTypeID`),
  CONSTRAINT `fk_tblTimeReg_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblTimeRegType` (
  `timeRegTypeID` int NOT NULL AUTO_INCREMENT,
  `timeRegTypeName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `timeRegTypeActive` tinyint(1) NOT NULL DEFAULT '1',
  `timeRegTypeMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`timeRegTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblTranslation` (
  `translationID` int NOT NULL AUTO_INCREMENT,
  `languageID` int NOT NULL,
  `translationUIName` varchar(150) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `translationUIText` text COLLATE utf8mb4_0900_as_cs NOT NULL,
  PRIMARY KEY (`translationID`),
  UNIQUE KEY `uk_tblTranslation_languageID_UIName` (`languageID`,`translationUIName`),
  CONSTRAINT `fk_tblTranslation_languageID` FOREIGN KEY (`languageID`) REFERENCES `tblLanguage` (`languageID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUser` (
  `userID` int NOT NULL AUTO_INCREMENT,
  `userName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `userSurname` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `userEmail` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `userCellphoneNumber` varchar(30) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `userCode` varchar(50) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `userQRcode` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `userPassword` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `userKioskMode` tinyint(1) NOT NULL DEFAULT '0',
  `userPINCode` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `userActive` tinyint(1) NOT NULL DEFAULT '1',
  `userMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userID`),
  UNIQUE KEY `uk_tblUser_userCode` (`userCode`),
  UNIQUE KEY `uk_tblUser_userQRcode` (`userQRcode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUserCompany` (
  `userCompanyID` int NOT NULL AUTO_INCREMENT,
  `userID` int NOT NULL,
  `companyID` int NOT NULL,
  `userCompanyActive` tinyint(1) NOT NULL DEFAULT '1',
  `userCompanyMFD` tinyint(1) NOT NULL DEFAULT '0',
  `userCompanyDefault` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userCompanyID`),
  UNIQUE KEY `uk_tblUserCompany_userID_companyID` (`userID`,`companyID`),
  UNIQUE KEY `uk_tblUserCompany_oneDefault` ((if(((`userCompanyDefault` = 1) and (`userCompanyMFD` = 0)),`userID`,NULL))),
  KEY `fk_tblUserCompany_companyID` (`companyID`),
  CONSTRAINT `fk_tblUserCompany_companyID` FOREIGN KEY (`companyID`) REFERENCES `tblCompany` (`companyID`),
  CONSTRAINT `fk_tblUserCompany_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUserConfiguration` (
  `userConfigurationID` int NOT NULL AUTO_INCREMENT,
  `userID` int NOT NULL,
  `configurationID` int NOT NULL,
  `userConfigurationValue` text COLLATE utf8mb4_0900_as_cs,
  `userConfigurationActive` tinyint(1) NOT NULL DEFAULT '1',
  `userConfigurationMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userConfigurationID`),
  UNIQUE KEY `uk_tblUserConfiguration_userID_configurationID` (`userID`,`configurationID`),
  KEY `fk_tblUserConfiguration_configurationID` (`configurationID`),
  CONSTRAINT `fk_tblUserConfiguration_configurationID` FOREIGN KEY (`configurationID`) REFERENCES `tblConfiguration` (`configurationID`),
  CONSTRAINT `fk_tblUserConfiguration_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUserCredGroup` (
  `userCredGroupID` int NOT NULL AUTO_INCREMENT,
  `userID` int NOT NULL,
  `credGroupID` int NOT NULL,
  `userCredGroupActive` tinyint(1) NOT NULL DEFAULT '1',
  `userCredGroupMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userCredGroupID`),
  UNIQUE KEY `uk_tblUserCredGroup_userID_credGroupID` (`userID`,`credGroupID`),
  KEY `fk_tblUserCredGroup_credGroupID` (`credGroupID`),
  CONSTRAINT `fk_tblUserCredGroup_credGroupID` FOREIGN KEY (`credGroupID`) REFERENCES `tblCredGroup` (`credGroupID`),
  CONSTRAINT `fk_tblUserCredGroup_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUserDevice` (
  `userDeviceID` int NOT NULL AUTO_INCREMENT,
  `deviceID` int NOT NULL,
  `userID` int NOT NULL,
  `userDeviceActive` tinyint(1) NOT NULL DEFAULT '1',
  `userDeviceMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userDeviceID`),
  UNIQUE KEY `uk_tblUserDevice_deviceID_userID` (`deviceID`,`userID`),
  KEY `fk_tblUserDevice_userID` (`userID`),
  CONSTRAINT `fk_tblUserDevice_deviceID` FOREIGN KEY (`deviceID`) REFERENCES `tblDevice` (`deviceID`),
  CONSTRAINT `fk_tblUserDevice_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUserFunction` (
  `userFunctionID` int NOT NULL AUTO_INCREMENT,
  `userID` int NOT NULL,
  `functionID` int NOT NULL,
  `userFunctionActive` tinyint(1) NOT NULL DEFAULT '1',
  `userFunctionMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userFunctionID`),
  UNIQUE KEY `uk_tblUserFunction_userID_functionID` (`userID`,`functionID`),
  KEY `fk_tblUserFunction_functionID` (`functionID`),
  CONSTRAINT `fk_tblUserFunction_functionID` FOREIGN KEY (`functionID`) REFERENCES `tblFunction` (`functionID`),
  CONSTRAINT `fk_tblUserFunction_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUserGroup` (
  `userGroupID` int NOT NULL AUTO_INCREMENT,
  `userID` int NOT NULL,
  `groupID` int NOT NULL,
  `userGroupActive` tinyint(1) NOT NULL DEFAULT '1',
  `userGroupMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userGroupID`),
  UNIQUE KEY `uk_tblUserGroup_userID_groupID` (`userID`,`groupID`),
  KEY `fk_tblUserGroup_groupID` (`groupID`),
  CONSTRAINT `fk_tblUserGroup_groupID` FOREIGN KEY (`groupID`) REFERENCES `tblGroup` (`groupID`),
  CONSTRAINT `fk_tblUserGroup_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUserLanguage` (
  `userLanguageID` int NOT NULL AUTO_INCREMENT,
  `userID` int NOT NULL,
  `languageID` int NOT NULL,
  `userLanguageActive` tinyint(1) NOT NULL DEFAULT '1',
  `userLanguageMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userLanguageID`),
  UNIQUE KEY `uk_tblUserLanguage_userID_languageID` (`userID`,`languageID`),
  KEY `fk_tblUserLanguage_languageID` (`languageID`),
  CONSTRAINT `fk_tblUserLanguage_languageID` FOREIGN KEY (`languageID`) REFERENCES `tblLanguage` (`languageID`),
  CONSTRAINT `fk_tblUserLanguage_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUserSchedule` (
  `userScheduleID` int NOT NULL AUTO_INCREMENT,
  `userID` int NOT NULL,
  `scheduleID` int NOT NULL,
  `userScheduleActive` tinyint(1) NOT NULL DEFAULT '1',
  `userScheduleMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userScheduleID`),
  UNIQUE KEY `uk_tblUserSchedule_userID_scheduleID` (`userID`,`scheduleID`),
  KEY `fk_tblUserSchedule_scheduleID` (`scheduleID`),
  CONSTRAINT `fk_tblUserSchedule_scheduleID` FOREIGN KEY (`scheduleID`) REFERENCES `tblSchedule` (`scheduleID`),
  CONSTRAINT `fk_tblUserSchedule_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblUserVisitor` (
  `userVisitorID` int NOT NULL AUTO_INCREMENT,
  `userID` int NOT NULL,
  `visitorID` int NOT NULL,
  `userVisitorActive` tinyint(1) NOT NULL DEFAULT '1',
  `userVisitorMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userVisitorID`),
  UNIQUE KEY `uk_tblUserVisitor_userID_visitorID` (`userID`,`visitorID`),
  KEY `fk_tblUserVisitor_visitorID` (`visitorID`),
  CONSTRAINT `fk_tblUserVisitor_userID` FOREIGN KEY (`userID`) REFERENCES `tblUser` (`userID`),
  CONSTRAINT `fk_tblUserVisitor_visitorID` FOREIGN KEY (`visitorID`) REFERENCES `tblVisitor` (`visitorID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

CREATE TABLE `tblVisitor` (
  `visitorID` int NOT NULL AUTO_INCREMENT,
  `visitorName` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `visitorSurname` varchar(100) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `visitorCompany` varchar(150) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `visitorCellphoneNumber` varchar(30) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `visitorLicenseplate` varchar(20) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `visitorPicture` mediumblob,
  `visitorCheckInTimestamp` datetime DEFAULT NULL,
  `visitorCheckOutTimestamp` datetime DEFAULT NULL,
  `visitorActive` tinyint(1) NOT NULL DEFAULT '1',
  `visitorMFD` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`visitorID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs;

SET FOREIGN_KEY_CHECKS = 1;
