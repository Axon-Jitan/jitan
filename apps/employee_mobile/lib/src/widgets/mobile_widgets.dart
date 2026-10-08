import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// Layout shared by the onboarding screens (390 × 844 Figma frames):
/// 24 px side margins, optional "jitan." logo, scrollable content, and the
/// actions pinned to the bottom.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.children,
    required this.actions,
    this.showLogo = true,
    this.logoStyle,
  });

  final List<Widget> children;
  final List<Widget> actions;
  final bool showLogo;
  final TextStyle? logoStyle;

  /// Horizontal margin of every onboarding screen.
  static const margin = 24.0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: JitanColors.warmWhite,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(margin, 10, margin, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showLogo) JitanWordmark(style: logoStyle),
                    ...children,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...actions,
          ],
        ),
      ),
    ),
  );
}

/// The "jitan." wordmark. A brand name: never translated.
class JitanWordmark extends StatelessWidget {
  const JitanWordmark({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: Text('jitan.', style: style ?? JitanMobileTextStyles.logo));
}

/// A Figma illustration: 210 px high, radius 22, image scaled and offset the
/// way the Figma frame crops it.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({
    super.key,
    required this.asset,
    required this.widthFactor,
    required this.heightFactor,
    required this.left,
    required this.top,
  });

  /// `assets/illustrations/<name>.png` in this app.
  final String asset;

  /// Image size relative to the frame, and its offset (fractions of the
  /// frame, negative = outside), copied from Figma.
  final double widthFactor;
  final double heightFactor;
  final double left;
  final double top;

  static const height = 210.0;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: left * w,
                  top: top * height,
                  width: widthFactor * w,
                  height: heightFactor * height,
                  child: Image.asset(asset, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// A selectable card with a radio indicator (Figma "Method / …").
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.text,
    this.minHeight = 142,
  });

  final String title;
  final String? text;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    button: true,
    child: Material(
      color: JitanColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: selected
            ? const BorderSide(color: JitanColors.vermilion, width: 2)
            : const BorderSide(color: JitanColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 17, 24, 17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioDot(selected: selected),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: JitanMobileTextStyles.cardTitle),
                      if (text != null) ...[
                        const SizedBox(height: 12),
                        Text(text!, style: JitanMobileTextStyles.cardText),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The 24 px radio circle of a [ChoiceCard].
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? JitanColors.vermilion : JitanColors.surface,
      border: Border.all(color: selected ? JitanColors.vermilion : JitanColors.radioBorder, width: 2),
    ),
    child: selected
        ? Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: JitanColors.surface),
          )
        : null,
  );
}

/// A rounded note: optional bold title and a paragraph.
class NoteBox extends StatelessWidget {
  const NoteBox({
    super.key,
    required this.text,
    this.title,
    this.background = JitanColors.inputFill,
    this.foreground,
    this.titleForeground,
    this.border,
    this.titleStyle,
    this.textStyle,
    this.radius = 16,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 28, 18),
    this.minHeight = 0,
  });

  final String? title;
  final String text;
  final Color background;

  /// Colour of title and text (error, warning and info notes); `null` keeps
  /// the styles' own colours.
  final Color? foreground;

  /// Colour of the title only, when it differs from [foreground].
  final Color? titleForeground;

  /// Outline, e.g. Figma 03B "Secure connection confirmed"; none by default.
  final Color? border;
  final TextStyle? titleStyle;
  final TextStyle? textStyle;
  final double radius;
  final EdgeInsets padding;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final titleText = (titleStyle ?? JitanMobileTextStyles.noteTitle).copyWith(color: titleForeground ?? foreground);
    final bodyText = (textStyle ?? JitanMobileTextStyles.noteText).copyWith(color: foreground);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[Text(title!, style: titleText), const SizedBox(height: 10)],
          Text(text, style: bodyText),
        ],
      ),
    );
  }
}

/// The 82 px circle with a glyph on error screens.
class StatusCircle extends StatelessWidget {
  const StatusCircle({super.key, required this.background, required this.foreground, required this.icon});

  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: Icon(icon, size: 40, color: foreground),
    ),
  );
}

