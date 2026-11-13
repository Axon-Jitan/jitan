import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

// The building blocks of the calm phone pages (Figma `1585:2`, `1588:2`,
// 2026-11-12): a white grouped list, a quiet link and a red note.

/// A white rounded card holding rows, with a thin line between them, as in
/// iOS Settings.
class PhoneListCard extends StatelessWidget {
  const PhoneListCard({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 18)});

  final List<Widget> children;

  /// Around the rows; a row that reacts to taps fills the width itself.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: JitanColors.surface,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: JitanColors.inputBorder),
            child,
          ],
        ],
      ),
    ),
  );
}

/// A row of a [PhoneListCard] that reacts to a tap: a title, an optional
/// detail under it, and a trailing widget (a checkmark, a chevron, "Now").
class PhoneListRow extends StatelessWidget {
  const PhoneListRow({super.key, required this.title, this.detail, this.trailing, this.onTap, this.titleStyle, this.selected = false});

  final String title;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;

  /// Read out as selected (a checked choice).
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle ?? JitanMobileTextStyles.rowTitle),
                    if (detail case final detail?) ...[const SizedBox(height: 2), Text(detail, style: JitanMobileTextStyles.detail)],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    ),
  );
}

/// The checkmark of a chosen row.
class PhoneCheck extends StatelessWidget {
  const PhoneCheck({super.key});

  @override
  Widget build(BuildContext context) => const Icon(Icons.check, size: 20, color: JitanColors.ink);
}

/// The chevron of a row that opens something.
class PhoneChevron extends StatelessWidget {
  const PhoneChevron({super.key});

  @override
  Widget build(BuildContext context) => const Icon(Icons.chevron_right, size: 20, color: JitanColors.inkMuted);
}

/// The quiet link under a page's main button ("Finished earlier? Enter the
/// time"), 44 px tall so it is easy to tap.
class PhoneQuietLink extends StatelessWidget {
  const PhoneQuietLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: JitanColors.inkMuted,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    child: Text(label, textAlign: TextAlign.center, style: JitanMobileTextStyles.quietLink),
  );
}

/// One quiet line for a milder problem: "Couldn't refresh · Try again"
/// (Figma `1602:2`). What is shown stays; the action tries again.
class PhoneRetryLine extends StatelessWidget {
  const PhoneRetryLine({super.key, required this.message, required this.action, required this.onPressed});

  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      children: [
        Flexible(
          child: Text('$message ·', maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanMobileTextStyles.detail),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: JitanColors.ink,
            minimumSize: const Size(44, 36),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(
            action,
            style: JitanMobileTextStyles.detail.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// A red note above the main button: something wasn't saved.
class PhoneErrorNote extends StatelessWidget {
  const PhoneErrorNote({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: JitanColors.errorSurface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(title, style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 14, color: JitanColors.errorStrong)),
          Text(message, style: JitanMobileTextStyles.detail.copyWith(color: JitanColors.ink)),
        ],
      ),
    ),
  );
}

/// The top bar of a page opened from another: only a back chevron.
PreferredSizeWidget phoneAppBar(BuildContext context) => AppBar(
  backgroundColor: JitanColors.warmWhite,
  elevation: 0,
  scrolledUnderElevation: 0,
  automaticallyImplyLeading: false,
  leading: IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    icon: const Icon(Icons.chevron_left, size: 30, color: JitanColors.ink),
    onPressed: () => Navigator.of(context).maybePop(),
  ),
);
