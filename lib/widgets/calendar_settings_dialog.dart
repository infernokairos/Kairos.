import 'package:flutter/material.dart';

import '../models/sleep_schedule.dart';
import '../models/tier_task.dart';
import '../models/week_targets.dart';

void showTargetRatiosDialog({
  required BuildContext context,
  required WeekTargets weekTargets,
  required ValueChanged<WeekTargets> onSave,
}) {
  showDialog(
    context: context,
    builder: (context) => _TargetRatiosDialog(
      initialTargets: weekTargets,
      onSave: onSave,
    ),
  );
}

/// Backwards-compatible wrapper
void showCalendarSettingsDialog({
  required BuildContext context,
  required bool is24Hour,
  required SleepSchedule sleepSchedule,
  required WeekTargets weekTargets,
  required void Function({
    required bool is24Hour,
    required SleepSchedule sleepSchedule,
    required WeekTargets weekTargets,
  }) onSave,
}) {
  showTargetRatiosDialog(
    context: context,
    weekTargets: weekTargets,
    onSave: (newTargets) {
      onSave(
        is24Hour: is24Hour,
        sleepSchedule: sleepSchedule,
        weekTargets: newTargets,
      );
    },
  );
}

class _TargetRatiosDialog extends StatefulWidget {
  final WeekTargets initialTargets;
  final ValueChanged<WeekTargets> onSave;

  const _TargetRatiosDialog({
    required this.initialTargets,
    required this.onSave,
  });

  @override
  State<_TargetRatiosDialog> createState() => _TargetRatiosDialogState();
}

class _TargetRatiosDialogState extends State<_TargetRatiosDialog> {
  late int _targetS;
  late int _targetA;
  late int _targetB;

  late final TextEditingController _sController;
  late final TextEditingController _aController;
  late final TextEditingController _bController;

  @override
  void initState() {
    super.initState();
    _targetS = widget.initialTargets.sPct;
    _targetA = widget.initialTargets.aPct;
    _targetB = widget.initialTargets.bPct;

    _sController = TextEditingController(text: '$_targetS');
    _aController = TextEditingController(text: '$_targetA');
    _bController = TextEditingController(text: '$_targetB');
  }

  @override
  void dispose() {
    _sController.dispose();
    _aController.dispose();
    _bController.dispose();
    super.dispose();
  }

  Widget _buildRatioTile({
    required String letter,
    required Color badgeColor,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 32,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onChanged,
              ),
            ),
            Text(
              '%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetsTotal = _targetS + _targetA + _targetB;
    final isTotalValid = targetsTotal == 100;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.tune, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Loop Target Ratios',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tier Percentages',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  isTotalValid ? 'Total: 100%' : '$targetsTotal% (need 100%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isTotalValid
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildRatioTile(
                  letter: 'S',
                  badgeColor: TierCategory.s.color,
                  controller: _sController,
                  onChanged: (v) {
                    setState(() => _targetS = int.tryParse(v.trim()) ?? 0);
                  },
                ),
                const SizedBox(width: 8),
                _buildRatioTile(
                  letter: 'A',
                  badgeColor: TierCategory.a.color,
                  controller: _aController,
                  onChanged: (v) {
                    setState(() => _targetA = int.tryParse(v.trim()) ?? 0);
                  },
                ),
                const SizedBox(width: 8),
                _buildRatioTile(
                  letter: 'B',
                  badgeColor: TierCategory.b.color,
                  controller: _bController,
                  onChanged: (v) {
                    setState(() => _targetB = int.tryParse(v.trim()) ?? 0);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isTotalValid
              ? () {
                  Navigator.pop(context);
                  widget.onSave(WeekTargets(
                    sPct: _targetS,
                    aPct: _targetA,
                    bPct: _targetB,
                  ));
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
