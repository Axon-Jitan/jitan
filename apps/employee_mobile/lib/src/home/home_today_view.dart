import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../activity/activity_controller.dart';
import '../geofencing/workplace_presence.dart';
import '../l10n/employee_text_keys.dart';
import '../today/time_entry_screen.dart';
import '../today/today_controller.dart';
import '../today/today_text.dart';
import '../widgets/phone_widgets.dart';
import 'home_hero.dart';
import 'home_mode.dart';
import 'home_page.dart';
import 'home_project_row.dart';
import 'home_text.dart';
import 'home_timeline.dart';

/// Every state of Home (Figma `1585:2`): loading, couldn't load, the first
/// day, not started, working, away, "What happened?" and the day done. The
/// main button follows how the employee registers ([HomeMode]).
class HomeTodayView extends StatelessWidget {
  const HomeTodayView({
    super.key,
    required this.today,
    required this.activity,
    required this.mode,
    required this.firstName,
    required this.navBar,
    required this.onCorrect,
    required this.onShowQr,
    required this.onSwitch,
    required this.onAnswerWithTime,
  });

  final TodayController today;
  final ActivityController activity;

  /// `null` while the phone's method is read.
  final HomeMode? mode;
  final String? firstName;
  final Widget navBar;

  /// "Forgot to start?" / "Finished earlier?": a time with a reason.
  final void Function(MyDay day, RegistrationBoundary boundary) onCorrect;
  final VoidCallback onShowQr;
  final VoidCallback onSwitch;

