import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';
import 'package:logging/logging.dart';

import '../l10n/employee_text_keys.dart';
import '../l10n/language_names.dart';
import '../widgets/phone_step_page.dart';
import '../widgets/phone_widgets.dart';
import 'profile_context.dart';

final _log = Logger('profile.language');

/// Profile → Language (Figma `1612:244`, 2026-11-13; EMP-06): the same list
/// as onboarding. A tap saves it (`PUT /me/language`); the check moves and
/// the app switches only once the server confirmed. English is built in and
/// always first.
class ProfileLanguageScreen extends StatefulWidget {
  const ProfileLanguageScreen({super.key, required this.profile, required this.bottomBar});

  final ProfileContext profile;
  final Widget bottomBar;

  @override
  State<ProfileLanguageScreen> createState() => _ProfileLanguageScreenState();
}

class _ProfileLanguageScreenState extends State<ProfileLanguageScreen> {
  static const _english = Language(id: 0, code: englishLanguageCode, name: 'English');

  List<Language> _languages = const [_english];
  bool _loadFailed = false;

  /// The language being saved, while the server answers.
  String? _saving;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final fromServer = await widget.profile.languagesApi.listLanguages();
      if (mounted) setState(() => _languages = [_english, ...fromServer.where((l) => l.code != englishLanguageCode)]);
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return widget.profile.onSessionEnded();
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _choose(String code) async {
    if (_saving != null || code == TranslationScope.of(context).languageCode) return;
    setState(() {
      _saving = code;
      _saveFailed = false;
    });
    try {
      final saved = await widget.profile.languagesApi.setCurrentUserLanguage(code);
      await widget.profile.onLanguageChanged(saved ?? code);
    } on ApiClientException catch (e) {
      _log.info('Changing the language failed: ${e.kind.name} ${e.statusCode ?? ''}');
      if (e.statusCode == 401) return widget.profile.onSessionEnded();
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = TranslationScope.of(context).languageCode;
    return PhoneStepPage(
      showBack: true,
      onBack: () => Navigator.of(context).maybePop(),
      title: context.t(EmployeeTextKeys.profileLanguageTitle),
      subtitle: context.t(EmployeeTextKeys.profileLanguageText),
      bottomBar: widget.bottomBar,
      children: [
        PhoneListCard(
          padding: EdgeInsets.zero,
          children: [
            for (final language in _languages)
              PhoneListRow(
                title: LanguageNames.own(context, language),
                titleStyle: JitanMobileTextStyles.rowTitle.copyWith(fontWeight: FontWeight.w500),
                detail: LanguageNames.translated(context, language),
                selected: current == language.code,
                trailing: _saving == language.code
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: JitanColors.inkMuted))
                    : current == language.code
                    ? const PhoneCheck()
                    : null,
                onTap: () => _choose(language.code),
              ),
          ],
        ),
        if (_saveFailed) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(context.t(EmployeeTextKeys.profileLanguageFailed), style: JitanMobileTextStyles.detail.copyWith(color: JitanColors.errorStrong)),
          ),
        ],
        if (_loadFailed) ...[
          const SizedBox(height: 4),
          PhoneRetryLine(message: context.t(EmployeeTextKeys.profileLanguagesFailed), action: context.t(EmployeeTextKeys.todayTryAgain), onPressed: _load),
        ],
      ],
    );
  }
}
