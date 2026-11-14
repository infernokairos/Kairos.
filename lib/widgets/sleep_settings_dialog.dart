import 'package:flutter/material.dart';

import '../models/sleep_schedule.dart';

void showSleepSettingsDialog({
  required BuildContext context,
  required SleepSchedule currentSchedule,
  required bool is24Hour,
  required ValueChanged<SleepSchedule> onSave,
}) {
  showDialog(
    context: context,
    builder: (context) => _SleepSettingsDialog(
      initialSchedule: currentSchedule,
      is24Hour: is24Hour,
      onSave: onSave,
    ),
  );
}

class _SleepSettingsDialog extends StatefulWidget {
  final SleepSchedule initialSchedule;
  final bool is24Hour;
  final ValueChanged<SleepSchedule> onSave;

  const _SleepSettingsDialog({
    required this.initialSchedule,
    required this.is24Hour,
    required this.onSave,
  });

  @override
  State<_SleepSettingsDialog> createState() => _SleepSettingsDialogState();
}

class _SleepSettingsDialogState extends State<_SleepSettingsDialog> {
  late int _startMinutes;
  late int _endMinutes;
  late bool _isFocusEnabled;

  @override
  void initState() {
    super.initState();
    _startMinutes = widget.initialSchedule.startMinutes;
    _endMinutes = widget.initialSchedule.endMinutes;
    _isFocusEnabled = widget.initialSchedule.isFocusEnabled;
  }

  SleepSchedule get _currentSchedule => SleepSchedule(
    startMinutes: _startMinutes,
    endMinutes: _endMinutes,
    isFocusEnabled: _isFocusEnabled,
  );

  Future<void> _pickTime({required bool isBedtime}) async {
    final initialMin = isBedtime ? _startMinutes : _endMinutes;
    final initialTime = TimeOfDay(
      hour: initialMin ~/ 60,
      minute: initialMin % 60,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: widget.is24Hour),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final totalMin = picked.hour * 60 + picked.minute;
        if (isBedtime) {
          _startMinutes = totalMin;
        } else {
          _endMinutes = totalMin;
        }
      });
    }
  }

  Widget _buildStatPill({
    required ThemeData theme,
    required String label,
    required Color color,
    required String hours,
    required String pct,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  Text(
                    hours,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    pct,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
    final schedule = _currentSchedule;

    final bedtimeDisplay = schedule.formatTime(
      _startMinutes,
      is24Hour: widget.is24Hour,
    );
    final wakeDisplay = schedule.formatTime(
      _endMinutes,
      is24Hour: widget.is24Hour,
    );

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bedtime_outlined, size: 20, color: Color(0xFF818CF8)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sleep Schedule & Focus',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Focus Mode Switch Tile
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.25,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Focus Mode (Shorten Scroll)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hide empty sleep hours to focus on work',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isFocusEnabled,
                      onChanged: (val) => setState(() => _isFocusEnabled = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Bedtime and Wake Up Selectors
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(isBedtime: true),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.nightlight_outlined,
                              size: 18,
                              color: Color(0xFF818CF8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bedtime',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    bedtimeDisplay,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(isBedtime: false),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wb_sunny_outlined,
                              size: 18,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Wake up',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    wakeDisplay,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Material 3 Sleep Analysis Card (Zero Bloat, Single-Source Metrics)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.25,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sleep Analysis',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            schedule.healthInsight,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: schedule.healthColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Material 3 Dual-Color Ratio Track
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: Row(
                          children: [
                            Expanded(
                              flex: schedule.durationMinutes,
                              child: Container(color: const Color(0xFF818CF8)),
                            ),
                            Expanded(
                              flex: (1440 - schedule.durationMinutes).clamp(
                                1,
                                1440,
                              ),
                              child: Container(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Stat Badges
                    Row(
                      children: [
                        _buildStatPill(
                          theme: theme,
                          label: 'Sleep',
                          color: const Color(0xFF818CF8),
                          hours:
                              '${schedule.durationHours.toStringAsFixed(1)}h',
                          pct: '${schedule.sleepPercentOfTotal}%',
                        ),
                        const SizedBox(width: 8),
                        _buildStatPill(
                          theme: theme,
                          label: 'Focus',
                          color: theme.colorScheme.primary,
                          hours:
                              '${schedule.dailyAwakeHours.toStringAsFixed(1)}h',
                          pct: '${schedule.awakePercentOfTotal}%',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onSave(_currentSchedule);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
