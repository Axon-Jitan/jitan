import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../onboarding/widgets/onboarding_widgets.dart';

/// Where a signed-in employee lands. A placeholder until the Today screens
/// ("Today / 01 …") are built: it proves the session works by loading the
/// account with `GET /me`.
///
/// A 401 means the session is no longer valid (expired, password changed,
/// account disabled): [onSessionEnded] signs the device out.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.meApi, required this.onSessionEnded, this.initialAccount});

  final MeApi meApi;
  final VoidCallback onSessionEnded;

  /// Known right after onboarding; saves a request.
  final EmployeeAccount? initialAccount;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late EmployeeAccount? _account = widget.initialAccount;

  @override
  void initState() {
    super.initState();
    if (_account == null) _load();
  }

  Future<void> _load() async {
    try {
      final account = await widget.meApi.me();
      if (mounted) setState(() => _account = account);
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) widget.onSessionEnded();
      // Offline or server trouble: stay signed in; the name just isn't shown.
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _account?.firstName;
    return OnboardingPage(
      actions: const [],
      children: [
        const SizedBox(height: 45),
        Semantics(
          header: true,
          child: Text(
            firstName == null || firstName.isEmpty
                ? context.t(EmployeeTextKeys.homeGreetingNoName)
                : context.t(EmployeeTextKeys.homeGreeting, args: {'name': firstName}),
            style: JitanMobileTextStyles.title,
          ),
        ),
        const SizedBox(height: 12),
        Text(context.t(EmployeeTextKeys.homeText), style: JitanMobileTextStyles.bodyLarge),
      ],
    );
  }
}
