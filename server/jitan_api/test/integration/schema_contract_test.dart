@Tags(['integration'])
library;

import 'package:jitan_api/src/database/database.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Every table/column the repositories reference, spelled exactly as used.
///
/// Fails when the live schema differs from the ERD documentation, which
/// would otherwise surface only as a runtime 500. Extend this list whenever a
/// repository starts using a new column.
const _usedColumns = {
  'tblCompany': ['companyID', 'companyName', 'companyActive', 'companyMFD'],
  'tblUserCompany': ['userCompanyID', 'userID', 'companyID', 'userCompanyActive', 'userCompanyMFD'],
  'tblUser': [
    'userID', 'userName', 'userSurname', 'userCode', 'userQRcode', 'cellphoneNumber',
    'userKioskMode', 'userPassword', 'userActive', 'userMFD',
  ],
  'tblUserGroup': ['userGroupID', 'userID', 'groupID', 'userGroupActive', 'userGroupMFD'],
  'tblGroup': ['groupID', 'groupName', 'groupActive', 'groupMFD'],
  'tblEventLog': [
    'eventLogID', 'eventLogTimestamp', 'userIDInit', 'userIDTarget', 'companyID', 'userCompanyID',
    'groupID', 'userGroupID', 'credGroupID', 'userCredGroupID', 'scheduleID', 'scheduleTypeID', 'dayID',
    'roundingRuleID', 'scheduleRoundingRuleID',
  ],
  'tblTimeReg': [
    'timeRegID', 'userID', 'addressID', 'timeRegTypeID', 'timeRegTimestamp', 'timeRegManualEntry',
    'timeRegComment', 'timeRegWhenModified', 'timeRegActive', 'timeRegMFD',
  ],
  'tblTimeRegType': ['timeRegTypeID', 'timeRegTypeName', 'timeRegTypeActive', 'timeRegTypeMFD'],
  'tblAddress': ['addressID', 'addressLogicalName'],
  'tblCredGroup': ['credGroupID', 'credGroupName', 'credGroupLevel', 'credGroupActive', 'credGroupMFD'],
  'tblUserCredGroup': ['userCredGroupID', 'userID', 'credGroupID', 'userCredGroupActive', 'userCredGroupMFD'],
  'tblEventType': ['eventTypeID', 'eventTypeName'],
  'tblEventLogEventType': [
    'eventLogEventTypeID', 'eventTypeID', 'eventLogID', 'eventLogEventTypeActive', 'eventLogEventTypeMFD',
  ],
  'tblLanguage': ['languageID', 'languageName', 'languageCode', 'languageActive', 'languageMFD'],
  'tblTranslation': ['translationID', 'languageID', 'translationUIName', 'translationUIText'],
  'tblUserLanguage': ['userLanguageID', 'userID', 'languageID', 'userLanguageActive', 'userLanguageMFD'],
  'tblDays': ['dayID', 'dayName', 'dayActive', 'dayMFD'],
  'tblScheduleType': ['scheduleTypeID', 'scheduleTypeName', 'scheduleTypeActive', 'scheduleTypeMFD'],
  'tblSchedule': [
    'scheduleID', 'scheduleTypeID', 'dayID', 'scheduleHrStart', 'scheduleMinStart', 'scheduleHrStop',
    'scheduleMinStop', 'scheduleMarginMin', 'scheduleActive', 'scheduleMFD',
  ],
  'tblUserSchedule': ['userScheduleID', 'userID', 'scheduleID', 'userScheduleActive', 'userScheduleMFD'],
  'tblRoundingRule': [
    'roundingRuleID', 'roundingRuleValueInMin', 'roundingRuleRoundUp', 'roundingRuleActive', 'roundingRuleMFD',
  ],
  'tblScheduleRoundingRule': [
    'scheduleRoundingRuleID', 'scheduleID', 'roundingRuleID', 'scheduleRoundingRuleActive', 'scheduleRoundingRuleMFD',
  ],
};

/// Every junction table and its soft-delete columns (IT decision 2026-10-08,
/// confirmed in IT's development database 2026-10-09): a link counts only
/// while `Active = 1 AND MFD = 0`, and a removed link keeps its row.
const _junctionSoftDelete = {
  'tblUserCompany': ('userCompanyActive', 'userCompanyMFD'),
  'tblUserGroup': ('userGroupActive', 'userGroupMFD'),
  'tblUserCredGroup': ('userCredGroupActive', 'userCredGroupMFD'),
  'tblUserFunction': ('userFunctionActive', 'userFunctionMFD'),
  'tblUserLanguage': ('userLanguageActive', 'userLanguageMFD'),
  'tblUserSchedule': ('userScheduleActive', 'userScheduleMFD'),
  'tblAppModulesCredGroup': ('appModulesCredGroupActive', 'appModulesCredGroupMFD'),
  'tblScheduleRoundingRule': ('scheduleRoundingRuleActive', 'scheduleRoundingRuleMFD'),
  'tblGeofenceAddress': ('geofenceAddressActive', 'geofenceAddressMFD'),
  'tblAddressLocationType': ('addressLocationTypeActive', 'addressLocationTypeMFD'),
  'tblEventLogEventType': ('eventLogEventTypeActive', 'eventLogEventTypeMFD'),
};

void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;

  setUpAll(() => db = TestDatabase.connect());
  tearDownAll(() => db.close());

  for (final MapEntry(key: table, value: columns) in _usedColumns.entries) {
    test('$table has ${columns.join(', ')}', () async {
      final rows = await db.query(
        'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS '
        'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table',
        {'table': table},
      );
      final actual = rows.map((r) => r.readString('COLUMN_NAME')).toSet();

      expect(actual, isNotEmpty, reason: 'Table $table does not exist.');
      for (final column in columns) {
        expect(actual, contains(column), reason: '$table.$column missing or spelled differently.');
      }
    });
  }

  for (final MapEntry(key: table, value: (active, mfd)) in _junctionSoftDelete.entries) {
    test('junction $table has $active and $mfd', () async {
      final rows = await db.query(
        'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS '
        'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table',
        {'table': table},
      );
      final actual = rows.map((r) => r.readString('COLUMN_NAME')).toSet();
      expect(actual, containsAll([active, mfd]), reason: '$table soft-delete columns missing or spelled differently.');
    });
  }
}
