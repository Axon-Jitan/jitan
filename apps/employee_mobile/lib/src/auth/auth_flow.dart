import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_screens.dart';

/// Shows the screen for the sign-in controller's step. Back from the sign-in
/// screen itself returns to onboarding ([onLeave]).
class AuthFlow extends StatelessWidget {
  const AuthFlow({super.key, required this.controller, required this.onLeave});

  final AuthController controller;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !controller.back()) onLeave();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(controller.step),
          child: switch (controller.step) {
            AuthStep.signIn => SignInScreen(controller: controller, onUseQr: onLeave),
            AuthStep.forgotPassword => ForgotPasswordScreen(controller: controller),
            AuthStep.recovery => RecoveryScreen(controller: controller),
            AuthStep.error => AuthErrorScreen(controller: controller),
          },
        ),
      ),
    ),
  );
}
