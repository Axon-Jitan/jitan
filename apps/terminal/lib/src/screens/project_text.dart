import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/terminal_text_keys.dart';

abstract final class ProjectText {
  /// What a project means at this tablet: a client project is on site.
  static ActivityKind kindOf(MyProject project) => project.isClient ? ActivityKind.clientOnSite : ActivityKind.internal;

  /// "On site · Almeco".
  static String detail(BuildContext context, MyProject project) => context.t(
    TerminalTextKeys.projectDetail,
    args: {
      'kind': context.t(project.isClient ? TerminalTextKeys.onSite : TerminalTextKeys.internal),
      'company': project.companyName,
    },
  );
}
