import 'package:flutter/material.dart';

import '../models/tier_task.dart';
import '../services/task_storage.dart';

void showThresholdSheet({
  required BuildContext context,
  required Map<TierCategory, int> thresholds,
  required Map<TierCategory, int> taskCounts,
  required void Function(TierCategory tier, int value) onChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: _ThresholdSheet(
          thresholds: thresholds,
          taskCounts: taskCounts,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

class _ThresholdSheet extends StatefulWidget {
  final Map<TierCategory, int> thresholds;
  final Map<TierCategory, int> taskCounts;
  final void Function(TierCategory tier, int value) onChanged;

  const _ThresholdSheet({
    required this.thresholds,
    required this.taskCounts,
    required this.onChanged,
  });

  @override
  State<_ThresholdSheet> createState() => _ThresholdSheetState();
}

class _ThresholdSheetState extends State<_ThresholdSheet> {
  late Map<TierCategory, int> _values;

  @override
  void initState() {
    super.initState();
    _values = Map.from(widget.thresholds);
  }

  int _maxFor(TierCategory tier) {
    final count = widget.taskCounts[tier] ?? 0;
    final current = _values[tier] ?? TaskStorageData.defaultThreshold;
    return [10, count, current]
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, TaskStorageData.maxThreshold);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active thresholds', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tasks ranked within the threshold are active.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final tier in TierCategory.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tier.label),
              subtitle: Text('${widget.taskCounts[tier] ?? 0} tasks'),
              trailing: PopupMenuButton<int>(
                initialValue: _values[tier] ?? TaskStorageData.defaultThreshold,
                onSelected: (val) {
                  setState(() => _values[tier] = val);
                  widget.onChanged(tier, val);
                },
                itemBuilder: (context) => [
                  for (int i = 0; i <= _maxFor(tier); i++)
                    PopupMenuItem(
                      value: i,
                      child: Text(i == 0 ? 'Off' : '$i'),
                    ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (_values[tier] ?? TaskStorageData.defaultThreshold) == 0
                          ? 'Off'
                          : '${_values[tier] ?? TaskStorageData.defaultThreshold}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
