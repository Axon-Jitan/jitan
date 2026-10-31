import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../geofencing/away_reminder.dart';
import '../geofencing/workplace_presence.dart';
import '../l10n/employee_text_keys.dart';
import '../period/period_screen.dart';
import '../profile/profile_screens.dart';
import '../qr/my_qr_screen.dart';
import '../today/time_entry_screen.dart';
import '../today/today_controller.dart';
import '../today/today_text.dart';
import '../today/today_widgets.dart';
import '../widgets/mobile_widgets.dart';

/// Where a signed-in employee lands: "Today" (Figma 1444:3 not started,
/// 1436:128 working, 1436:213 complete, 22:2 first day), with Start work,
/// Finish work and the corrections "Forgot to start?" / "Finished earlier?".
///
/// A 401 means the session is no longer valid (expired, password changed,
/// account disabled): [onSessionEnded] signs the device out.
///
/// The navigation bar switches between Home, Period (Figma 48:2) and My QR
/// (50:67), and opens Profile.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.meApi,
    required this.timeRegistrationsApi,
    required this.presence,
    required this.reminder,
    required this.onSessionEnded,
    required this.profileFor,
    this.onReady,
    this.onReturn,
    this.initialAccount,
    this.clock,
  });

  final MeApi meApi;
  final TimeRegistrationsApi timeRegistrationsApi;
  final WorkplacePresence presence;
  final AwayReminder reminder;
  final VoidCallback onSessionEnded;

  /// Called once when the employee arrives here: turns on detection.
  final Future<void> Function()? onReady;

  /// Called when the app comes back to the foreground, before the day loads.
  final Future<void> Function()? onReturn;

  /// What the Profile screens need, for the account as known so far.
  final ProfileContext Function(EmployeeAccount? account) profileFor;

  /// Known right after onboarding; saves a request.
  final EmployeeAccount? initialAccount;

  /// The phone's clock; `DateTime.now` when `null`.
  final DateTime Function()? clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late EmployeeAccount? _account = widget.initialAccount;
  late final _today = TodayController(
    widget.timeRegistrationsApi,
    presence: widget.presence,
    reminder: widget.reminder,
    onSessionEnded: widget.onSessionEnded,
    clock: widget.clock,
  )..load();

  /// Moves "Registered today" and the greeting on while the screen is open.
  late final Timer _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
    if (mounted) setState(() {});
  });

  /// Back in the foreground: load the day again, so a correction HR
  /// approved meanwhile shows without pulling to refresh.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () async {
      await widget.onReturn?.call();
      await _today.load();
    },
  );

  @override
  void initState() {
    super.initState();
    _ticker;
    _lifecycle;
    if (_account == null) _loadAccount();
    widget.onReady?.call().then((_) {
      // An arrival may have been registered; a failed load keeps its message.
      if (mounted && _today.state is TodayLoaded) _today.load();
    });
  }

  Future<void> _loadAccount() async {
    try {
      final account = await widget.meApi.me();
      if (mounted) setState(() => _account = account);
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) widget.onSessionEnded();
      // Offline or server trouble: stay signed in; the name just isn't shown.
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    _lifecycle.dispose();
    _today.dispose();
    super.dispose();
  }

  void _openProfile() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => ProfileScreen(profile: widget.profileFor(_account))));

  /// Home (0), Period (1) or My QR (2).
  int _tab = 0;

  void _select(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    // Back on Home: what changed in Period (a time added) shows at once.
    if (tab == 0) _today.load();
  }

  Widget _navBar(BuildContext context) => EmployeeNavBar(
    items: [
      EmployeeNavItem(icon: Icons.home_outlined, label: context.t(EmployeeTextKeys.navHome), selected: _tab == 0, onTap: () => _select(0)),
      EmployeeNavItem(icon: Icons.schedule, label: context.t(EmployeeTextKeys.navPeriod), selected: _tab == 1, onTap: () => _select(1)),
      EmployeeNavItem(icon: Icons.qr_code_2, label: context.t(EmployeeTextKeys.navQr), selected: _tab == 2, onTap: () => _select(2)),
      EmployeeNavItem(icon: Icons.person_outline, label: context.t(EmployeeTextKeys.navProfile), onTap: _openProfile),
    ],
  );

  void _correct(MyDay day, RegistrationBoundary boundary) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TimeEntryScreen(
        boundary: boundary,
        entry: RegistrationEntry.corrected,
        scheduled: boundary == RegistrationBoundary.start ? day.scheduledStart : day.scheduledFinish,
        now: _today.now,
        onConfirm: (hour, minute, reason) =>
            _today.registerAt(boundary, RegistrationEntry.corrected, hour, minute, reason: reason),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => switch (_tab) {
    1 => PeriodScreen(
      api: widget.timeRegistrationsApi,
      onSessionEnded: widget.onSessionEnded,
      clock: widget.clock,
      bottomBar: _navBar(context),
    ),
    2 => MyQrScreen(meApi: widget.meApi, account: _account, onSessionEnded: widget.onSessionEnded, bottomBar: _navBar(context)),
    _ => _home(context),
  };

  Widget _home(BuildContext context) => ListenableBuilder(
    listenable: _today,
    builder: (context, _) => switch (_today.state) {
      TodayLoading() => _page(context, children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator(color: JitanColors.ink, strokeWidth: 2)),
      ]),
      TodayFailed() => _page(
        context,
        children: [
          const SizedBox(height: 40),
          Text(context.t(EmployeeTextKeys.todayLoadFailedTitle), style: JitanMobileTextStyles.title.copyWith(fontSize: 26)),
          const SizedBox(height: 10),
          Text(context.t(EmployeeTextKeys.todayCheckConnection), style: JitanMobileTextStyles.body),
        ],
        button: JitanMobileButton(label: context.t(EmployeeTextKeys.todayTryAgain), onPressed: _today.retry),
      ),
      TodayLoaded(:final day) => switch (TodayController.phaseOf(day)) {
        TodayPhase.firstDay => TimeEntryScreen(
          key: const ValueKey('first-day'),
          boundary: RegistrationBoundary.start,
          entry: RegistrationEntry.firstDay,
          scheduled: day.scheduledStart,
          now: _today.now,
          onConfirm: (hour, minute, _) => _today.registerAt(RegistrationBoundary.start, RegistrationEntry.firstDay, hour, minute),
          bottomBar: _navBar(context),
        ),
        TodayPhase.notStarted => _notStarted(context, day),
        TodayPhase.working => switch (_today.away) {
          final away? when _today.needsAnswer => _question(context, away),
          final away? => _away(context, away),
          null => _working(context, day),
        },
        TodayPhase.complete => switch (_today.away) {
          final away? when away.onBreak => _away(context, away),
          _ => _complete(context, day),
        },
      },
    },
  );

  /// Logo, scrollable content, then the link, the main button and the bar.
  Widget _page(BuildContext context, {required List<Widget> children, Widget? link, Widget? button}) => Scaffold(
    backgroundColor: JitanColors.warmWhite,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                color: JitanColors.ink,
                onRefresh: _today.load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const JitanWordmark(), const SizedBox(height: 40), ...children],
                  ),
                ),
              ),
            ),
            if (_today.registerFailure != null) ...[
              TodayErrorBox(
                title: context.t(
                  TodayController.phaseOf((_today.state as TodayLoaded).day) == TodayPhase.working
                      ? EmployeeTextKeys.todaySaveFinishFailed
                      : EmployeeTextKeys.todaySaveStartFailed,
                ),
                message: context.t(
                  _today.registerFailure!.kind == ApiFailureKind.network
                      ? EmployeeTextKeys.todayCheckConnection
                      : EmployeeTextKeys.todaySaveRefused,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (link != null) ...[Center(child: link), const SizedBox(height: 14)],
            ?button,
            const SizedBox(height: 32),
            _navBar(context),
          ],
        ),
      ),
    ),
  );

  Widget _title(String text) => Semantics(header: true, child: Text(text, style: JitanMobileTextStyles.title));

  Widget _notStarted(BuildContext context, MyDay day) => _page(
    context,
    children: [
      _title(TodayText.greeting(context, _account?.firstName, _today.now())),
      const SizedBox(height: 10),
      Text(context.t(EmployeeTextKeys.todayNotStartedText), style: JitanMobileTextStyles.body),
      const SizedBox(height: 36),
      TodayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TodayEyebrow(context.t(EmployeeTextKeys.todayScheduleTitle)),
            const SizedBox(height: 14),
            if (day.scheduledStart == null && day.scheduledFinish == null)
              Text(context.t(EmployeeTextKeys.todayScheduleNone), style: JitanMobileTextStyles.cardTitle)
            else
              Text(
                TodayText.range(day.scheduledStart, day.scheduledFinish),
                style: JitanMobileTextStyles.displayLarge.copyWith(fontSize: 30),
              ),
            if (day.breakMinutes case final minutes? when minutes > 0) ...[
              const SizedBox(height: 14),
              Text(context.t(EmployeeTextKeys.todayBreak, args: {'minutes': minutes}), style: JitanMobileTextStyles.cardText),
            ],
          ],
        ),
      ),
    ],
    link: TodayLink(
      label: context.t(EmployeeTextKeys.todayForgotStart),
      onPressed: _today.busy ? null : () => _correct(day, RegistrationBoundary.start),
    ),
    button: JitanMobileButton(
      label: context.t(EmployeeTextKeys.todayStartWork),
      busy: _today.busy,
      onPressed: () => _today.registerNow(RegistrationBoundary.start),
    ),
  );

  /// Travelling or Other: the time and reason wait for HR (D34, D31).
  void _answerWithTime(MyDay day) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TimeEntryScreen(
        boundary: RegistrationBoundary.finish,
        entry: RegistrationEntry.corrected,
        scheduled: day.scheduledFinish,
        now: _today.now,
        onConfirm: (hour, minute, reason) => _today.answerWithTime(hour, minute, reason ?? ''),
      ),
    ),
  );

  /// Figma 19:76, an hour after leaving. Different from Figma on purpose:
  /// the note says "the time you left", because the rounded time is the
  /// server's to work out (rule §6).
  Widget _question(BuildContext context, AwayFromWorkplace away) {
    final day = (_today.state as TodayLoaded).day;
    final left = away.leftAt.toLocal();
    final time = '${left.hour.toString().padLeft(2, '0')}:${left.minute.toString().padLeft(2, '0')}';
    Widget option(String key, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: JitanColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _today.busy ? null : onTap,
          child: Container(
            height: 48,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(context.t(key), style: JitanMobileTextStyles.cardTitleSmall.copyWith(fontSize: 14)),
          ),
        ),
      ),
    );
    return _page(
      context,
      children: [
        _title(context.t(EmployeeTextKeys.todayAnswerTitle)),
        const SizedBox(height: 10),
        Text(
          away.name == null
              ? context.t(EmployeeTextKeys.todayAnswerTextNoName, args: {'time': time})
              : context.t(EmployeeTextKeys.todayAnswerText, args: {'place': away.name!, 'time': time}),
          style: JitanMobileTextStyles.body,
        ),
        const SizedBox(height: 26),
        TodayChip(label: context.t(EmployeeTextKeys.todayAnswerChip), filled: true, tinted: true, color: JitanColors.errorStrong),
        const SizedBox(height: 18),
        TodayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t(EmployeeTextKeys.todayAnswerCard), style: JitanMobileTextStyles.cardTitle.copyWith(fontSize: 24)),
              const SizedBox(height: 14),
              option(EmployeeTextKeys.todayAnswerFinished, _today.answerFinished),
              option(EmployeeTextKeys.todayAnswerBreak, _today.answerBreak),
              option(EmployeeTextKeys.todayAnswerTravelling, () => _answerWithTime(day)),
              option(EmployeeTextKeys.todayAnswerOther, () => _answerWithTime(day)),
              const SizedBox(height: 6),
              Text(context.t(EmployeeTextKeys.todayAnswerNote), style: JitanMobileTextStyles.cardText),
            ],
          ),
        ),
      ],
    );
  }

  /// Figma 19:52. Registers nothing: the day just keeps running (D32).
  Widget _away(BuildContext context, AwayFromWorkplace away) {
    final minutes = _today.now().difference(away.leftAt).inMinutes.clamp(0, 24 * 60);
    final left = away.leftAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return _page(
      context,
      children: [
        _title(context.t(EmployeeTextKeys.todayAwayTitle)),
        const SizedBox(height: 10),
        Text(
          away.name == null
              ? context.t(EmployeeTextKeys.todayAwayTextNoName)
              : context.t(EmployeeTextKeys.todayAwayText, args: {'place': away.name!}),
          style: JitanMobileTextStyles.body,
        ),
        const SizedBox(height: 26),
        TodayChip(label: context.t(EmployeeTextKeys.todayAwayChip), filled: true, tinted: true, color: JitanColors.warning),
        const SizedBox(height: 18),
        TodayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(EmployeeTextKeys.todayAwayMinutes, args: {'minutes': minutes}),
                style: JitanMobileTextStyles.displayLarge.copyWith(fontSize: 40),
              ),
              Text(context.t(EmployeeTextKeys.todayAwayLabel), style: JitanMobileTextStyles.cardText),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t(EmployeeTextKeys.todayAwayLeftAt, args: {'time': '${two(left.hour)}:${two(left.minute)}'}),
                      style: JitanMobileTextStyles.cardTitleSmall,
                    ),
                  ),
                  Text(context.t(EmployeeTextKeys.todayAwayNoAction), style: JitanMobileTextStyles.cardText),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TodayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t(EmployeeTextKeys.todayAwayKeepTitle), style: JitanMobileTextStyles.cardTitleSmall),
              const SizedBox(height: 8),
              Text(context.t(EmployeeTextKeys.todayAwayKeepText), style: JitanMobileTextStyles.cardText),
            ],
          ),
        ),
      ],
    );
  }

  Widget _working(BuildContext context, MyDay day) {
    final start = shownTime(day.day, RegistrationBoundary.start);
    // Since the start, minus the part of the break already passed (D13).
    final elapsed = start.at == null
        ? null
        : day.day!.awayMinutes > 0
        // Back from time away: it replaces the break (D34).
        ? _today.now().difference(start.at!).inMinutes - day.day!.awayMinutes
        : RunningTotal.minutes(start: start.at!, now: _today.now(), breakStart: day.breakStart, breakFinish: day.breakFinish);
    final method = day.day?.start?.method ?? TimeRecordMethod.manual;
    final light = JitanMobileTextStyles.cardText.copyWith(color: JitanColors.sidebarText);
    return _page(
      context,
      children: [
        _title(context.t(EmployeeTextKeys.todayWorkingTitle)),
        const SizedBox(height: 14),
        TodayChip(label: context.t(EmployeeTextKeys.todayWorkingChip), color: JitanColors.inkMuted),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          decoration: BoxDecoration(color: JitanColors.ink, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: TodayEyebrow(context.t(EmployeeTextKeys.todayWorkingRegistered), color: JitanColors.sidebarText)),
                  if (start.local case final local?)
                    Text(context.t(EmployeeTextKeys.todayWorkingStarted, args: {'time': local}), style: light),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                elapsed == null ? '—' : TodayText.duration(context, elapsed),
                style: JitanMobileTextStyles.displayLarge.copyWith(fontSize: 40, color: JitanColors.warmWhite),
              ),
              const SizedBox(height: 14),
              Text(TodayText.method(context, method), style: light),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TodayCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t(EmployeeTextKeys.todayWorkdayTitle), style: JitanMobileTextStyles.cardTitle),
              const SizedBox(height: 14),
              _workdayRow(
                leading: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: start.pending ? JitanColors.warning : JitanColors.success, shape: BoxShape.circle),
                ),
                title: context.t(EmployeeTextKeys.todayWorkdayStarted),
                detail: context.t(switch ((start.pending, method)) {
                  (true, _) => EmployeeTextKeys.todayWorkdayWaitingForHr,
                  (_, TimeRecordMethod.geofence) => EmployeeTextKeys.todayWorkdayStartedAutomatically,
                  _ => EmployeeTextKeys.todayWorkdayStartedInApp,
                }),
                time: start.local,
              ),
              if (day.scheduledFinish case final finish?) ...[
                const Divider(height: 1, color: JitanColors.inputBorder),
                _workdayRow(
                  leading: const Icon(Icons.schedule, size: 12, color: JitanColors.inkMuted),
                  title: context.t(EmployeeTextKeys.todayWorkdayScheduledFinish),
                  time: finish,
                ),
              ],
            ],
          ),
        ),
      ],
      link: TodayLink(
        label: context.t(EmployeeTextKeys.todayFinishedEarlier),
        onPressed: _today.busy ? null : () => _correct(day, RegistrationBoundary.finish),
      ),
      button: JitanMobileButton(
        label: context.t(EmployeeTextKeys.todayFinishWork),
        busy: _today.busy,
        onPressed: () => _today.registerNow(RegistrationBoundary.finish),
      ),
    );
  }

  Widget _workdayRow({required Widget leading, required String title, String? detail, String? time}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 20, height: 18, child: Align(alignment: Alignment.centerLeft, child: leading)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: JitanMobileTextStyles.cardTitleSmall.copyWith(fontSize: 14)),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(detail, style: JitanMobileTextStyles.cardText),
              ],
            ],
          ),
        ),
        if (time != null) Text(time, style: JitanMobileTextStyles.cardTitleSmall.copyWith(fontSize: 14)),
      ],
    ),
  );

  Widget _complete(BuildContext context, MyDay day) {
    final waiting = day.day?.pending.isNotEmpty ?? false;
    final start = shownTime(day.day, RegistrationBoundary.start);
    final finish = shownTime(day.day, RegistrationBoundary.finish);
    return _page(
      context,
      children: [
        _title(context.t(EmployeeTextKeys.todayCompleteTitle)),
        const SizedBox(height: 10),
        Text(
          context.t(waiting ? EmployeeTextKeys.todayCompleteWaitingText : EmployeeTextKeys.todayCompleteText),
          style: JitanMobileTextStyles.body,
        ),
        const SizedBox(height: 24),
        TodayChip(
          label: context.t(waiting ? EmployeeTextKeys.todayCompleteWaitingChip : EmployeeTextKeys.todayCompleteChip),
          filled: true,
          color: waiting ? JitanColors.warning : JitanColors.ink,
        ),
        const SizedBox(height: 22),
        TodayCard(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (day.registeredMinutes case final minutes?) ...[
                Text(TodayText.duration(context, minutes), style: JitanMobileTextStyles.displayLarge.copyWith(fontSize: 40)),
                const SizedBox(height: 2),
                Text(context.t(EmployeeTextKeys.todayCompleteRegistered), style: JitanMobileTextStyles.body),
                const SizedBox(height: 22),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(TodayText.range(start.local, finish.local), style: JitanMobileTextStyles.cardTitleSmall.copyWith(fontSize: 14)),
                  ),
                  if (day.breakMinutes case final minutes? when minutes > 0)
                    Text(context.t(EmployeeTextKeys.todayBreak, args: {'minutes': minutes}), style: JitanMobileTextStyles.cardText),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
