import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../device/device_settings.dart';
import '../home/home_page.dart';
import '../l10n/employee_text_keys.dart';
import '../l10n/language_names.dart';
import '../widgets/phone_widgets.dart';
import 'change_password_screen.dart';
import 'location_permission_screen.dart';
import 'location_status.dart';
import 'profile_context.dart';
import 'profile_language_screen.dart';
import 'registration_method_screen.dart';
import 'sign_out_sheet.dart';

/// The Profile tab (Figma `1611:4`, 2026-11-13): the employee's name and
/// code as the title, one list whose rows show their value as in iPhone
/// Settings, and Sign out, which asks in a sheet. Pages opened from here
/// keep the tab bar.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profile, required this.bottomBar});

  final ProfileContext profile;
  final Widget bottomBar;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  RegistrationMethod? _method;
  LocationStatus? _location;

  /// "Your password was changed." for a moment after a change.
  bool _passwordChanged = false;
  Timer? _toast;

  /// Back from the phone's settings, location may have changed.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _load);

  ProfileContext get _profile => widget.profile;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _load();
  }

  @override
  void dispose() {
    _toast?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final method = await _profile.settings.registrationMethod() ?? RegistrationMethod.manual;
    final location = await LocationStatus.read(_profile.permissions, _profile.presence);
    if (mounted) {
      setState(() {
        _method = method;
        _location = location;
      });
    }
  }

  /// Opens a page with the tab bar under it; the rows' values may have
  /// changed when it closes.
  Future<T?> _open<T>(Widget Function(Widget bottomBar) page) async {
    final result = await Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page(widget.bottomBar)));
    await _load();
    return result;
  }

  Future<void> _changePassword() async {
    final changed = await _open<bool>((bar) => ChangePasswordScreen(profile: _profile, bottomBar: bar));
    if ((changed ?? false) && mounted) {
      _toast?.cancel();
      setState(() => _passwordChanged = true);
      _toast = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _passwordChanged = false);
      });
    }
  }

  Future<void> _signOut() async {
    if (await askToSignOut(context)) _profile.onSignOut();
  }

  /// The row's value: short, so the row stays one line ("QR", not "QR at
  /// a Jitan Terminal"); the page names it in full.
  String _methodName(BuildContext context, RegistrationMethod method) => context.t(switch (method) {
    RegistrationMethod.automatic => EmployeeTextKeys.methodAutomaticTitle,
    RegistrationMethod.qr => EmployeeTextKeys.profileMethodQrValue,
    RegistrationMethod.manual => EmployeeTextKeys.methodManualTitle,
  });

  /// "Allowed", "Off" or "Check settings"; amber when automatic registration
  /// needs location and doesn't have it.
  (String, Color?)? _locationValue(BuildContext context) {
    final location = _location;
    if (location == null) return null;
    final key = location.allowed
        ? EmployeeTextKeys.profileAllowed
        : location.needsSettings
        ? EmployeeTextKeys.profileCheck
        : EmployeeTextKeys.profileOff;
    final attention = !location.allowed && _method == RegistrationMethod.automatic;
    return (context.t(key), attention ? JitanColors.warning : null);
  }

  @override
  Widget build(BuildContext context) {
    final account = _profile.account;
    final name = [account?.firstName, account?.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    final method = _method;
    final location = _locationValue(context);
    final row = JitanMobileTextStyles.rowText;
    return HomePage(
      navBar: widget.bottomBar,
      onRefresh: _load,
      title: account == null ? context.t(EmployeeTextKeys.profileTitle) : (name.isEmpty ? account.code : name),
      subtitle: account == null ? null : [account.code, ...account.companies].join(' · '),
      note: _passwordChanged ? _Toast(text: context.t(EmployeeTextKeys.profilePasswordChanged)) : null,
      children: [
        PhoneListCard(
          padding: EdgeInsets.zero,
          children: [
            PhoneListRow(
              title: context.t(EmployeeTextKeys.profileMethodTitle),
              titleStyle: row,
              value: method == null ? null : _methodName(context, method),
              trailing: const PhoneChevron(),
              onTap: () => _open<void>(
                (bar) => RegistrationMethodScreen(
                  settings: _profile.settings,
                  permissions: _profile.permissions,
                  onChanged: _profile.onMethodChanged,
                  bottomBar: bar,
                ),
              ),
            ),
            PhoneListRow(
              title: context.t(EmployeeTextKeys.profileLocationRow),
              titleStyle: row,
              value: location?.$1,
              valueColor: location?.$2,
              trailing: const PhoneChevron(),
              onTap: () => _open<void>((bar) => LocationPermissionScreen(permissions: _profile.permissions, presence: _profile.presence, bottomBar: bar)),
            ),
            PhoneListRow(
              title: context.t(EmployeeTextKeys.profileLanguageRow),
              titleStyle: row,
              value: LanguageNames.current(context),
              trailing: const PhoneChevron(),
              onTap: () => _open<void>((bar) => ProfileLanguageScreen(profile: _profile, bottomBar: bar)),
            ),
            PhoneListRow(title: context.t(EmployeeTextKeys.profilePasswordRow), titleStyle: row, trailing: const PhoneChevron(), onTap: _changePassword),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _signOut,
            style: TextButton.styleFrom(
              foregroundColor: JitanColors.inkMuted,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              context.t(EmployeeTextKeys.profileSignOut),
              style: JitanMobileTextStyles.rowText.copyWith(color: JitanColors.inkMuted, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

/// A short dark confirmation above the tab bar.
class _Toast extends StatelessWidget {
  const _Toast({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: JitanColors.ink, borderRadius: BorderRadius.circular(14)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: JitanMobileTextStyles.rowText.copyWith(color: JitanColors.surface, fontWeight: FontWeight.w500),
      ),
    ),
  );
}