  /// "Travelling for work" / "Other": the time and reason wait for HR.
  final void Function(MyDay day) onAnswerWithTime;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([today, activity]),
    builder: (context, _) {
      final mode = this.mode;
      return switch (today.state) {
        TodayLoaded(:final day) when mode != null => _loaded(context, day, mode),
        TodayFailed() => _page(
          context,
          title: context.t(EmployeeTextKeys.todayLoadFailedTitle),
          subtitle: context.t(EmployeeTextKeys.todayCheckConnection),
          action: _button(context, EmployeeTextKeys.todayTryAgain, today.retry),
        ),
        _ => _page(context, children: const [HomeSkeleton()]),
      };
    },
  );

  Widget _loaded(BuildContext context, MyDay day, HomeMode mode) => switch (TodayController.phaseOf(day)) {
    TodayPhase.firstDay => TimeEntryScreen(
      key: const ValueKey('first-day'),
      boundary: RegistrationBoundary.start,
      entry: RegistrationEntry.firstDay,
      scheduled: day.scheduledStart,
      now: today.now,
      onConfirm: (hour, minute, _) => today.registerAt(RegistrationBoundary.start, RegistrationEntry.firstDay, hour, minute),
      bottomBar: navBar,
    ),
    TodayPhase.notStarted => _notStarted(context, day, mode),
    TodayPhase.working => switch (today.away) {
      final away? when today.needsAnswer => _question(context, day, away),
      final away? => _away(context, away),
      null => _working(context, day, mode),
    },
    TodayPhase.complete => switch (today.away) {
      final away? when away.onBreak => _away(context, away),
      _ => _complete(context, day),
    },
  };

  Widget _page(BuildContext context, {String? title, String? subtitle, List<Widget> children = const [], Widget? action, Widget? link}) =>
      HomePage(
        navBar: navBar,
        onRefresh: today.load,
        title: title,
        subtitle: subtitle,
        notice: today.refreshFailed && today.state is TodayLoaded
            ? PhoneRetryLine(
                message: context.t(EmployeeTextKeys.todayRefreshFailed),
                action: context.t(EmployeeTextKeys.todayTryAgain),
                onPressed: today.load,
              )
            : null,
        note: _saveFailure(context),
        action: action,
        link: link,
        children: children,
      );

  Widget? _saveFailure(BuildContext context) {
    final failure = today.registerFailure;
    final state = today.state;
    if (failure == null || state is! TodayLoaded) return null;
    final finishing = TodayController.phaseOf(state.day) == TodayPhase.working;
    return PhoneErrorNote(
      title: context.t(finishing ? EmployeeTextKeys.todaySaveFinishFailed : EmployeeTextKeys.todaySaveStartFailed),
      message: context.t(
        failure.kind == ApiFailureKind.network ? EmployeeTextKeys.todayCheckConnection : EmployeeTextKeys.todaySaveRefused,
      ),
    );
  }

  Widget _button(BuildContext context, String key, VoidCallback onPressed) =>
      JitanMobileButton(label: context.t(key), size: JitanMobileButtonSize.phone, busy: today.busy, onPressed: onPressed);

  Widget _link(BuildContext context, String key, VoidCallback onPressed) =>
      PhoneQuietLink(label: context.t(key), onPressed: today.busy ? null : onPressed);

  Widget _notStarted(BuildContext context, MyDay day, HomeMode mode) {
    final noSchedule = day.scheduledStart == null && day.scheduledFinish == null;
    final breakMinutes = day.breakMinutes ?? 0;
    void startNow() => today.registerNow(RegistrationBoundary.start);
    return _page(
      context,
      title: TodayText.greeting(context, firstName, today.now()),
      subtitle: context.t(switch (mode) {
        HomeMode.automatic => EmployeeTextKeys.todayNotStartedAutomatic,
        HomeMode.qr => EmployeeTextKeys.todayNotStartedQr,
        HomeMode.manual => EmployeeTextKeys.todayNotStartedText,
      }),
      children: [
        HomeHero(
          label: context.t(EmployeeTextKeys.todayPlanned),
          value: noSchedule ? context.t(EmployeeTextKeys.todayScheduleNone) : HomeText.span(day.scheduledStart, day.scheduledFinish),
          plainValue: noSchedule,
          lines: [
            if (!noSchedule && breakMinutes > 0) context.t(EmployeeTextKeys.todayBreak, args: {'minutes': breakMinutes}),
          ],
        ),
      ],
      action: switch (mode) {
        HomeMode.automatic => null,
        HomeMode.qr => _button(context, EmployeeTextKeys.todayShowQr, onShowQr),
        HomeMode.manual => _button(context, EmployeeTextKeys.todayStartWork, startNow),
      },
      link: switch (mode) {
        HomeMode.automatic => _link(context, EmployeeTextKeys.todayStartNow, startNow),
        HomeMode.qr => _link(context, EmployeeTextKeys.todayStartInApp, startNow),
        HomeMode.manual => _link(context, EmployeeTextKeys.todayForgotStart, () => onCorrect(day, RegistrationBoundary.start)),
      },
    );
  }

  Widget _working(BuildContext context, MyDay day, HomeMode mode) {
    final start = shownTime(day.day, RegistrationBoundary.start);
    final elapsed = start.at == null ? null : RunningTotal.ofToday(day, start.at!, activity.activity.current, today.now());
    final line = HomeText.workingLine(context, day, activity.activity.breakdown);
    final moments = HomeText.timeline(context, day, activity.activity);
    void finishNow() => today.registerNow(RegistrationBoundary.finish);
    return _page(
      context,
      title: context.t(EmployeeTextKeys.todayWorkingTitle),
      subtitle: HomeText.since(context, day),
      children: [
        HomeHero(
          dark: true,
          label: context.t(EmployeeTextKeys.todayWorkingRegistered),
          value: elapsed == null ? '--' : TodayText.duration(context, elapsed),
          lines: [?line],
        ),
        if (activity.showsCard) ...[const SizedBox(height: 12), HomeProjectRow(activity: activity.activity.current, onSwitch: onSwitch)],
        if (moments.isNotEmpty) ...[const SizedBox(height: 12), HomeTimeline(moments: moments)],
      ],
      action: switch (mode) {
        HomeMode.automatic => null,
        HomeMode.qr => _button(context, EmployeeTextKeys.todayShowQr, onShowQr),
        HomeMode.manual => _button(context, EmployeeTextKeys.todayFinishWork, finishNow),
      },
      link: switch (mode) {
        HomeMode.automatic => _link(context, EmployeeTextKeys.todayFinishNow, finishNow),
        HomeMode.qr => _link(context, EmployeeTextKeys.todayFinishInApp, finishNow),
        HomeMode.manual => _link(context, EmployeeTextKeys.todayFinishedEarlier, () => onCorrect(day, RegistrationBoundary.finish)),
      },
    );
  }

  static String _clock(DateTime at) {
    final local = at.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Registers nothing: the day just keeps running (D32).
  Widget _away(BuildContext context, AwayFromWorkplace away) {
    final minutes = today.now().difference(away.leftAt).inMinutes.clamp(0, 24 * 60);
    final time = _clock(away.leftAt);
    return _page(
      context,
      title: context.t(EmployeeTextKeys.todayAwayTitle),
      subtitle: away.name == null
          ? context.t(EmployeeTextKeys.todayAwayTextNoName, args: {'time': time})
          : context.t(EmployeeTextKeys.todayAwayText, args: {'place': away.name!, 'time': time}),
      children: [
        HomeHero(
          label: context.t(EmployeeTextKeys.todayAwayFor),
          value: context.t(EmployeeTextKeys.todayAwayMinutes, args: {'minutes': minutes}),
          lines: [context.t(EmployeeTextKeys.todayAwayNoAction)],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
          child: Text(context.t(EmployeeTextKeys.todayAwayKeepText), style: JitanMobileTextStyles.detail.copyWith(fontSize: 14)),
        ),
      ],
    );
  }

  /// An hour after leaving (D34). Says "the time you left": the rounded
  /// time is the server's to work out (rule §6).
  Widget _question(BuildContext context, MyDay day, AwayFromWorkplace away) {
    final time = _clock(away.leftAt);
    PhoneListRow answer(String key, VoidCallback onTap) => PhoneListRow(
      title: context.t(key),
      titleStyle: JitanMobileTextStyles.rowText.copyWith(fontWeight: FontWeight.w500),
      trailing: const PhoneChevron(),
      onTap: today.busy ? null : onTap,
    );
    return _page(
      context,
      title: context.t(EmployeeTextKeys.todayAnswerTitle),
      subtitle: away.name == null
          ? context.t(EmployeeTextKeys.todayAnswerTextNoName, args: {'time': time})
          : context.t(EmployeeTextKeys.todayAnswerText, args: {'place': away.name!, 'time': time}),
      children: [
        PhoneListCard(
          padding: EdgeInsets.zero,
          children: [
            answer(EmployeeTextKeys.todayAnswerFinished, today.answerFinished),
            answer(EmployeeTextKeys.todayAnswerBreak, today.answerBreak),
            answer(EmployeeTextKeys.todayAnswerTravelling, () => onAnswerWithTime(day)),
            answer(EmployeeTextKeys.todayAnswerOther, () => onAnswerWithTime(day)),
          ],
        ),
        const SizedBox(height: 14),
        Text(context.t(EmployeeTextKeys.todayAnswerNote), style: JitanMobileTextStyles.detail),
      ],
    );
  }

  Widget _complete(BuildContext context, MyDay day) {
    final waiting = day.day?.pending.isNotEmpty ?? false;
    final start = shownTime(day.day, RegistrationBoundary.start);
    final finish = shownTime(day.day, RegistrationBoundary.finish);
    final minutes = day.registeredMinutes;
    final planned = HomeText.plannedLine(context, day);
    final moments = HomeText.timeline(context, day, activity.activity);
    return _page(
      context,
      title: context.t(EmployeeTextKeys.todayCompleteTitle),
      subtitle: HomeText.span(start.local, finish.local),
      children: [
        if (waiting || minutes == null)
          HomeHero(
            label: context.t(EmployeeTextKeys.todayWorkingRegistered),
            value: context.t(EmployeeTextKeys.todayWaitingForHr),
            smallValue: true,
            lines: [context.t(EmployeeTextKeys.todayCompleteWaitingTotal)],
          )
        else
          HomeHero(
            label: context.t(EmployeeTextKeys.todayWorkingRegistered),
            value: TodayText.duration(context, minutes),
            lines: [?planned],
          ),
        if (moments.isNotEmpty) ...[const SizedBox(height: 12), HomeTimeline(moments: moments)],
      ],
    );
  }
}
