import 'package:flutter/material.dart';

import '../time_records/time_record_card.dart';

// The layout both Reports views share (Figma `1571:2`, `1571:390`).

/// The period and Export, at the top right; on a phone one line under the
/// title, the period taking the room.
Widget reportHeaderActions(Widget period, Widget export, {required bool phone}) => phone
    ? Row(spacing: 10, children: [Expanded(child: period), export])
    : Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [period, export]);

/// Employees | Projects, then the search and any [filters]; one under the
/// other on a phone.
Widget reportToolbar({required bool phone, required Widget viewSwitch, required Widget search, List<Widget> filters = const []}) =>
    phone
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [Align(alignment: Alignment.centerLeft, child: viewSwitch), search, ...filters],
          )
        : Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [viewSwitch, SizedBox(width: 320, child: search), ...filters],
          );

/// The quiet ⓘ line under a report's table: how many, and what the numbers
/// mean.
Widget reportNote(List<String> parts) => SliverToBoxAdapter(
  child: Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 0), child: TimeRecordNote(parts.join(' · '))),
);
