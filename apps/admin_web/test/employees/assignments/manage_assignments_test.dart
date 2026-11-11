import 'package:admin_web/src/employees/assignments/manage_assignments_controller.dart';
import 'package:admin_web/src/employees/assignments/manage_assignments_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../support/fake_assignments_api.dart';

const _disan = EmployeeDetails(
  id: 2,
  companyId: 1,
  companyName: 'Almeco',
  firstName: 'Disan',
  lastName: 'Ssebowa',
  code: 'SBW',
  groups: ['White collar'],
  phone: null,
  isActive: true,
  isActivated: false,
);

const _almeco = AssignmentOption(id: 1, name: 'Almeco', isActive: true, isAssigned: true);
const _pca = AssignmentOption(id: 2, name: 'PCA', isActive: true, isAssigned: false);
const _akwa = AssignmentOption(id: 3, name: 'Akwa', isActive: false, isAssigned: true);

const _blue = AssignmentOption(id: 2, name: 'Blue collar', isActive: true, isAssigned: false);
const _white = AssignmentOption(id: 1, name: 'White collar', isActive: true, isAssigned: true);

FakeEmployeeAssignmentsApi _api() => FakeEmployeeAssignmentsApi()
  ..byKind = {
    AssignmentKind.companies: [_akwa, _almeco, _pca],
    AssignmentKind.groups: [_blue, _white],
    AssignmentKind.language: [_english, _dutch],
    AssignmentKind.credentialGroups: [_employeeRole, _hrRole],
  };

const _english = AssignmentOption(id: 1, name: 'English', code: 'en', isActive: true, isAssigned: true);
const _dutch = AssignmentOption(id: 2, name: 'Nederlands', code: 'nl', isActive: true, isAssigned: false);

const _employeeRole = AssignmentOption(id: 1, name: 'Employee', isActive: true, isAssigned: true);
const _hrRole = AssignmentOption(id: 2, name: 'HR', isActive: true, isAssigned: false);

