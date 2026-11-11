@Tags(['integration'])
library;

import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/companies/company_service.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Adding, renaming, deactivating and reactivating a company against MySQL,
/// each audited (Figma `1524:*`). `[DEV-TEST]` companies are removed after.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late CompanyService companies;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  final created = <int>[];
  const actor = 1;

  Future<List<String>> auditOf(int companyId) async => [
    for (final row in await db.query(
      'SELECT t.eventTypeName FROM tblEventLog e '
      'JOIN tblEventLogEventType l ON l.eventLogID = e.eventLogID JOIN tblEventType t ON t.eventTypeID = l.eventTypeID '
      'WHERE e.companyID = :c ORDER BY e.eventLogID',
      {'c': companyId},
    ))
      row.readString('eventTypeName'),
  ];

  Matcher refused(int status, [String? code]) => throwsA(
    isA<ApiException>()
        .having((e) => e.statusCode, 'status', status)
        .having((e) => code == null || e.code == code, 'code $code', true),
  );

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 2);
    companies = CompanyService(CompanyRepository(db), transactions: db);
  });

  tearDownAll(() async {
    for (final id in created) {
      await db.execute(
        'DELETE l FROM tblEventLogEventType l JOIN tblEventLog e ON e.eventLogID = l.eventLogID WHERE e.companyID = :c',
        {'c': id},
      );
      await db.execute('DELETE FROM tblEventLog WHERE companyID = :c', {'c': id});
      await db.execute('DELETE FROM tblCompany WHERE companyID = :c', {'c': id});
    }
    await db.close();
  });

  test('a new company is active, with no employees, and audited', () async {
    final company = await companies.create(actor, CompanyRequest(name: '  $prefix Proceq  '));
    created.add(company.id);

    expect((company.name, company.isActive, company.employeeCount), ('$prefix Proceq', true, 0));
    expect(await auditOf(company.id), ['company.created']);
    expect(company.lastUpdatedAt, isNotNull, reason: 'from the audit row');
  });

  test('a name in use is refused, ignoring capitals and accents', () async {
    final company = await companies.create(actor, CompanyRequest(name: '$prefix Société'));
    created.add(company.id);

    await expectLater(
      companies.create(actor, CompanyRequest(name: '$prefix SOCIETE')),
      refused(409, ApiErrorCode.duplicateCompanyName),
    );
  });

  test('an empty or too long name is refused on the name', () async {
    await expectLater(companies.create(actor, const CompanyRequest(name: '   ')), refused(400));
    await expectLater(
      companies.create(actor, CompanyRequest(name: 'x' * (CompanyRequest.maxNameLength + 1))),
      refused(400),
    );
  });

  test('rename: audited; the same name again changes nothing; another company’s name is refused', () async {
    final a = await companies.create(actor, CompanyRequest(name: '$prefix Alpha'));
    final b = await companies.create(actor, CompanyRequest(name: '$prefix Beta'));
    created.addAll([a.id, b.id]);

    final renamed = await companies.rename(actor, a.id, CompanyRequest(name: '$prefix Alpha Group'));
    expect(renamed.name, '$prefix Alpha Group');
    await companies.rename(actor, a.id, CompanyRequest(name: '$prefix Alpha Group'));
    expect(await auditOf(a.id), ['company.created', 'company.renamed']);

    await expectLater(companies.rename(actor, a.id, CompanyRequest(name: '$prefix beta')), refused(409));
    await expectLater(companies.rename(actor, 999999999, CompanyRequest(name: '$prefix X')), refused(404));
  });

  test('deactivate and reactivate: kept, shown as inactive, each audited once', () async {
    final company = await companies.create(actor, CompanyRequest(name: '$prefix Gamma'));
    created.add(company.id);

    expect((await companies.setActive(actor, company.id, active: false)).isActive, isFalse);
    await companies.setActive(actor, company.id, active: false);
    expect((await companies.listCompanies(search: '$prefix Gamma')).single.isActive, isFalse, reason: 'still listed');
    expect((await companies.setActive(actor, company.id, active: true)).isActive, isTrue);

    expect(await auditOf(company.id), ['company.created', 'company.deactivated', 'company.reactivated']);
  });
}
