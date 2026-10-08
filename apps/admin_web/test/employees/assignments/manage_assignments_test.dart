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

  group('Manage employee assignments modal (Companies tab)', () {
    Future<FakeEmployeeAssignmentsApi> open(WidgetTester tester, {FakeEmployeeAssignmentsApi? api}) async {
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
      return fake;
    }

    testWidgets('matches the Figma content: title, employee line, tabs, options and note', (tester) async {
      await open(tester);

      expect(find.text('Manage employee assignments'), findsOneWidget);
      expect(find.text('Disan Ssebowa  ·  Almeco  ·  Employee code SBW'), findsOneWidget);
      expect(find.text('Company membership'), findsOneWidget);
      expect(find.text('Choose the companies this employee belongs to. Multiple selections are allowed.'), findsOneWidget);
      expect(find.text('Current company'), findsOneWidget);
      expect(find.text('Additional company'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget, reason: 'an existing membership stays listed');
      expect(find.text('Company-scoped access'), findsOneWidget);
      expect(find.text('Changes take effect after saving.'), findsOneWidget);
    });

    testWidgets('Save is disabled until something is ticked; ticking PCA and saving adds a second company', (tester) async {
      final api = await open(tester);
      FilledButton save() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save changes'));
      expect(save().onPressed, isNull);

      await tester.tap(find.text('Almeco'));
      await tester.pump();
      expect(save().onPressed, isNull, reason: 'the current company is locked');

      await tester.tap(find.text('PCA'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pump();

      final (companyId, userId, kind, ids) = api.adds.single;
      expect((companyId, userId, kind), (1, 2, AssignmentKind.companies));
      expect(ids, [2]);
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

    testWidgets('a failed save shows an inline error and keeps the modal open', (tester) async {
      final api = await open(tester, api: _api()..addFailure = const ApiClientException.network('offline'));

      await tester.tap(find.text('Groups'));
      await tester.pump();
      await tester.tap(find.text('Blue collar'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pump();

      expect(api.adds, hasLength(1));
      expect(find.text('Manage employee assignments'), findsOneWidget);
      expect(find.byType(JitanInlineError), findsOneWidget);
    });
  });
  group('Groups tab (universal groups)', () {
    Future<FakeEmployeeAssignmentsApi> openGroups(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = _api();
      await tester.pumpWidget(
        TranslationScope(
          translations: Translations.english(),
          child: MaterialApp(
            theme: JitanTheme.light(),
            home: Scaffold(body: ManageAssignmentsDialog(api: fake, employee: _disan)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Groups'));
      await tester.pump();
      return fake;
    }

    testWidgets('matches Figma: no company selector, available groups to add', (tester) async {
      await openGroups(tester);

      expect(find.text('Employee groups / type'), findsOneWidget);
      expect(find.text('Groups are universal. Assigned groups apply across every company the employee belongs to.'), findsOneWidget);
      expect(find.text('Not assigned · available to add'), findsOneWidget);
      expect(find.text('Removing groups is temporarily unavailable'), findsNothing);
      expect(find.byType(DropdownButton<int>), findsNothing);
      expect(find.text('Almeco'), findsNothing, reason: 'no company list on the Groups tab');
    });

    testWidgets('ticking Blue collar and saving adds that group only', (tester) async {
      final api = await openGroups(tester);

      await tester.tap(find.text('White collar'));
      await tester.tap(find.text('Blue collar'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pump();

      final (companyId, userId, kind, ids) = api.adds.single;
      expect((companyId, userId, kind), (1, 2, AssignmentKind.groups));
      expect(ids, [2]);
    });
  });
  group('Access tab (credential groups)', () {
    Future<FakeEmployeeAssignmentsApi> openAccess(WidgetTester tester, {FakeEmployeeAssignmentsApi? api}) async {
      tester.view.physicalSize = const Size(1440, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = api ?? _api();
      await tester.pumpWidget(
        TranslationScope(
          translations: Translations.english(),
          child: MaterialApp(
            theme: JitanTheme.light(),
            home: Scaffold(body: ManageAssignmentsDialog(api: fake, employee: _disan)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Access'));
      await tester.pump();
      return fake;
    }

    testWidgets('matches Figma: picker, current assignments from the database, hint', (tester) async {
      await openAccess(tester);

      expect(find.text('Access and credential groups'), findsOneWidget);
      expect(find.text('Select credential group'), findsOneWidget);
      expect(find.text('Current assignments'), findsOneWidget);
      expect(find.text('Employee'), findsOneWidget, reason: 'the current assignment, listed');
      expect(find.text('Only authorized HR/Admin users can change access. The server enforces permissions.'), findsOneWidget);
    });

    testWidgets('no assignments shows the empty text', (tester) async {
      final api = _api()..byKind[AssignmentKind.credentialGroups] = [_hrRole];
      await openAccess(tester, api: api);

      expect(find.text('Assigned credential groups will appear here.'), findsOneWidget);
    });

    testWidgets('picking HR and saving adds that credential group', (tester) async {
      final api = await openAccess(tester);

      await tester.tap(find.text('Select credential group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HR').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pump();

      final (companyId, userId, kind, ids) = api.adds.single;
      expect((companyId, userId, kind), (1, 2, AssignmentKind.credentialGroups));
      expect(ids, [2]);
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
  group('Language tab (one preferred language)', () {
    Future<FakeEmployeeAssignmentsApi> openLanguage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = _api();
      await tester.pumpWidget(
        TranslationScope(
          translations: Translations.english(),
          child: MaterialApp(
            theme: JitanTheme.light(),
            home: Scaffold(body: ManageAssignmentsDialog(api: fake, employee: _disan)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Language'));
      await tester.pump();
      return fake;
    }

    testWidgets('matches Figma: title, native names with the English name below, radio', (tester) async {
      await openLanguage(tester);

      expect(find.text('Preferred app language'), findsOneWidget);
      expect(find.text('Choose the language used in the employee app and Employee Web.'), findsOneWidget);
      expect(find.text('Nederlands'), findsOneWidget);
      expect(find.text('Dutch'), findsOneWidget);
      expect(
        tester.widgetList<JitanOptionCard>(find.byType(JitanOptionCard)).map((c) => (c.title, c.selected, c.indicator)),
        [('English', true, JitanOptionIndicator.radio), ('Nederlands', false, JitanOptionIndicator.radio)],
      );
    });

    testWidgets('choosing Nederlands moves the selection and saving replaces the language', (tester) async {
      final api = await openLanguage(tester);

      await tester.tap(find.text('Nederlands'));
      await tester.pump();
      expect(
        tester.widgetList<JitanOptionCard>(find.byType(JitanOptionCard)).map((c) => c.selected),
        [false, true],
        reason: 'one choice: English is no longer shown selected',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pump();

      expect(api.languageChanges.single, (1, 2, 2));
      expect(api.adds, isEmpty);
    });
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

  group('removing a company or group (soft delete, Figma 207:329 / 207:441)', () {
    const removableWhite = AssignmentOption(id: 1, name: 'White collar', isActive: true, isAssigned: true, isRemovable: true);
    const removablePca = AssignmentOption(id: 2, name: 'PCA', isActive: true, isAssigned: true, isRemovable: true);

    Future<FakeEmployeeAssignmentsApi> openTab(WidgetTester tester, String tab) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = _api()
        ..byKind[AssignmentKind.groups] = [_blue, removableWhite]
        ..byKind[AssignmentKind.companies] = [_almeco, removablePca];
      await tester.pumpWidget(
        TranslationScope(
          translations: Translations.english(),
          child: MaterialApp(
            theme: JitanTheme.light(),
            home: Scaffold(body: ManageAssignmentsDialog(api: fake, employee: _disan)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(tab));
      await tester.pump();
      return fake;
    }

    testWidgets('an assigned group says "Assigned · select to remove"; tapping asks to confirm', (tester) async {
      final api = await openTab(tester, 'Groups');

      expect(find.text('Assigned · select to remove'), findsOneWidget);
      expect(tester.widget<JitanOptionCard>(find.widgetWithText(JitanOptionCard, 'White collar')).removable, isTrue);

      await tester.tap(find.text('White collar'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Remove employee from group?'), findsOneWidget);
      expect(find.text('The assignment will disappear from Jitan but remain in the database.'), findsOneWidget);
      expect(find.text('Set Active = false and MFD = true in tblUserGroup.'), findsOneWidget);
      expect(find.text('Record the change, actor and time in tblEventLog.'), findsOneWidget);
      expect(api.removes, isEmpty, reason: 'nothing happens before the confirmation');

      await tester.tap(find.text('Remove assignment'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.removes.single, (1, 2, AssignmentKind.groups, 1));
      expect(find.text('Remove employee from group?'), findsNothing);
      expect(find.text('Assigned · select to remove'), findsNothing, reason: 'the list comes from the server');
    });

    testWidgets('Cancel removes nothing', (tester) async {
      final api = await openTab(tester, 'Groups');

      await tester.tap(find.text('White collar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel').last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.removes, isEmpty);
      expect(find.text('Assigned · select to remove'), findsOneWidget);
    });

    testWidgets('an additional company is removed after confirmation; the current one is not offered', (tester) async {
      final api = await openTab(tester, 'Companies');

      expect(find.text('Current company'), findsOneWidget);
      await tester.tap(find.text('Almeco'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Remove employee from company?'), findsNothing, reason: 'the current company is locked');

      await tester.tap(find.text('PCA'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Remove employee from company?'), findsOneWidget);
      expect(find.text('Set Active = false and MFD = true in tblUserCompany.'), findsOneWidget);
      await tester.tap(find.text('Remove assignment'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.removes.single, (1, 2, AssignmentKind.companies, 2));
    });

    testWidgets('a refused removal is explained and the dialog stays open', (tester) async {
      final api = await openTab(tester, 'Groups');
      api.removeFailure = const ApiClientException.network('offline');

      await tester.tap(find.text('White collar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Remove assignment'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Remove employee from group?'), findsOneWidget);
      expect(find.byType(JitanInlineError), findsOneWidget);
    });
  });
}
