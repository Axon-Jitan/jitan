import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../device/permissions_gateway.dart';
import '../geofencing/workplace_presence.dart';
import '../l10n/employee_text_keys.dart';
import '../widgets/mobile_widgets.dart';
import 'profile_screens.dart';

/// Profile / Location permission (Figma 94:23): whether automatic
/// registration can work on this phone, and what location is used for.
/// Figma draws the allowed state; the other states use the same layout.
///
/// Calmer than Figma, on purpose (Apple, Stripe, Notion): the three uses are
/// one grouped list, and the main button shows only when something needs
/// fixing; otherwise the phone's settings are a quiet link.
class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key, required this.permissions, required this.presence});

  final PermissionsGateway permissions;
  final WorkplacePresence presence;

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  LocationAccess? _access;
  bool _refused = false;

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
    final access = await widget.permissions.locationAccess();
    final refused = await widget.presence.geofencesRefused();
    if (mounted) {
      setState(() {
        _access = access;
        _refused = refused;
      });
    }
  }

  Widget _card({required Widget child, Color color = JitanColors.surface}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
    child: child,
  );

  Widget _status(IconData icon, String title, String status, Color statusColor, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: JitanColors.ink),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: JitanMobileTextStyles.cardTitleSmall)),
                Text(status, style: JitanMobileTextStyles.fieldLabel.copyWith(color: statusColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: JitanMobileTextStyles.cardText.copyWith(color: JitanColors.ink)),
          ],
        ),
      ),
    ],
  );

  /// One row of the grouped list.
  Widget _use(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: JitanColors.ink),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: JitanMobileTextStyles.cardTitleSmall.copyWith(fontSize: 14)),
              const SizedBox(height: 4),
              Text(text, style: JitanMobileTextStyles.cardText),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final access = _access;
    final allowed = access?.whileInUse ?? false;
    final working = allowed && !_refused;
    final (status, statusColor, text) = switch ((allowed, _refused)) {
      (false, _) => (EmployeeTextKeys.locationStatusOff, JitanColors.errorStrong, EmployeeTextKeys.locationAccessOffText),
      (true, true) => (EmployeeTextKeys.locationStatusCheck, JitanColors.warning, EmployeeTextKeys.locationAccessCheckText),
      _ => (EmployeeTextKeys.locationStatusAllowed, JitanColors.success, EmployeeTextKeys.locationAccessText),
    };
    final background = access?.always ?? false;
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OnboardingPage.margin, 10, OnboardingPage.margin, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileSubHeader(title: context.t(EmployeeTextKeys.locationTitle)),
                      const SizedBox(height: 24),
                      Text(context.t(EmployeeTextKeys.locationText), style: JitanMobileTextStyles.body),
                      const SizedBox(height: 20),
                      _card(
                        color: working ? JitanColors.noteSurface : JitanColors.warningSurface,
                        child: _status(
                          Icons.location_on_outlined,
                          context.t(EmployeeTextKeys.locationAccess),
                          context.t(status),
                          statusColor,
                          context.t(text),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(context.t(EmployeeTextKeys.locationHowTitle), style: JitanMobileTextStyles.fieldLabel),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
                        child: Column(
                          children: [
                            _use(Icons.login, context.t(EmployeeTextKeys.locationUseEventsTitle), context.t(EmployeeTextKeys.locationUseEventsText)),
                            const Divider(height: 1, indent: 50, color: JitanColors.inputBorder),
                            _use(Icons.location_off_outlined, context.t(EmployeeTextKeys.locationUseNoTrackingTitle), context.t(EmployeeTextKeys.locationUseNoTrackingText)),
                            const Divider(height: 1, indent: 50, color: JitanColors.inputBorder),
                            _use(Icons.bar_chart, context.t(EmployeeTextKeys.locationUseWorkdayTitle), context.t(EmployeeTextKeys.locationUseWorkdayText)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _card(
                        color: JitanColors.inputFill,
                        child: _status(
                          Icons.smartphone,
                          context.t(EmployeeTextKeys.locationBackground),
                          context.t(background ? EmployeeTextKeys.locationBackgroundOn : EmployeeTextKeys.locationBackgroundOff),
                          background ? JitanColors.success : JitanColors.errorStrong,
                          context.t(EmployeeTextKeys.locationBackgroundText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (working && background)
                Center(
                  child: TextButton(
                    onPressed: widget.permissions.openSettings,
                    child: Text(context.t(EmployeeTextKeys.locationOpenSettings), style: JitanMobileTextStyles.link),
                  ),
                )
              else
                JitanMobileButton(label: context.t(EmployeeTextKeys.locationOpenSettings), onPressed: widget.permissions.openSettings),
            ],
          ),
        ),
      ),
    );
  }
}