/// A password field (Figma "Field / Password"): white, 50 px, radius 14,
/// with a show/hide toggle. A red outline and message mark [error].
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.showLabel,
    required this.hideLabel,
    this.error,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String showLabel;
  final String hideLabel;
  final String? error;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: JitanMobileTextStyles.fieldLabel),
        const SizedBox(height: 6),
        SizedBox(
          height: 50,
          child: TextField(
            controller: widget.controller,
            obscureText: _obscured,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            autofillHints: widget.autofillHints,
            style: JitanMobileTextStyles.fieldText,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: JitanMobileTextStyles.fieldHint,
              filled: true,
              fillColor: JitanColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
              enabledBorder: hasError
                  ? border(JitanColors.errorStrong, 1.5)
                  : border(JitanColors.inputBorder, 1),
              focusedBorder: hasError ? border(JitanColors.errorStrong, 1.5) : border(JitanColors.ink, 1),
              suffixIcon: IconButton(
                tooltip: _obscured ? widget.showLabel : widget.hideLabel,
                icon: Icon(
                  _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: JitanColors.inkMuted,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Semantics(liveRegion: true, child: Text(widget.error!, style: JitanMobileTextStyles.fieldError)),
        ],
      ],
    );
  }
}

/// Tone of a [StatusPage]: the colours of its circle and help note.
enum StatusTone { error, warning, info }

/// One button on a [StatusPage].
class StatusAction {
  const StatusAction({required this.label, required this.onPressed, this.primary = false, this.busy = false});

  final String label;
  final VoidCallback? onPressed;

  /// Vermilion main action; otherwise the warm-grey secondary style.
  final bool primary;
  final bool busy;
}

/// Full-screen state with a title, an 82 px status circle, a coloured help
/// note and actions (Figma "Onboarding Error / …", "Auth / 03–05").
class StatusPage extends StatelessWidget {
  const StatusPage({
    super.key,
    required this.title,
    required this.text,
    required this.tone,
    required this.helpTitle,
    required this.help,
    required this.actions,
    this.showLogo = false,
    this.buttonSize = JitanMobileButtonSize.compact,
    this.footer = const [],
    this.inkHelpTitle = false,
  });

  final String title;
  final String text;
  final StatusTone tone;
  final String helpTitle;
  final String help;
  final List<StatusAction> actions;
  final bool showLogo;
  final JitanMobileButtonSize buttonSize;

  /// Shown after the actions, e.g. an instruction that is not an action.
  final List<Widget> footer;

  /// The help title in ink instead of the tone's colour (Figma "Onboarding
  /// Error / 03", "Auth / 04": "Contact HR/Admin").
  final bool inkHelpTitle;

  @override
  Widget build(BuildContext context) {
    final (surface, strong, icon) = switch (tone) {
      StatusTone.error => (JitanColors.errorSurface, JitanColors.errorStrong, Icons.priority_high_rounded),
      StatusTone.warning => (JitanColors.warningSurface, JitanColors.warning, Icons.priority_high_rounded),
      StatusTone.info => (JitanColors.infoSurface, JitanColors.info, Icons.refresh_rounded),
    };
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(OnboardingPage.margin, showLogo ? 0 : 14, OnboardingPage.margin, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLogo) ...[
                const JitanWordmark(),
                const SizedBox(height: 28),
              ],
              Semantics(
                header: true,
                child: Text(title, style: showLogo ? JitanMobileTextStyles.formTitle : JitanMobileTextStyles.errorTitle),
              ),
              const SizedBox(height: 10),
              Text(text, style: JitanMobileTextStyles.caption),
              SizedBox(height: showLogo ? 58 : 92),
              Center(child: StatusCircle(background: surface, foreground: strong, icon: icon)),
              const SizedBox(height: 28),
              Semantics(
                liveRegion: true,
                child: NoteBox(
                  title: helpTitle,
                  text: help,
                  background: surface,
                  foreground: strong,
                  titleForeground: inkHelpTitle ? JitanColors.ink : null,
                  radius: 18,
                  minHeight: showLogo ? 116 : 120,
                ),
              ),
              const SizedBox(height: 34),
              for (final (i, action) in actions.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                JitanMobileButton(
                  label: action.label,
                  style: action.primary ? JitanMobileButtonStyle.brand : JitanMobileButtonStyle.secondary,
                  size: buttonSize,
                  busy: action.busy,
                  onPressed: action.onPressed,
                ),
              ],
              if (footer.isNotEmpty) ...[const SizedBox(height: 12), ...footer],
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled text field in the mobile form style (Figma "Field / Employee
/// code"): white, 50 px, radius 14.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: JitanMobileTextStyles.fieldLabel),
        const SizedBox(height: 6),
        SizedBox(
          height: 50,
          child: TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            autofillHints: autofillHints,
            style: JitanMobileTextStyles.fieldText,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: JitanMobileTextStyles.fieldHint,
              filled: true,
              fillColor: JitanColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
              enabledBorder: border(JitanColors.inputBorder),
              focusedBorder: border(JitanColors.ink),
            ),
          ),
        ),
      ],
    );
  }
}
