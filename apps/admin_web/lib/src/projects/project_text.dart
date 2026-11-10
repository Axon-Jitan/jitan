import 'package:flutter/widgets.dart';
import 'package:jitan_ui/jitan_ui.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';
import '../terminals/terminal_text.dart';

/// The words of the Projects page (Figma `1512:2`).
abstract final class ProjectText {
  /// "Client site · Mouscron", "Our workshop · Almeco".
  static String place(BuildContext context, ProjectSummary project) {
    final place = project.placeName;
    if (place == null || place.isEmpty) {
      return context.t(project.isClientSite ? AdminTextKeys.projectPlaceClientOnly : AdminTextKeys.projectPlaceWorkshopOnly);
    }
    return context.t(
      project.isClientSite ? AdminTextKeys.projectPlaceClient : AdminTextKeys.projectPlaceWorkshop,
      args: {'place': place},
    );
  }

  /// "Today", "Yesterday, 16:42", "3 November, 09:12", "—": said like the
  /// Terminals page says it.
  static String lastUsed(BuildContext context, DateTime? used, DateTime now) =>
      used == null ? context.t(AdminTextKeys.projectNeverUsed) : TerminalText.lastSeen(context, used, now);
}
