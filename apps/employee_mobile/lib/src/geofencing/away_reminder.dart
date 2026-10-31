import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/employee_text_keys.dart';

/// The notification one hour after leaving ("What happened?", D32). Set on
/// the phone itself, so it needs no connection and can be taken back the
/// moment the employee returns. The only place that knows the plugin.
abstract interface class AwayReminder {
  Future<void> schedule(DateTime at);

  Future<void> cancel();
}

class LocalAwayReminder implements AwayReminder {
  LocalAwayReminder();

  static const _id = 1;
  static const _channel = AndroidNotificationDetails(
    'workday',
    'Workday confirmations',
    importance: Importance.high,
    priority: Priority.high,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tz.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
  }

  /// In English: this runs with the app closed, without the employee's
  /// translations (I18N-01).
  @override
  Future<void> schedule(DateTime at) async {
    await _init();
    final english = Translations.english();
    await _plugin.zonedSchedule(
      id: _id,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: english.t(EmployeeTextKeys.todayAnswerCard),
      body: english.t(EmployeeTextKeys.todayAnswerNotification),
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _id);
  }
}
