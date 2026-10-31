import 'package:flutter/widgets.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';

/// A failed call, in a project dialog.
class ProjectFailureNote extends StatelessWidget {
  const ProjectFailureNote(this.failure, {super.key});

  final ApiClientException failure;

  @override
  Widget build(BuildContext context) {
    final keys = failureTextKeysFor(failure);
    return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
  }
}
