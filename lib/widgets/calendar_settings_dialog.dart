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
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Time Format
              const Text(
                'Time Format',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('12-Hour (AM/PM)'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('24-Hour'),
                  ),
                ],
                selected: {_is24Hour},
                onSelectionChanged: (newSel) {
                  setState(() => _is24Hour = newSel.first);
                },
              ),
              const SizedBox(height: 18),

              // 2. Loop Target Percentages
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Loop Target Ratios',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total: $targetsTotal%',
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
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'S-Tier %',
                        labelStyle: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        suffixText: '%',
                      ),
                      onChanged: (v) {
                        setState(() {
                          _targetS = int.tryParse(v.trim()) ?? 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _aController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'A-Tier %',
                        labelStyle: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        suffixText: '%',
                      ),
                      onChanged: (v) {
                        setState(() {
                          _targetA = int.tryParse(v.trim()) ?? 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _bController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'B-Tier %',
                        labelStyle: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        suffixText: '%',
                      ),
                      onChanged: (v) {
                        setState(() {
                          _targetB = int.tryParse(v.trim()) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Sleep Schedule & Focus
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Focus & Sleep Hours',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Focus mode (hide sleeping hours)'),
                subtitle: const Text('Cuts out empty midnight hours to shorten scroll'),
                value: _isFocusEnabled,
                onChanged: (val) => setState(() => _isFocusEnabled = val),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.nightlight_outlined, size: 15),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Bed: $bedtimeDisplay', style: const TextStyle(fontSize: 11.5)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      ),
                      onPressed: () => _pickTime(isBedtime: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.wb_sunny_outlined, size: 15),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Wake: $wakeDisplay', style: const TextStyle(fontSize: 11.5)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      ),
                      onPressed: () => _pickTime(isBedtime: false),
                    ),
                  ),
                ],
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
