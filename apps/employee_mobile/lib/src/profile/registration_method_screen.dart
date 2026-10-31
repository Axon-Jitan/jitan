import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../device/device_settings.dart';
import '../device/permissions_gateway.dart';
import '../l10n/employee_text_keys.dart';
import '../widgets/mobile_widgets.dart';
import 'profile_screens.dart';

/// Profile / Registration method (Figma 94:2, 631:2, 631:30, 631:58): how the
/// employee's time is recorded. Stays on this phone (GAP-07). Automatic needs
/// the employee's location permission, also with the app closed (D30).
class RegistrationMethodScreen extends StatefulWidget {
  const RegistrationMethodScreen({
    super.key,
    required this.settings,
    required this.permissions,
    required this.onChanged,
  });

  final DeviceSettings settings;
  final PermissionsGateway permissions;

  /// Saved: detection follows the new method.
  final Future<void> Function() onChanged;

  @override
  State<RegistrationMethodScreen> createState() => _RegistrationMethodScreenState();
}

class _RegistrationMethodScreenState extends State<RegistrationMethodScreen> {
  RegistrationMethod? _current;
  RegistrationMethod? _selected;
  bool _busy = false;
  bool _locationRefused = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final method = await widget.settings.registrationMethod() ?? RegistrationMethod.manual;
    if (mounted) {
      setState(() {
        _current = method;
        _selected = method;
      });
    }
  }

  Future<void> _save() async {
    final method = _selected!;
    setState(() {
      _busy = true;
      _locationRefused = false;
    });
    final allowed = method != RegistrationMethod.automatic ||
        (await widget.permissions.requestLocation() && await widget.permissions.requestBackgroundLocation());
    if (!allowed) {
      if (mounted) {
        setState(() {
          _busy = false;
          _locationRefused = true;
        });
      }
      return;
    }
    await widget.settings.setRegistrationMethod(method);
    await widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  Widget _option(
    BuildContext context,
    RegistrationMethod method, {
    required String title,
    required String text,
  }) => InkWell(
    onTap: _busy ? null : () => setState(() => _selected = method),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioDot(selected: _selected == method),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: JitanMobileTextStyles.cardTitleSmall)),
                    if (_current == method)
                      Text(context.t(EmployeeTextKeys.profileMethodCurrent), style: JitanMobileTextStyles.cardText),
                  ],
                ),
                const SizedBox(height: 6),
                Text(text, style: JitanMobileTextStyles.cardText),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
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
                    ProfileSubHeader(
                      title: context.t(EmployeeTextKeys.profileMethodTitle),
                      text: context.t(EmployeeTextKeys.profileMethodText),
                    ),
                    const SizedBox(height: 40),
                    Text(context.t(EmployeeTextKeys.profileMethodEyebrow), style: JitanMobileTextStyles.fieldLabel),
                    const SizedBox(height: 12),
                    Material(
                      color: JitanColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: JitanColors.inputBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _option(
                            context,
                            RegistrationMethod.automatic,
                            title: context.t(EmployeeTextKeys.methodAutomaticTitle),
                            text: context.t(EmployeeTextKeys.methodAutomaticText),
                          ),
                          const Divider(height: 1, indent: 54, endIndent: 16, color: JitanColors.inputBorder),
                          _option(
                            context,
                            RegistrationMethod.manual,
                            title: context.t(EmployeeTextKeys.methodManualTitle),
                            text: context.t(EmployeeTextKeys.methodManualText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: JitanColors.inkMuted),
                        const SizedBox(width: 10),
                        Expanded(child: Text(context.t(EmployeeTextKeys.profileMethodNote), style: JitanMobileTextStyles.cardText)),
                      ],
                    ),
                    if (_locationRefused) ...[
                      const SizedBox(height: 12),
                      Text(
                        context.t(EmployeeTextKeys.methodNote),
                        style: JitanMobileTextStyles.cardText.copyWith(color: JitanColors.errorStrong),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            JitanMobileButton(
              label: context.t(EmployeeTextKeys.profileMethodSave),
              busy: _busy,
              onPressed: _selected == null || _selected == _current ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );
}
