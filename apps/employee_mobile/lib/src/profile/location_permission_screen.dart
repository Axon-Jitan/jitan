import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../device/permissions_gateway.dart';
import '../geofencing/workplace_presence.dart';
import '../l10n/employee_text_keys.dart';
import '../widgets/phone_step_page.dart';
import '../widgets/phone_widgets.dart';
import 'location_status.dart';

/// Profile → Location access (Figma `1612:120`, `1612:181`, 2026-11-13):
/// whether automatic registration can work on this phone, and what location
/// is used for. "Open phone settings" is the main button only when something
/// is off; otherwise a quiet link.
class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key, required this.permissions, required this.presence, required this.bottomBar});

  final PermissionsGateway permissions;
  final WorkplacePresence presence;
  final Widget bottomBar;

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  LocationStatus? _status;

  /// Back from the phone's settings, the answer may have changed.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _load);

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final status = await LocationStatus.read(widget.permissions, widget.presence);
    if (mounted) setState(() => _status = status);
  }

  Widget _row(BuildContext context, String label, bool? on) => PhoneListRow(
    title: context.t(label),
    titleStyle: JitanMobileTextStyles.rowText,
    value: on == null ? null : context.t(on ? EmployeeTextKeys.profileAllowed : EmployeeTextKeys.profileOff),
    valueColor: on == false ? JitanColors.warning : null,
  );

  Widget _use(BuildContext context, String title, String text) =>
      PhoneListRow(title: context.t(title), titleStyle: JitanMobileTextStyles.rowText, detail: context.t(text));

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final settings = context.t(EmployeeTextKeys.locationOpenSettings);
    final problem = status == null || status.allowed
        ? null
        : status.needsSettings
        ? EmployeeTextKeys.locationAccessCheckText
        : EmployeeTextKeys.locationOffLine;
    return PhoneStepPage(
      showBack: true,
      onBack: () => Navigator.of(context).maybePop(),
      title: context.t(EmployeeTextKeys.locationTitle),
      subtitle: context.t(EmployeeTextKeys.locationText),
      action: status != null && !status.allowed
          ? JitanMobileButton(label: settings, size: JitanMobileButtonSize.phone, onPressed: widget.permissions.openSettings)
          : null,
      link: status != null && status.allowed ? PhoneQuietLink(label: settings, onPressed: widget.permissions.openSettings) : null,
      bottomBar: widget.bottomBar,
      children: [
        PhoneListCard(
          padding: EdgeInsets.zero,
          children: [_row(context, EmployeeTextKeys.locationRow, status?.whileInUse), _row(context, EmployeeTextKeys.locationWhileClosed, status?.always)],
        ),
        if (problem != null) ...[const SizedBox(height: 12), Text(context.t(problem), style: JitanMobileTextStyles.detail)],
        const SizedBox(height: 28),
        Text(context.t(EmployeeTextKeys.locationHowTitle), style: JitanMobileTextStyles.label),
        const SizedBox(height: 8),
        PhoneListCard(
          padding: EdgeInsets.zero,
          children: [
            _use(context, EmployeeTextKeys.locationUseEventsTitle, EmployeeTextKeys.locationUseEventsText),
            _use(context, EmployeeTextKeys.locationUseNoTrackingTitle, EmployeeTextKeys.locationUseNoTrackingText),
            _use(context, EmployeeTextKeys.locationUseWorkdayTitle, EmployeeTextKeys.locationUseWorkdayText),
          ],
        ),
      ],
    );
  }
}
