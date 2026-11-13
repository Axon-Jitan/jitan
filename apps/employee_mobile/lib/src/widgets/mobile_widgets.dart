import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

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
    this.phone = false,
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

  /// The calm phone look (Figma `1591:170`): 13 px label, 52 px field,
  /// 15 px text. Onboarding uses it; sign-in follows when it is redrawn.
  final bool phone;

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
    final phone = widget.phone;
    final textStyle = phone ? JitanMobileTextStyles.rowText : JitanMobileTextStyles.fieldText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: phone ? JitanMobileTextStyles.label : JitanMobileTextStyles.fieldLabel),
        SizedBox(height: phone ? 8 : 6),
        SizedBox(
          height: phone ? 52 : 50,
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
            style: textStyle,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: phone ? textStyle.copyWith(color: JitanColors.inkMuted) : JitanMobileTextStyles.fieldHint,
              filled: true,
              fillColor: JitanColors.surface,
              contentPadding: EdgeInsets.symmetric(horizontal: phone ? 16 : 13, vertical: 15),
              enabledBorder: hasError
                  ? border(JitanColors.errorStrong, 1.5)
                  : border(JitanColors.inputBorder, 1),
              focusedBorder: hasError ? border(JitanColors.errorStrong, 1.5) : border(JitanColors.ink, 1),
              suffixIcon: IconButton(
                tooltip: _obscured ? widget.showLabel : widget.hideLabel,
                icon: Icon(
                  _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: phone ? 20 : 18,
                  color: JitanColors.inkMuted,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: phone ? 8 : 6),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.error!,
              style: phone
                  ? JitanMobileTextStyles.detail.copyWith(color: JitanColors.errorStrong)
                  : JitanMobileTextStyles.fieldError,
            ),
          ),
        ],
      ],
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
        Text(label, style: JitanMobileTextStyles.label),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            autofillHints: autofillHints,
            style: JitanMobileTextStyles.rowText,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: JitanMobileTextStyles.rowText.copyWith(color: JitanColors.inkMuted),
              filled: true,
              fillColor: JitanColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              enabledBorder: border(JitanColors.inputBorder),
              focusedBorder: border(JitanColors.ink),
            ),
          ),
        ),
      ],
    );
  }
}
