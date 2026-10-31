import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// "Travel counts as work" on the group page (Figma `1455:2`, D39): one
/// switch, saved at once. Not there on a database without the proposed tables.
class GroupTravelRow extends StatefulWidget {
  const GroupTravelRow({super.key, required this.api, required this.groupId, required this.enabled});

  final GroupManagementApi api;
  final int groupId;

  /// `false` while the group is inactive.
  final bool enabled;

  @override
  State<GroupTravelRow> createState() => _GroupTravelRowState();
}

class _GroupTravelRowState extends State<GroupTravelRow> {
  bool? _value;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final travel = await widget.api.travel(widget.groupId);
      if (mounted && travel.available) setState(() => _value = travel.travelIsWork);
    } on ApiClientException {
      // The switch stays away; the rest of the page works.
    }
  }

  Future<void> _change(bool value) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final saved = await widget.api.setTravel(widget.groupId, travelIsWork: value);
      if (mounted) setState(() => _value = saved.travelIsWork);
    } on ApiClientException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.t(AdminTextKeys.groupTravelRow),
                style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
              ),
            ),
            Transform.scale(
              scale: 0.7,
              alignment: Alignment.centerRight,
              child: Switch(
                value: value,
                activeThumbColor: JitanColors.surface,
                activeTrackColor: JitanColors.ink,
                inactiveTrackColor: JitanColors.inputBorder,
                inactiveThumbColor: JitanColors.surface,
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                onChanged: widget.enabled && !_busy ? _change : null,
              ),
            ),
          ],
        ),
        if (_failed) Text(context.t(AdminTextKeys.groupTravelFailed), style: JitanTextStyles.fieldError),
      ],
    );
  }
}
