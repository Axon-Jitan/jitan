import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/web_services.dart';
import '../common/web_text.dart';
import '../l10n/employee_web_text_keys.dart';
import 'home_controller.dart';
import 'my_qr_dialog.dart';
import 'switch_activity_dialog.dart';

/// Home (Figma `1499:19`; not started `1501:2`, finished `1501:66`, no project
/// `1501:129`): one number, what they're on, and today as a list. Start and
/// Finish stay on the phone and the terminal, where the day really begins.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services, this.clock});

  final WebServices services;
  final DateTime Function()? clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _controller = HomeController(times: widget.services.times, activities: widget.services.activity, clock: widget.clock)..start();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showQr() => showMyQrDialog(context, me: widget.services.me);

  Future<void> _switch() async {
    await showSwitchActivityDialog(
      context,
      api: widget.services.activity,
      activity: _controller.activity,
      clock: _controller.now,
    );
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (_controller.failed) return WebNoConnection(onRetry: _controller.load);
      final day = _controller.day;
      if (day == null) return JitanLoadingState(label: context.t(EmployeeWebTextKeys.loading));
      return _HomeBody(day: day, controller: _controller, onQr: _showQr, onSwitch: _switch);
    },
  );
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.day, required this.controller, required this.onQr, required this.onSwitch});

  final MyDay day;
  final HomeController controller;
  final VoidCallback onQr;
  final VoidCallback onSwitch;

  TimeRecordDay? get _record => day.day;
  DateTime? get _started => _record?.start?.rounded ?? _record?.start?.actual;
  bool get _isFinished => _record?.finish != null;
  bool get _isWorking => _started != null && !_isFinished;

  String _title(BuildContext context) {
    if (_isFinished) return context.t(EmployeeWebTextKeys.homeDone);
    if (_isWorking) return context.t(EmployeeWebTextKeys.homeWorking);
    final hour = controller.now.hour;
    final key = hour < 12
        ? EmployeeWebTextKeys.homeGreetingMorning
        : hour < 18
        ? EmployeeWebTextKeys.homeGreetingAfternoon
        : EmployeeWebTextKeys.homeGreetingEvening;
    return context.t(key);
  }

  String _subtitle(BuildContext context) {
    final start = _record?.start?.roundedLocal ?? _record?.start?.actualLocal;
    final finish = _record?.finish?.roundedLocal ?? _record?.finish?.actualLocal;
    if (_isFinished) return context.t(EmployeeWebTextKeys.homePlannedRange, args: {'start': start ?? '—', 'finish': finish ?? '—'});
    if (_isWorking) {
      final place = controller.activity.today.firstOrNull?.placeName;
      return place == null
          ? context.t(EmployeeWebTextKeys.homeSince, args: {'time': start ?? '—'})
          : context.t(EmployeeWebTextKeys.homeSinceAt, args: {'time': start ?? '—', 'place': place});
    }
    final planned = day.scheduledStart, end = day.scheduledFinish;
    if (planned == null || end == null) return context.t(EmployeeWebTextKeys.homeNoPlan);
    return context.t(EmployeeWebTextKeys.homePlannedRange, args: {'start': planned, 'finish': end});
  }

  int get _minutes {
    final started = _started;
    if (started == null) return 0;
    if (_isFinished) return day.registeredMinutes ?? 0;
    return RunningTotal.ofToday(day, started, controller.activity.current, controller.now);
  }

  Widget _hero(BuildContext context) {
    final note = _isWorking
        ? (day.scheduledFinish == null ? '' : context.t(EmployeeWebTextKeys.homePlannedFinish, args: {'time': day.scheduledFinish!}))
        : _isFinished
        ? (day.scheduledStart == null ? '' : context.t(EmployeeWebTextKeys.homePlanned, args: {'time': _plannedText(context)}))
        : context.t(EmployeeWebTextKeys.homeStartsWhen);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: JitanColors.ink, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t(EmployeeWebTextKeys.homeRegistered), style: JitanTextStyles.sidebarCaption.copyWith(fontSize: 12)),
          const SizedBox(height: 10),
          FittedBox(
            child: Text(
              WebText.duration(context, _minutes),
              style: JitanTextStyles.pageTitle.copyWith(fontSize: 56, color: JitanColors.surface),
            ),
          ),
          const SizedBox(height: 8),
          Text(note, style: JitanTextStyles.tableCell.copyWith(fontSize: 14, color: JitanColors.sidebarText)),
        ],
      ),
    );
  }

  String _plannedText(BuildContext context) {
    final start = _parse(day.scheduledStart), finish = _parse(day.scheduledFinish);
    if (start == null || finish == null) return '';
    return WebText.duration(context, finish - start - (day.breakMinutes ?? 0));
  }

  static int? _parse(String? hhmm) {
    final parts = hhmm?.split(':');
    return parts == null || parts.length != 2 ? null : int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Widget _card(BuildContext context) {
    final activity = controller.activity;
    final project = activity.current?.project;
    final canSwitch = _isWorking && activity.enabled;
    final qr = JitanSecondaryButton(label: context.t(EmployeeWebTextKeys.homeMyQr), onPressed: onQr);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(project == null ? EmployeeWebTextKeys.homeMyQr : EmployeeWebTextKeys.homeCurrentProject).toUpperCase(),
            style: JitanTextStyles.tableCell.copyWith(fontSize: 12, color: JitanColors.inkMuted),
          ),
          const SizedBox(height: 10),
          Text(
            project?.name ?? context.t(EmployeeWebTextKeys.homeQrTitle),
            overflow: TextOverflow.ellipsis,
            style: JitanTextStyles.modalTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            project == null ? context.t(EmployeeWebTextKeys.homeQrText) : WebText.project(context, project),
            style: JitanTextStyles.tableCell.copyWith(fontSize: 14, color: JitanColors.inkMuted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canSwitch) JitanSecondaryButton(label: context.t(EmployeeWebTextKeys.homeSwitch), onPressed: onSwitch),
              qr,
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _today(BuildContext context) {
    Widget row(String time, String label, String detail) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Row(
        spacing: 16,
        children: [
          SizedBox(width: 48, child: Text(time, style: JitanTextStyles.tableCell.copyWith(fontSize: 14, color: JitanColors.inkMuted))),
          Text(label, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 14)),
          Expanded(
            child: Text(
              detail,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: JitanTextStyles.tableCell.copyWith(fontSize: 14, color: JitanColors.inkMuted),
            ),
          ),
        ],
      ),
    );

    String detail(ActivityEntry entry) {
      if (entry.kind != ActivityKind.transport) return entry.projectName ?? entry.placeName ?? '';
      final parts = [
        if (entry.placeName case final place?) context.t(EmployeeWebTextKeys.entryTo, args: {'place': place}),
        if (entry.metres case final metres?) WebText.kilometres(context, metres),
      ];
      return parts.join(' · ');
    }

    final entries = controller.activity.today;
    final rows = [
      for (final (i, entry) in entries.indexed)
        i == 0
            ? row(entry.timeLocal, context.t(EmployeeWebTextKeys.entryStarted), entry.placeName ?? entry.projectName ?? '')
            : row(entry.timeLocal, WebText.kind(context, entry.kind), detail(entry)),
      // Without activities (a database without the proposed tables), the day itself.
      if (entries.isEmpty && _record?.start?.actualLocal != null)
        row(_record!.start!.actualLocal, context.t(EmployeeWebTextKeys.entryStarted), ''),
      if (_record?.finish?.actualLocal case final time?) row(time, context.t(EmployeeWebTextKeys.entryFinished), ''),
    ];
    return rows.isEmpty
        ? [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.t(EmployeeWebTextKeys.homeNothingYet), style: JitanTextStyles.stateMessage),
            ),
          ]
        : rows;
  }

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return SingleChildScrollView(
      padding: EdgeInsets.all(phone ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanPageHeader(title: _title(context), subtitle: _subtitle(context)),
          const SizedBox(height: 24),
          if (phone) ...[
            _hero(context),
            const SizedBox(height: 16),
            _card(context),
          ] else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  Expanded(child: _hero(context)),
                  SizedBox(width: 400, child: _card(context)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          WebList(rows: _today(context)),
        ],
      ),
    );
  }
}
