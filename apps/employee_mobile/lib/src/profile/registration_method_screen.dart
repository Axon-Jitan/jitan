import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../device/device_settings.dart';
import '../device/permissions_gateway.dart';
import '../l10n/employee_text_keys.dart';
import '../widgets/phone_step_page.dart';
import '../widgets/phone_widgets.dart';

/// Profile → Registration method (Figma `1589:68`, `1589:103`): how the
/// employee's time is registered, the same list as onboarding with the
/// current method marked. Stays on this phone (GAP-07). Automatic needs
/// location, also with the app closed (D30): Save asks for it first.
class RegistrationMethodScreen extends StatefulWidget {
  const RegistrationMethodScreen({super.key, required this.settings, required this.permissions, required this.onChanged, required this.bottomBar});

  final DeviceSettings settings;
  final PermissionsGateway permissions;

  /// Saved: detection follows the new method.
  final Future<void> Function() onChanged;
  final Widget bottomBar;

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
    final allowed =
        method != RegistrationMethod.automatic || (await widget.permissions.requestLocation() && await widget.permissions.requestBackgroundLocation());
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

  Widget _option(BuildContext context, RegistrationMethod method, String title, String text) {
    final selected = _selected == method;
    return PhoneListRow(
      title: context.t(title),
      tag: _current == method ? context.t(EmployeeTextKeys.profileMethodCurrent) : null,
      detail: context.t(text),
      selected: selected,
      trailing: selected ? const PhoneCheck() : null,
      onTap: _busy ? null : () => setState(() => _selected = method),
    );
  }

  @override
  Widget build(BuildContext context) => PhoneStepPage(
    showBack: true,
    onBack: _busy ? null : () => Navigator.of(context).maybePop(),
    title: context.t(EmployeeTextKeys.profileMethodTitle),
    subtitle: context.t(EmployeeTextKeys.profileMethodText),
    action: JitanMobileButton(
      label: context.t(EmployeeTextKeys.profileMethodSave),
      size: JitanMobileButtonSize.phone,
      busy: _busy,
      onPressed: _selected == null || _selected == _current ? null : _save,
    ),
    bottomBar: widget.bottomBar,
    children: [
      PhoneListCard(
        padding: EdgeInsets.zero,
        children: [
          _option(context, RegistrationMethod.automatic, EmployeeTextKeys.methodAutomaticTitle, EmployeeTextKeys.methodAutomaticText),
          _option(context, RegistrationMethod.qr, EmployeeTextKeys.methodQrTitle, EmployeeTextKeys.methodQrText),
          _option(context, RegistrationMethod.manual, EmployeeTextKeys.methodManualTitle, EmployeeTextKeys.methodManualText),
        ],
      ),
      const SizedBox(height: 12),
      Text(context.t(EmployeeTextKeys.profileMethodNote), style: JitanMobileTextStyles.detail),
      if (_locationRefused) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(context.t(EmployeeTextKeys.methodNote), style: JitanMobileTextStyles.detail.copyWith(color: JitanColors.errorStrong)),
        ),
      ],
    ],
  );
}
