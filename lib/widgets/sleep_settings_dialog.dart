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
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: widget.is24Hour,
          ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final schedule = _currentSchedule;

    final bedtimeDisplay = schedule.formatTime(_startMinutes, is24Hour: widget.is24Hour);
    final wakeDisplay = schedule.formatTime(_endMinutes, is24Hour: widget.is24Hour);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bedtime_rounded,
              size: 17,
              color: Color(0xFF818CF8),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sleep Schedule & Focus',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              // Focus Mode Toggle (Shortens calendar scroll)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
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
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cut out empty sleep hours to focus on work and minimize scroll area.',
                            style: TextStyle(
                              fontSize: 10.0,
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
              const SizedBox(height: 12),

              // Bedtime and Wake time selector
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bedtime (Start)',
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.nightlight_outlined, size: 14),
                          label: Text(bedtimeDisplay, style: const TextStyle(fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                          onPressed: () => _pickTime(isBedtime: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wake Time (End)',
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.wb_sunny_outlined, size: 14),
                          label: Text(wakeDisplay, style: const TextStyle(fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                          onPressed: () => _pickTime(isBedtime: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Sleep Duration Analysis Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.40 : 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'SLEEP ANALYSIS',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${schedule.durationHours.toStringAsFixed(1)}h / night',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Daily Sleep',
                            value: '${schedule.durationHours.toStringAsFixed(1)}h',
                            sublabel: 'per night',
                            color: const Color(0xFF818CF8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Weekly Sleep',
                            value: '${schedule.weeklySleepHours.toStringAsFixed(1)}h',
                            sublabel: '${schedule.sleepPercentOfTotal}% of week',
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Waking Focus',
                            value: '${schedule.dailyAwakeHours.toStringAsFixed(1)}h',
                            sublabel: '${schedule.awakePercentOfTotal}% active',
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Sleep vs Awake Ratio Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
                        child: Row(
                          children: [
                            Expanded(
                              flex: schedule.durationMinutes,
                              child: Container(color: const Color(0xFF6366F1)),
                            ),
                            Expanded(
                              flex: (1440 - schedule.durationMinutes).clamp(1, 1440),
                              child: Container(color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, color: const Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            Text(
                              'Sleep: ${schedule.sleepPercentOfTotal}% (${schedule.weeklySleepHours.toStringAsFixed(1)}h/wk)',
                              style: TextStyle(
                                fontSize: 9.0,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Awake: ${schedule.awakePercentOfTotal}% (${schedule.weeklyAwakeHours.toStringAsFixed(1)}h/wk)',
                              style: TextStyle(
                                fontSize: 9.0,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Health Insight Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: schedule.healthColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.health_and_safety_outlined, size: 13, color: schedule.healthColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              schedule.healthInsight,
                              style: TextStyle(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w600,
                                color: schedule.healthColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Calendar Block Preview
              const Text(
                'Calendar Block Appearance',
                style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                        : [const Color(0xFF1E293B), const Color(0xFF312E81)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                    width: 1.0,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Row(
                    children: [
                      Container(width: 4.5, color: const Color(0xFF818CF8)),
                      const SizedBox(width: 8),
                      const Icon(Icons.nightlight_round, size: 14, color: Color(0xFFA5B4FC)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sleep Block',
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE0E7FF),
                              ),
                            ),
                            Text(
                              schedule.formatRange(is24Hour: widget.is24Hour),
                              style: const TextStyle(
                                fontSize: 9.0,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF312E81).withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '${schedule.durationHours.toStringAsFixed(1)}h',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC7D2FE),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
          child: const Text('Save Settings'),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sublabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 9.0,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
