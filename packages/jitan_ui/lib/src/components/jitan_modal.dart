import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// The white rounded modal from the Figma web flows ("Add employee", …):
/// title, optional one-line subtitle, scrollable body, optional actions
/// bottom-right. Without actions it is closed by Escape or a tap outside.
///
/// Narrower than [JitanDimensions.modalWidth] on small screens.
class JitanModal extends StatelessWidget {
  const JitanModal({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.width,
    this.onClose,
    this.footerNote,
    this.leadingActions = const [],
    this.bandFooter = false,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;

  /// Fixed width (still narrower on small screens); otherwise sized to the
  /// content, up to [JitanDimensions.modalWidth].
  final double? width;

  /// Shows a "×" close button at the top right; `null` hides it.
  final VoidCallback? onClose;

  /// Text left of the actions, above which a divider separates the footer
  /// (e.g. "Changes take effect after saving.").
  final String? footerNote;

  /// Buttons at the left of the footer (e.g. "Back" in a wizard).
  final List<Widget> leadingActions;

  /// The footer as a full-width shaded band under the body (Figma wizard
  /// dialogs) instead of a row inside the padding.
  final bool bandFooter;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: JitanColors.surface,
        surfaceTintColor: JitanColors.surface,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JitanDimensions.modalRadius)),
        child: ConstrainedBox(
          constraints: width == null
              ? const BoxConstraints(maxWidth: JitanDimensions.modalWidth)
              : BoxConstraints.tightFor(width: width),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: Padding(
                  padding: bandFooter
                      ? const EdgeInsets.fromLTRB(
                          JitanDimensions.modalPadding,
                          JitanDimensions.modalPadding,
                          JitanDimensions.modalPadding,
                          24,
                        )
                      : const EdgeInsets.all(JitanDimensions.modalPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context),
                      const SizedBox(height: 32),
                      Flexible(child: SingleChildScrollView(child: body)),
                      if (!bandFooter && _hasFooter) ...[
                        SizedBox(height: footerNote == null ? 32 : 24),
                        if (footerNote != null) ...[
                          const Divider(height: 1, color: JitanColors.inputBorder),
                          const SizedBox(height: 14),
                        ],
                        _footerRow(),
                      ],
                    ],
                  ),
                ),
              ),
              if (bandFooter && _hasFooter)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(JitanDimensions.modalRadius)),
                  child: ColoredBox(
                    color: JitanColors.warmWhite,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: JitanDimensions.modalPadding, vertical: 14),
                      child: _footerRow(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  bool get _hasFooter => actions.isNotEmpty || leadingActions.isNotEmpty;

  Widget _header(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Semantics(header: true, child: Text(title, style: JitanTextStyles.modalTitle))),
              if (onClose != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20, color: JitanColors.inkMuted),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: JitanTextStyles.modalSubtitle),
          ],
        ],
      );

  Widget _footerRow() {
    // Without a note: the buttons sit left and right when they fit, and
    // stack (main action on top) on a narrow screen instead of overflowing.
    if (footerNote == null) {
      return OverflowBar(
        alignment: leadingActions.isEmpty ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
        overflowAlignment: OverflowBarAlignment.end,
        overflowDirection: VerticalDirection.up,
        spacing: 12,
        overflowSpacing: 10,
        children: [...leadingActions, ...actions],
      );
    }
    return _footerRowWithNote();
  }

  Widget _footerRowWithNote() => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < leadingActions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            leadingActions[i],
          ],
          if (footerNote != null)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: leadingActions.isEmpty ? 0 : 16, right: 16),
                child: Text(footerNote!, style: JitanTextStyles.modalSubtitle.copyWith(fontSize: 14)),
              ),
            )
          else
            const Spacer(),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            actions[i],
          ],
        ],
      );
}
