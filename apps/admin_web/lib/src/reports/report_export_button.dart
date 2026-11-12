import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// "Export ⌄" (Figma `HR / Reports V2 — export` `1572:2`): Excel or CSV
/// from a white menu that ends at the button's right edge. Off while there
/// is nothing to export.
class ReportExportButton extends StatefulWidget {
  const ReportExportButton({super.key, required this.onExcel, required this.onCsv, required this.enabled});

  final VoidCallback onExcel;
  final VoidCallback onCsv;
  final bool enabled;

  @override
  State<ReportExportButton> createState() => _ReportExportButtonState();
}

class _ReportExportButtonState extends State<ReportExportButton> {
  final _menu = MenuController();
  final _anchor = GlobalKey();
  Offset _offset = const Offset(0, 6);

  static const _menuWidth = 200.0;
  static const _inset = 6.0;

  void _toggle() {
    if (_menu.isOpen) return _menu.close();
    final width = (_anchor.currentContext?.findRenderObject() as RenderBox?)?.size.width ?? _menuWidth;
    setState(() => _offset = Offset(width - _menuWidth, 6));
    _menu.open();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    alignmentOffset: _offset,
    style: jitanMenuStyle(_menuWidth),
    menuChildren: [
      JitanMenuItem(label: context.t(AdminTextKeys.reportExportExcel), width: _menuWidth - _inset * 2, onPressed: widget.onExcel),
      JitanMenuItem(label: context.t(AdminTextKeys.reportExportCsv), width: _menuWidth - _inset * 2, onPressed: widget.onCsv),
    ],
    builder: (context, menu, _) => JitanPrimaryButton(
      key: _anchor,
      label: context.t(AdminTextKeys.reportExport),
      trailingIcon: Icons.keyboard_arrow_down_rounded,
      onPressed: widget.enabled ? _toggle : null,
    ),
  );
}
