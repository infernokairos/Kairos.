import 'package:flutter/material.dart';

import '../models/schedule_slot.dart';
import '../models/sleep_schedule.dart';
import '../models/week_targets.dart';

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
  showDialog(
    context: context,
    builder: (context) => _CalendarSettingsDialog(
      initialIs24Hour: is24Hour,
      initialSleepSchedule: sleepSchedule,
      initialWeekTargets: weekTargets,
      onSave: onSave,
    ),
  );
}

class _CalendarSettingsDialog extends StatefulWidget {
  final bool initialIs24Hour;
  final SleepSchedule initialSleepSchedule;
  final WeekTargets initialWeekTargets;
  final void Function({
    required bool is24Hour,
    required SleepSchedule sleepSchedule,
    required WeekTargets weekTargets,
  }) onSave;

  const _CalendarSettingsDialog({
    required this.initialIs24Hour,
    required this.initialSleepSchedule,
    required this.initialWeekTargets,
    required this.onSave,
  });

  @override
  State<_CalendarSettingsDialog> createState() => _CalendarSettingsDialogState();
}

class _CalendarSettingsDialogState extends State<_CalendarSettingsDialog> {
  late bool _is24Hour;
  late int _startMinutes;
  late int _endMinutes;
  late bool _isFocusEnabled;
  late int _targetS;
  late int _targetA;
  late int _targetB;

  late final TextEditingController _sController;
  late final TextEditingController _aController;
  late final TextEditingController _bController;

  @override
  void initState() {
    super.initState();
    _is24Hour = widget.initialIs24Hour;
    _startMinutes = widget.initialSleepSchedule.startMinutes;
    _endMinutes = widget.initialSleepSchedule.endMinutes;
    _isFocusEnabled = widget.initialSleepSchedule.isFocusEnabled;
    _targetS = widget.initialWeekTargets.sPct;
    _targetA = widget.initialWeekTargets.aPct;
    _targetB = widget.initialWeekTargets.bPct;

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

  SleepSchedule get _currentSleepSchedule => SleepSchedule(
        startMinutes: _startMinutes,
        endMinutes: _endMinutes,
        isFocusEnabled: _isFocusEnabled,
      );

  WeekTargets get _currentTargets => WeekTargets(
        sPct: _targetS,
        aPct: _targetA,
        bPct: _targetB,
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
            alwaysUse24HourFormat: _is24Hour,
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

  Widget _buildRatioField({
    required String letter,
    required Color badgeColor,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
    final schedule = _currentSleepSchedule;
    final targetsTotal = _targetS + _targetA + _targetB;
    final isTotalValid = targetsTotal == 100;

    final bedtimeDisplay = ScheduleSlot.formatMinutes(_startMinutes, is24Hour: _is24Hour);
    final wakeDisplay = ScheduleSlot.formatMinutes(_endMinutes, is24Hour: _is24Hour);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.tune, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Calendar Settings',
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
              // 1. Time Format (Clean, full-width segmented pill)
              const Text(
                'Time Format',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('12-Hour (AM/PM)', style: TextStyle(fontSize: 11.5)),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('24-Hour', style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                  selected: {_is24Hour},
                  onSelectionChanged: (newSel) {
                    setState(() => _is24Hour = newSel.first);
                  },
                ),
              ),
              const SizedBox(height: 18),

              // 2. Loop Target Percentages (Zero repetition, clean unified inputs)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Loop Target Ratios',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTotalValid ? 'Total: 100%' : 'Total: $targetsTotal% (needs 100%)',
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
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildRatioField(
                    letter: 'S',
                    badgeColor: const Color(0xFF1976D2),
                    controller: _sController,
                    onChanged: (v) {
                      setState(() => _targetS = int.tryParse(v.trim()) ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildRatioField(
                    letter: 'A',
                    badgeColor: const Color(0xFF2E7D32),
                    controller: _aController,
                    onChanged: (v) {
                      setState(() => _targetA = int.tryParse(v.trim()) ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildRatioField(
                    letter: 'B',
                    badgeColor: const Color(0xFFD97706),
                    controller: _bController,
                    onChanged: (v) {
                      setState(() => _targetB = int.tryParse(v.trim()) ?? 0);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Sleep & Focus Hours (Zero bloat, zero repetition)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Focus & Sleep Hours',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sleep: ${schedule.durationHours.toStringAsFixed(1)}h/day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Focus mode (hide sleeping hours)',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _isFocusEnabled,
                            onChanged: (val) => setState(() => _isFocusEnabled = val),
                          ),
                        ),
                      ],
                    ),
                    if (_isFocusEnabled) ...[
                      Divider(height: 12, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickTime(isBedtime: true),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.nightlight_outlined, size: 16, color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bedtime',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          bedtimeDisplay,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 26,
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickTime(isBedtime: false),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.wb_sunny_outlined, size: 16, color: Color(0xFFD97706)),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Wake up',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          wakeDisplay,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
          onPressed: isTotalValid
              ? () {
                  Navigator.pop(context);
                  widget.onSave(
                    is24Hour: _is24Hour,
                    sleepSchedule: _currentSleepSchedule,
                    weekTargets: _currentTargets,
                  );
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