void main() {
  group('ManageAssignmentsController', () {
    test('existing assignments are locked; only what the server allows can be ticked', () async {
      final c = ManageAssignmentsController(api: _api(), companyId: 1, userId: 2);
      await pumpEventQueue();
      final companies = c.tabs.first;
      final groups = c.tabs[1];

      c.toggle(companies, _almeco);
      c.toggle(companies, _akwa);
      expect(c.hasChanges, isFalse, reason: 'existing memberships are not unticked: removal is a confirmed action');
      c.toggle(companies, _pca);
      expect(companies.pending, {2}, reason: 'several companies allowed');
      c.toggle(companies, _pca);

      c.toggle(groups, _white);
      expect(c.hasChanges, isFalse);
      c.toggle(groups, _blue);
      expect(groups.pending, {2});
      c.toggle(groups, _blue);
      expect(c.hasChanges, isFalse);
    });

    test('save adds only what was ticked, then reflects the server', () async {
      final api = _api();
      final c = ManageAssignmentsController(api: api, companyId: 1, userId: 2);
      await pumpEventQueue();
      c.toggle(c.tabs[1], _blue);

      expect(await c.save(), isTrue);

      final (companyId, userId, kind, ids) = api.adds.single;
      expect((companyId, userId, kind), (1, 2, AssignmentKind.groups));
      expect(ids, [2]);
      expect(c.tabs[1].options!.firstWhere((o) => o.id == 2).isAssigned, isTrue);
      expect(c.hasChanges, isFalse);
    });

    test('a failed save keeps the ticks so it can be retried', () async {
      final api = _api()..addFailure = const ApiClientException.network('offline');
      final c = ManageAssignmentsController(api: api, companyId: 1, userId: 2);
      await pumpEventQueue();
      c.toggle(c.tabs[1], _blue);

      expect(await c.save(), isFalse);

      expect(c.saveFailure, isNotNull);
      expect(c.tabs[1].pending, {2});
    });
  });


  test('choose keeps one pending option and ignores assigned ones', () async {
    final c = ManageAssignmentsController(api: _api(), companyId: 1, userId: 2);
    await pumpEventQueue();
    final access = c.tabs.last;

    c.choose(access, 1);
    expect(access.pending, isEmpty, reason: 'already assigned');
    c.choose(access, 2);
    expect(access.pending, {2});
    c.choose(access, null);
    expect(c.hasChanges, isFalse);
  });

  test('language: picking the current one again undoes the change', () async {
    final c = ManageAssignmentsController(api: _api(), companyId: 1, userId: 2);
    await pumpEventQueue();
    final language = c.tabs.firstWhere((t) => t.kind == AssignmentKind.language);

    c.toggle(language, _dutch);
    expect(language.pending, {2});
    c.toggle(language, _english);
    expect(c.hasChanges, isFalse);
  });

  test('the server decides what can be ticked (isAssignable)', () async {
    final api = _api()
      ..byKind[AssignmentKind.groups] = [
        const AssignmentOption(id: 2, name: 'Blue collar', isActive: true, isAssigned: false, isAssignable: false),
      ];
    final c = ManageAssignmentsController(api: api, companyId: 1, userId: 2);
    await pumpEventQueue();
    final groups = c.tabs.firstWhere((t) => t.kind == AssignmentKind.groups);

    c.toggle(groups, groups.options!.single);
    expect(c.hasChanges, isFalse);
  });

  /// The pop-up, opened on [tab] (Figma 1537:*).
  Future<FakeEmployeeAssignmentsApi> open(WidgetTester tester, {String tab = 'Companies', FakeEmployeeAssignmentsApi? api}) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = api ?? _api();
    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: MaterialApp(
          theme: JitanTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showManageAssignmentsDialog(context, api: fake, employee: _disan),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (tab != 'Companies') {
      // The test font is wide: the tabs may scroll.
      await tester.ensureVisible(find.text(tab));
      await tester.pump();
      await tester.tap(find.text(tab));
      await tester.pump();
    }
    return fake;
  }

  bool ticked(WidgetTester tester, String name) => find
      .descendant(of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first, matching: find.byIcon(Icons.check))
      .evaluate()
      .isNotEmpty;

  group('Companies, groups and access (Figma 1537:2)', () {
    testWidgets('the name, tabs like the rest of the app, one line and a plain list with a check', (tester) async {
      await open(tester);

      expect(find.text('Disan Ssebowa'), findsOneWidget);
      expect(find.text('Companies, groups and access'), findsOneWidget);
      expect(find.byType(JitanPillSwitch<int>), findsOneWidget);
      expect(find.text('Disan can work for several companies.'), findsOneWidget);
      expect(ticked(tester, 'Almeco'), isTrue);
      expect(ticked(tester, 'PCA'), isFalse);
      expect(find.text('Inactive'), findsOneWidget, reason: 'an existing membership stays listed, marked');
      for (final gone in ['Manage employee assignments', 'Current company', 'Additional company', 'Changes take effect after saving.']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
    });

    testWidgets('Save waits for a change; ticking PCA and saving adds a second company', (tester) async {
      final api = await open(tester);
      FilledButton save() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
      expect(save().onPressed, isNull);

      await tester.tap(find.text('Almeco'));
      await tester.pump();
      expect(save().onPressed, isNull, reason: 'the current company is locked');

      await tester.tap(find.text('PCA'));
      await tester.pump();
      expect(ticked(tester, 'PCA'), isTrue);
      await tester.tap(find.text('Save'));
      await tester.pump();

      final (companyId, userId, kind, ids) = api.adds.single;
      expect((companyId, userId, kind), (1, 2, AssignmentKind.companies));
      expect(ids, [2]);
    });

    testWidgets('every tab keeps the same height', (tester) async {
      await open(tester);
      final companies = tester.getSize(find.byType(ListView)).height;
      for (final tab in ['Groups', 'Language', 'Access']) {
        await tester.ensureVisible(find.text(tab));
        await tester.pump();
        await tester.tap(find.text(tab));
        await tester.pump();
        expect(tester.getSize(find.byType(ListView)).height, companies, reason: tab);
      }
    });

    testWidgets('a load failure shows a retryable error', (tester) async {
      final api = _api()..loadFailure = const ApiClientException.network('offline');
      await open(tester, api: api);

      expect(find.text('Try again'), findsOneWidget);
      api.loadFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.text('Almeco'), findsOneWidget);
    });

    testWidgets('a failed save shows an inline error and keeps the pop-up open', (tester) async {
      final api = await open(tester, tab: 'Groups', api: _api()..addFailure = const ApiClientException.network('offline'));

      await tester.tap(find.text('Blue collar'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(api.adds, hasLength(1));
      expect(find.text('Companies, groups and access'), findsOneWidget);
      expect(find.byType(JitanInlineError), findsOneWidget);
    });
  });

  group('Groups (1537:194)', () {
    testWidgets('the hours come from the group: one line, and no company list', (tester) async {
      await open(tester, tab: 'Groups');

      expect(find.text('Disan’s hours come from the group.'), findsOneWidget);
      expect(ticked(tester, 'White collar'), isTrue);
      expect(find.text('Almeco'), findsNothing, reason: 'no company list on the Groups tab');
    });

    testWidgets('ticking Blue collar and saving adds that group only', (tester) async {
      final api = await open(tester, tab: 'Groups');

      await tester.tap(find.text('White collar'));
      await tester.tap(find.text('Blue collar'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();

      final (companyId, userId, kind, ids) = api.adds.single;
      expect((companyId, userId, kind), (1, 2, AssignmentKind.groups));
      expect(ids, [2]);
    });
  });

  group('Language (1537:372)', () {
    testWidgets('native names only, one checked; choosing Nederlands and saving replaces it', (tester) async {
      final api = await open(tester, tab: 'Language');

      expect(find.text('The language of Disan’s Jitan app.'), findsOneWidget);
      expect(find.text('Dutch'), findsNothing, reason: 'no repeated English name');
      expect(ticked(tester, 'English'), isTrue);

      await tester.tap(find.text('Nederlands'));
      await tester.pump();
      expect(ticked(tester, 'Nederlands'), isTrue);
      expect(ticked(tester, 'English'), isFalse, reason: 'one choice');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(api.languageChanges.single, (1, 2, 2));
      expect(api.adds, isEmpty);
    });
  });

  group('Access (1537:556)', () {
    testWidgets('the role names from the database, in plain words; picking HR and saving adds it', (tester) async {
      final api = await open(tester, tab: 'Access');

      expect(find.text('What Disan can open in Jitan.'), findsOneWidget);
      expect(ticked(tester, 'Employee'), isTrue);
      for (final gone in ['Access and credential groups', 'Select credential group', 'Current assignments']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('server enforces'), findsNothing);

      await tester.tap(find.text('HR'));
      await tester.pump();
      expect(ticked(tester, 'HR'), isTrue);
      await tester.tap(find.text('Save'));
      await tester.pump();

      final (companyId, userId, kind, ids) = api.adds.single;
      expect((companyId, userId, kind), (1, 2, AssignmentKind.credentialGroups));
      expect(ids, [2]);
    });
  });

  group('taking out of a company or group, asked first', () {
    const removableWhite = AssignmentOption(id: 1, name: 'White collar', isActive: true, isAssigned: true, isRemovable: true);
    const removablePca = AssignmentOption(id: 2, name: 'PCA', isActive: true, isAssigned: true, isRemovable: true);

    FakeEmployeeAssignmentsApi removable() => _api()
      ..byKind[AssignmentKind.groups] = [_blue, removableWhite]
      ..byKind[AssignmentKind.companies] = [_almeco, removablePca];

    testWidgets('a group: one plain question, then taken out', (tester) async {
      final api = await open(tester, tab: 'Groups', api: removable());

      await tester.tap(find.text('White collar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Take Disan out of White collar?'), findsOneWidget);
      expect(find.text('You can add White collar again any time.'), findsOneWidget);
      expect(find.textContaining('tblUserGroup'), findsNothing);
      expect(api.removes, isEmpty, reason: 'nothing happens before the confirmation');

      await tester.tap(find.text('Take out'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.removes.single, (1, 2, AssignmentKind.groups, 1));
      expect(find.text('Take Disan out of White collar?'), findsNothing);
    });

    testWidgets('Cancel takes nothing out', (tester) async {
      final api = await open(tester, tab: 'Groups', api: removable());

      await tester.tap(find.text('White collar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel').last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.removes, isEmpty);
    });

    testWidgets('a second company is taken out after the question; the current one is locked', (tester) async {
      final api = await open(tester, api: removable());

      await tester.tap(find.text('Almeco'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Take Disan out of Almeco?'), findsNothing, reason: 'the current company is locked');

      await tester.tap(find.text('PCA'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Disan no longer works for PCA in Jitan. Time records stay, and you can add PCA again any time.'), findsOneWidget);
      await tester.tap(find.text('Take out'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.removes.single, (1, 2, AssignmentKind.companies, 2));
    });

    testWidgets('a refusal is explained and the question stays open', (tester) async {
      final api = await open(tester, tab: 'Groups', api: removable());
      api.removeFailure = const ApiClientException.network('offline');

      await tester.tap(find.text('White collar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Take out'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Take Disan out of White collar?'), findsOneWidget);
      expect(find.byType(JitanInlineError), findsOneWidget);
    });
  });
}
