import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';

/// "Sign out of Jitan?" from Profile (Figma `1611:146`): a small sheet, not a
/// page. Resolves to `true` when the employee confirmed.
Future<bool> askToSignOut(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: JitanColors.surface,
      showDragHandle: true,
      // As tall as its content: the default 9/16 of the screen is too short
      // on a small phone.
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const _SignOutSheet(),
    ) ??
    false;

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(EmployeeTextKeys.signOutQuestion),
            textAlign: TextAlign.center,
            style: JitanMobileTextStyles.pageTitle.copyWith(fontSize: 20, height: 28 / 20),
          ),
          const SizedBox(height: 8),
          Text(context.t(EmployeeTextKeys.signOutText), textAlign: TextAlign.center, style: JitanMobileTextStyles.pageSubtitle),
          const SizedBox(height: 24),
          JitanMobileButton(
            label: context.t(EmployeeTextKeys.signOutTitle),
            style: JitanMobileButtonStyle.danger,
            size: JitanMobileButtonSize.phone,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: JitanColors.ink, minimumSize: const Size.fromHeight(48)),
            child: Text(context.t(CommonTextKeys.cancel), style: JitanMobileTextStyles.rowTitle),
          ),
        ],
      ),
    ),
  );
}
