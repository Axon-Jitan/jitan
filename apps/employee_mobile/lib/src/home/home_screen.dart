import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../activity/activity_controller.dart';
import '../activity/switch_activity_screen.dart';
import '../device/device_settings.dart';
import '../device/permissions_gateway.dart';
import '../geofencing/away_reminder.dart';
import '../geofencing/workplace_presence.dart';
import '../l10n/employee_text_keys.dart';
import '../period/period_controller.dart';
import '../period/period_screen.dart';
import '../profile/profile_context.dart';
import '../profile/profile_screen.dart';
import '../qr/my_qr_screen.dart';
import '../today/time_entry_screen.dart';
import '../today/today_controller.dart';
import '../today/today_widgets.dart';
import 'home_mode.dart';
import 'home_today_view.dart';

/// Where a signed-in employee lands: Home (Figma `1585:2`), its states drawn
/// by [HomeTodayView]. What it offers follows the registration method:
/// nothing to tap when location registers the day, "Show my QR" for a
/// Terminal, Start work and Finish work in the app.
///
/// A 401 means the session is no longer valid (expired, password changed,
/// account disabled): [onSessionEnded] signs the device out.
///
/// The navigation bar switches between Home, Period (Figma 48:2), My QR
/// (50:67) and Profile (`1611:4`).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.meApi,
    required this.timeRegistrationsApi,
    required this.activityApi,
    required this.presence,
    required this.reminder,
    required this.settings,
    required this.permissions,
    required this.onSessionEnded,
    required this.profileFor,
    this.onReady,
    this.onReturn,
    this.initialAccount,
    this.clock,
  });

  final MeApi meApi;
  final TimeRegistrationsApi timeRegistrationsApi;
  final ActivityApi activityApi;
  final WorkplacePresence presence;
  final AwayReminder reminder;

  /// The registration method chosen on this phone, and whether location
  /// lets it work: what Home offers ([HomeMode]).
  final DeviceSettings settings;
  final PermissionsGateway permissions;
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
  late final TodayController _today = TodayController(
    widget.timeRegistrationsApi,
    presence: widget.presence,
    reminder: widget.reminder,
    onSessionEnded: widget.onSessionEnded,
    onDayLoaded: () {
      _activity.load();
      _loadWeek();
    },
    clock: widget.clock,
  )..load();
  HomeMode? _mode;

  /// This week, for Home's card (Figma `1606:2`); `null` until loaded or when
  /// it couldn't be: the card then stays away, nothing else depends on it.
  MyPeriod? _week;

  Future<void> _loadWeek() async {
    final now = _today.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    try {
      final week = await widget.timeRegistrationsApi.period(
        from: today.subtract(Duration(days: today.weekday - 1)),
        to: today.add(Duration(days: 7 - today.weekday)),
      );
      if (mounted) setState(() => _week = week);
    } on ApiClientException {
      // The day itself says when the connection fails; the card waits.
    }
  }

  /// Period opens on the week from "This week", on the day otherwise.
  PeriodView _periodView = PeriodView.day;

  void _openWeek() => _select(1, periodView: PeriodView.week);

  Future<void> _loadMode() async {
    final mode = await homeModeOf(widget.settings, widget.permissions, widget.presence);
    if (mounted && mode != _mode) setState(() => _mode = mode);
  }

  late final ActivityController _activity = ActivityController(widget.activityApi, onSwitched: () => _today.load(), clock: widget.clock);

  /// Moves "Registered today" and the greeting on while the screen is open.
  late final Timer _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
    if (mounted) setState(() {});
  });

  /// Back in the foreground: load the day again, so a correction HR
  /// approved meanwhile shows without pulling to refresh.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () async {
      // Location access may have changed in the phone's settings.
      unawaited(_loadMode());
      await widget.onReturn?.call();
      await _today.load();
    },
  );

  @override
  void initState() {
    super.initState();
    _ticker;
    _lifecycle;
    _loadMode();
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
    _activity.dispose();
    super.dispose();
  }

  /// The tab bar also shows on pages opened from a tab (a day's details,
  /// Switch, a time entry): a tap on it first closes them, so the tab shows.
  void _closePagesOnTop() {
    final tabs = ModalRoute.of(context);
    if (tabs != null && !tabs.isCurrent) Navigator.of(context).popUntil((route) => route == tabs);
  }

  /// Home (0), Period (1), My QR (2) or Profile (3).
  int _tab = 0;

  void _select(int tab, {PeriodView periodView = PeriodView.day}) {
    _closePagesOnTop();
    // The tab bar opens Period on the day; only "This week" opens the week.
    _periodView = periodView;
    if (tab == _tab) return;
    setState(() => _tab = tab);
    // Back on Home: what changed in Period (a time added) shows at once, and
    // what Home offers follows a method changed in Profile.
    if (tab == 0) {
      _today.load();
      _loadMode();
    }
  }

  Widget _navBar(BuildContext context) => EmployeeNavBar(
    items: [
      EmployeeNavItem(icon: Icons.home_outlined, label: context.t(EmployeeTextKeys.navHome), selected: _tab == 0, onTap: () => _select(0)),
      EmployeeNavItem(icon: Icons.schedule, label: context.t(EmployeeTextKeys.navPeriod), selected: _tab == 1, onTap: () => _select(1)),
      EmployeeNavItem(icon: Icons.qr_code_2, label: context.t(EmployeeTextKeys.navQr), selected: _tab == 2, onTap: () => _select(2)),
      EmployeeNavItem(icon: Icons.person_outline, label: context.t(EmployeeTextKeys.navProfile), selected: _tab == 3, onTap: () => _select(3)),
    ],
  );

  void _correct(MyDay day, RegistrationBoundary boundary) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TimeEntryScreen(
        boundary: boundary,
        entry: RegistrationEntry.corrected,
        scheduled: boundary == RegistrationBoundary.start ? day.scheduledStart : day.scheduledFinish,
        now: _today.now,
        onConfirm: (hour, minute, reason) => _today.registerAt(boundary, RegistrationEntry.corrected, hour, minute, reason: reason),
      ),
    ),
  );

  /// Android's back key on Period, My QR or Profile goes to Home first, as
  /// in other apps with a tab bar; only on Home does it leave the app (user,
  /// 2026-11-13). Pages opened from a tab still go back to their tab.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _tab == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _select(0);
    },
    child: _tabView(context),
  );

  Widget _tabView(BuildContext context) => switch (_tab) {
    1 => PeriodScreen(
      api: widget.timeRegistrationsApi,
      onSessionEnded: widget.onSessionEnded,
      clock: widget.clock,
      bottomBar: _navBar(context),
      current: _activity.activity.current,
      activities: _activity.activity.today,
      initialView: _periodView,
    ),
    2 => MyQrScreen(meApi: widget.meApi, account: _account, onSessionEnded: widget.onSessionEnded, bottomBar: _navBar(context)),
    3 => ProfileScreen(profile: widget.profileFor(_account), bottomBar: _navBar(context)),
    _ => HomeTodayView(
      today: _today,
      activity: _activity,
      mode: _mode,
      firstName: _account?.firstName,
      navBar: _navBar(context),
      onCorrect: _correct,
      onShowQr: () => _select(2),
      onSwitch: _openSwitch,
      onAnswerWithTime: _answerWithTime,
      week: _week,
      onOpenWeek: _openWeek,
    ),
  };

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

  Future<void> _openSwitch() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SwitchActivityScreen(controller: _activity)));
}
