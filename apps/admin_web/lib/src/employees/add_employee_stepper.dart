import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// Add employee's progress (Figma `153:970`): a numbered circle per step,
/// dark for the current one, with its name beside it (bold when current).
/// On a narrow screen the names wrap under each other.
class AddEmployeeStepper extends StatelessWidget {
  const AddEmployeeStepper({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 24,
    runSpacing: 10,
    children: [
      for (final (index, label) in labels.indexed)
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == current ? JitanColors.ink : JitanColors.inputFill,
                ),
                child: Text(
                  '${index + 1}',
                  style: JitanTextStyles.tableCell.copyWith(
                    fontSize: 13,
                    color: index == current ? JitanColors.surface : JitanColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: index == current
                      ? JitanTextStyles.tableCellStrong.copyWith(fontSize: 13)
                      : JitanTextStyles.stateMessage.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
