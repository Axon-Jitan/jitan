import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/web_services.dart';
import '../common/web_text.dart';
import '../l10n/employee_web_text_keys.dart';
import 'change_password_dialog.dart';

/// Profile (Figma `1499:839`): only what works in a browser. How the phone
/// registers and what it notifies stay on the phone.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.services, required this.onLanguageChanged});

  final WebServices services;
  final VoidCallback onLanguageChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Language> _languages = const [];

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    try {
      final languages = await widget.services.languages.listLanguages();
      if (mounted) setState(() => _languages = languages);
    } on ApiClientException {
      // The row stays, without a choice.
    }
  }

  Future<void> _setLanguage(String code) async {
    try {
      await widget.services.languages.setCurrentUserLanguage(code);
      widget.onLanguageChanged();
    } on ApiClientException {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.t(EmployeeWebTextKeys.failed))));
      }
    }
  }

  Widget _row(String label, String value, {VoidCallback? onTap}) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        spacing: 12,
        children: [
          Text(label, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 14)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
        ],
      ),
    ),
  );

  Widget _language(BuildContext context) {
    final code = TranslationScope.of(context).languageCode;
    final name = context.tOrNull(CommonTextKeys.languageName(code)) ?? code;
    if (_languages.length < 2) return _row(context.t(EmployeeWebTextKeys.profileLanguage), name);
    return PopupMenuButton<String>(
      onSelected: _setLanguage,
      color: JitanColors.surface,
      tooltip: context.t(EmployeeWebTextKeys.profileLanguage),
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [for (final l in _languages) PopupMenuItem(value: l.code, child: Text(l.name))],
      child: IgnorePointer(child: _row(context.t(EmployeeWebTextKeys.profileLanguage), name, onTap: () {})),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.services.session;
    final account = session.account;
    final name = [account?.firstName, account?.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return SingleChildScrollView(
      padding: EdgeInsets.all(phone ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanPageHeader(
            title: context.t(EmployeeWebTextKeys.profileTitle),
            subtitle: [name, ?account?.code].where((t) => t.isNotEmpty).join(' · '),
          ),
          const SizedBox(height: 24),
          WebList(
            rows: [
              if (account != null) _row(context.t(EmployeeWebTextKeys.profileCompany), account.companies.join(', ')),
              _language(context),
              _row(
                context.t(EmployeeWebTextKeys.profilePassword),
                context.t(EmployeeWebTextKeys.profileChange),
                onTap: () => showChangePasswordDialog(context, session: session),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: session.signOut,
              style: TextButton.styleFrom(foregroundColor: JitanColors.inkMuted),
              child: Text(context.t(EmployeeWebTextKeys.signOut)),
            ),
          ),
        ],
      ),
    );
  }
}
