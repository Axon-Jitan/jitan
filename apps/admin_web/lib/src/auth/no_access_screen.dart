import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'admin_session.dart';
import 'sign_in_card.dart';

/// Signed in, but the server gives this account no HR access (Figma
/// `1469:44`). The server's answer decides, never a role name here (rule §18).
class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key, required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context) => SignInCard(
    children: [
      Semantics(header: true, child: Text(context.t(AdminTextKeys.noAccessTitle), style: JitanTextStyles.modalTitle)),
      const SizedBox(height: 6),
      Text(context.t(AdminTextKeys.noAccessText), style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
      const SizedBox(height: 28),
      JitanSecondaryButton(label: context.t(AdminTextKeys.signOut), onPressed: session.signOut),
    ],
  );
}
