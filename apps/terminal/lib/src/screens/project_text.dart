import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/terminal_text_keys.dart';

abstract final class ProjectText {
  /// What a project means at this tablet: a client project is on site.
  static ActivityKind kindOf(MyProject project) => project.isClient ? ActivityKind.clientOnSite : ActivityKind.internal;

  /// "Client site · Mouscron", "Our workshop · Almeco".
  static String detail(BuildContext context, MyProject project) {
    final kind = context.t(project.isClient ? TerminalTextKeys.clientSite : TerminalTextKeys.ourWorkshop);
    final place = project.placeName;
    if (place == null || place.isEmpty) return kind;
    return context.t(TerminalTextKeys.projectDetail, args: {'kind': kind, 'place': place});
  }
}
