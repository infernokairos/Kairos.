import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/schedule_slot.dart';
import '../models/sleep_schedule.dart';
import '../models/tier_task.dart';
import '../models/week_targets.dart';
import '../widgets/calendar_settings_dialog.dart';

class WeekScheduleScreen extends StatefulWidget {
  final List<ScheduleSlot> initialSchedule;
  final bool is24Hour;
  final SleepSchedule sleepSchedule;
  final WeekTargets weekTargets;
  final void Function(List<ScheduleSlot> newSchedule) onSave;
  final ValueChanged<bool>? onToggleTimeFormat;
  final ValueChanged<SleepSchedule>? onUpdateSleepSchedule;
  final ValueChanged<WeekTargets>? onUpdateWeekTargets;

  const WeekScheduleScreen({
    super.key,
    required this.initialSchedule,
    this.is24Hour = false,
    this.sleepSchedule = const SleepSchedule(),
    this.weekTargets = const WeekTargets(),
    required this.onSave,
    this.onToggleTimeFormat,
    this.onUpdateSleepSchedule,
    this.onUpdateWeekTargets,
  });

  @override
  State<WeekScheduleScreen> createState() => _WeekScheduleScreenState();
}

class _WeekScheduleScreenState extends State<WeekScheduleScreen> {
  late List<ScheduleSlot> _slots;
  late bool _is24Hour;
  late SleepSchedule _sleepSchedule;
  late WeekTargets _weekTargets;

  final List<List<ScheduleSlot>> _undoStack = [];
  final List<List<ScheduleSlot>> _redoStack = [];

  late final ScrollController _verticalController;
  late final ScrollController _headerHorizontalController;
  late final ScrollController _gridHorizontalController;

  static const double _hourHeight = 52.0;
  static const double _timeGutterWidth = 56.0;
  static const double _topPadding = 18.0;
  static const double _bottomPadding = 24.0;

  // Sunday is starting day: 7 = Sun, 1 = Mon .. 6 = Sat
  static const List<int> _weekDayOrder = [7, 1, 2, 3, 4, 5, 6];

  static const Map<int, String> _dayNames = {
    7: 'Sun',
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
  };

  static const Map<int, String> _dayFullNames = {
    7: 'Sunday',
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
  };

  @override
  void initState() {
    super.initState();
    _slots = List.from(widget.initialSchedule);
    _is24Hour = widget.is24Hour;
    _sleepSchedule = widget.sleepSchedule;
    _weekTargets = widget.weekTargets;

    _verticalController = ScrollController(initialScrollOffset: 0);
    _headerHorizontalController = ScrollController();
    _gridHorizontalController = ScrollController();

    // Sync horizontal scrolls
    _gridHorizontalController.addListener(() {
      if (_headerHorizontalController.hasClients &&
          _headerHorizontalController.offset !=
              _gridHorizontalController.offset) {
        _headerHorizontalController.jumpTo(_gridHorizontalController.offset);
      }
    });
    _headerHorizontalController.addListener(() {
      if (_gridHorizontalController.hasClients &&
          _gridHorizontalController.offset !=
              _headerHorizontalController.offset) {
        _gridHorizontalController.jumpTo(_headerHorizontalController.offset);
      }
    });
  }

  @override
  void didUpdateWidget(covariant WeekScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.is24Hour != widget.is24Hour) {
      _is24Hour = widget.is24Hour;
    }
    if (oldWidget.sleepSchedule != widget.sleepSchedule) {
      _sleepSchedule = widget.sleepSchedule;
    }
    if (oldWidget.weekTargets != widget.weekTargets) {
      _weekTargets = widget.weekTargets;
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _headerHorizontalController.dispose();
    _gridHorizontalController.dispose();
    super.dispose();
  }

  void _notifySave() {
    setState(() {});
    widget.onSave(_slots);
  }

  // --- Undo & Redo (Ctrl+Z & Ctrl+Shift+Z) ---

  List<ScheduleSlot> _cloneSlots(List<ScheduleSlot> list) {
    return list.map((s) => s.copyWith()).toList();
  }

  void _recordAction() {
    _undoStack.add(_cloneSlots(_slots));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_cloneSlots(_slots));
    final previous = _undoStack.removeLast();
    setState(() {
      _slots = previous;
    });
    _notifySave();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Undo'), duration: Duration(seconds: 1)),
    );
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_cloneSlots(_slots));
    final next = _redoStack.removeLast();
    setState(() {
      _slots = next;
    });
    _notifySave();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Redo'), duration: Duration(seconds: 1)),
    );
  }

  // --- Settings Dialog ---

  void _showSettingsDialog() {
    showCalendarSettingsDialog(
      context: context,
      is24Hour: _is24Hour,
      sleepSchedule: _sleepSchedule,
      weekTargets: _weekTargets,
      onSave: ({
        required bool is24Hour,
        required SleepSchedule sleepSchedule,
        required WeekTargets weekTargets,
      }) {
        setState(() {
          _is24Hour = is24Hour;
          _sleepSchedule = sleepSchedule;
          _weekTargets = weekTargets;
        });
        widget.onToggleTimeFormat?.call(is24Hour);
        widget.onUpdateSleepSchedule?.call(sleepSchedule);
        widget.onUpdateWeekTargets?.call(weekTargets);
      },
    );
  }

  // --- Waking Focus Hours (Shortened Scroll, Zero Bloat) ---

  int get _activeStartHour {
    if (!_sleepSchedule.isFocusEnabled) return 0;
    int wakeHour = _sleepSchedule.endMinutes ~/ 60;
    for (final s in _slots) {
      final sH = s.startMinutes ~/ 60;
      if (sH < wakeHour && sH >= 0) {
        wakeHour = sH;
      }
    }
    return wakeHour.clamp(0, 23);
  }

  int get _activeEndHour {
    if (!_sleepSchedule.isFocusEnabled) return 24;
    int bedHour = _sleepSchedule.startMinutes ~/ 60;
    for (final s in _slots) {
      final eH = (s.endMinutes + 59) ~/ 60;
      if (eH > bedHour && eH <= 24) {
        bedHour = eH;
      }
    }
    return bedHour.clamp(_activeStartHour + 1, 24);
  }

  int get _visibleHourCount => _activeEndHour - _activeStartHour;

  // --- Day Stats ---

  int _dayMinutes(int dayOfWeek, [TierCategory? tier]) {
    return _slots
        .where((s) => s.dayOfWeek == dayOfWeek && (tier == null || s.tier == tier))
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  int _totalTierMinutes(TierCategory tier) {
    return _slots
        .where((s) => s.tier == tier)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  int get _totalOtherMinutes {
    return _slots
        .where((s) => s.isOther)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  int get _totalWeekMinutes {
    return _slots.fold(0, (sum, s) => sum + s.durationMinutes);
  }

  // --- Solid Colors & Accents (Solid, Not Transparent) ---

  static Color _getSolidTierColor(TierCategory tier) {
    switch (tier) {
      case TierCategory.s:
        return const Color(0xFF1976D2); // Solid Blue
      case TierCategory.a:
        return const Color(0xFF2E7D32); // Solid Forest Green
      case TierCategory.b:
        return const Color(0xFFD97706); // Solid Warm Amber
    }
  }

  static Color _getSolidColor(ScheduleSlot slot) {
    if (slot.isOther || slot.tier == null) {
      return const Color(0xFF616161); // Solid Grey for Other
    }
    return _getSolidTierColor(slot.tier!);
  }

  static Color _getAccentBarColor(ScheduleSlot slot) {
    if (slot.isOther || slot.tier == null) {
      return const Color(0xFF424242); // Darker Grey accent bar
    }
    switch (slot.tier!) {
      case TierCategory.s:
        return const Color(0xFF0D47A1); // Deep Navy accent
      case TierCategory.a:
        return const Color(0xFF1B5E20); // Deep Forest Green accent
      case TierCategory.b:
        return const Color(0xFFB45309); // Deep Amber accent
    }
  }

  // --- Slot Actions ---

  void _addOrUpdateSlot({
    String? id,
    required int dayOfWeek,
    required int startMinutes,
    required int endMinutes,
    TierCategory? tier,
    String? title,
  }) {
    if (endMinutes <= startMinutes) return;

    _recordAction();

    if (id != null) {
      final idx = _slots.indexWhere((s) => s.id == id);
      if (idx != -1) {
        _slots[idx] = ScheduleSlot(
          id: id,
          dayOfWeek: dayOfWeek,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          tier: tier,
          title: title,
        );
      }
    } else {
      _slots.add(ScheduleSlot(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dayOfWeek: dayOfWeek,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        tier: tier,
        title: title,
      ));
    }
    _notifySave();
  }

  void _deleteSlot(String id) {
    _recordAction();
    _slots.removeWhere((s) => s.id == id);
    _notifySave();
  }

  // --- Copying Actions ---

  void _copyDayTo(int fromDay, List<int> targetDays) {
    final sourceSlots = _slots.where((s) => s.dayOfWeek == fromDay).toList();
    if (sourceSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No slots on ${_dayNames[fromDay] ?? 'this day'} to copy.')),
      );
      return;
    }

    _recordAction();

    // Remove existing slots on targets
    _slots.removeWhere((s) => targetDays.contains(s.dayOfWeek));

    // Clone into each target day
    for (final targetDay in targetDays) {
      for (final slot in sourceSlots) {
        _slots.add(ScheduleSlot(
          id: '${slot.id}_copy_${targetDay}_${DateTime.now().microsecondsSinceEpoch}',
          dayOfWeek: targetDay,
          startMinutes: slot.startMinutes,
          endMinutes: slot.endMinutes,
          tier: slot.tier,
          title: slot.title,
        ));
      }
    }
    _notifySave();

    final targetNames = targetDays.length == 6
        ? 'all other days'
        : targetDays.map((d) => _dayNames[d] ?? '$d').join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${_dayNames[fromDay] ?? ''} to $targetNames.')),
    );
  }

  void _clearDay(int day) {
    _recordAction();
    _slots.removeWhere((s) => s.dayOfWeek == day);
    _notifySave();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cleared ${_dayNames[day] ?? ''} slots.')),
    );
  }

  void _showCopyDayMenu(BuildContext context, int day) {
    final otherDays = _weekDayOrder.where((d) => d != day).toList();
    final isWeekday = day >= 1 && day <= 5;
    final daySlots = _slots.where((s) => s.dayOfWeek == day).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  '${_dayFullNames[day] ?? 'Day'} Options',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.copy_all),
                title: const Text('Copy to all days'),
                subtitle: const Text('Duplicate this day across the entire week'),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyDayTo(day, otherDays);
                },
              ),
              if (isWeekday)
                ListTile(
                  leading: const Icon(Icons.calendar_view_week),
                  title: const Text('Copy to all weekdays'),
                  subtitle: const Text('Duplicate to Monday through Friday'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final weekdays = [1, 2, 3, 4, 5].where((d) => d != day).toList();
                    _copyDayTo(day, weekdays);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.checklist_rtl),
                title: const Text('Copy to specific days...'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSelectDaysDialog(day);
                },
              ),
              if (daySlots.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text(
                    'Clear this day',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Confirmation dialog for clearing a day
                    showDialog(
                      context: context,
                      builder: (confirmCtx) => AlertDialog(
                        title: Text('Clear ${_dayFullNames[day] ?? 'Day'}?'),
                        content: Text(
                          'Are you sure you want to remove all ${daySlots.length} slot(s) on ${_dayFullNames[day]}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmCtx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () {
                              Navigator.pop(confirmCtx);
                              _clearDay(day);
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectDaysDialog(int sourceDay) {
    final candidates = _weekDayOrder.where((d) => d != sourceDay).toList();
    final selected = <int>{...candidates};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Copy ${_dayNames[sourceDay] ?? ''} to...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in candidates)
                CheckboxListTile(
                  title: Text(_dayFullNames[d] ?? ''),
                  value: selected.contains(d),
                  dense: true,
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selected.add(d);
                      } else {
                        selected.remove(d);
                      }
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _copyDayTo(sourceDay, selected.toList());
                    },
              child: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialogs: Add & Edit Slot ---

  void _showSlotDialog({
    ScheduleSlot? existingSlot,
    int? defaultDay,
    int? defaultStartMinutes,
  }) {
    int dayOfWeek = existingSlot?.dayOfWeek ?? defaultDay ?? _weekDayOrder.first;
    int startMinutes = existingSlot?.startMinutes ?? defaultStartMinutes ?? (9 * 60);
    int endMinutes = existingSlot?.endMinutes ?? (startMinutes + 120).clamp(0, 1440);
    bool isOther = existingSlot?.isOther ?? false;
    TierCategory selectedTier = existingSlot?.tier ?? TierCategory.s;
    final titleController = TextEditingController(text: existingSlot?.title ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final startDisplay = ScheduleSlot.formatMinutes(startMinutes, is24Hour: _is24Hour);
          final endDisplay = ScheduleSlot.formatMinutes(endMinutes, is24Hour: _is24Hour);
          final durationMinutes = endMinutes - startMinutes;
          final durationHours = durationMinutes / 60.0;
          final isDurationValid = durationMinutes > 0;
          final selectedCategoryCode = isOther ? 'other' : selectedTier.code.toLowerCase();
          final activeColor = isOther ? const Color(0xFF616161) : _getSolidTierColor(selectedTier);

          return AlertDialog(
            title: Text(existingSlot == null ? 'Add Loop Slot' : 'Edit Loop Slot'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Day selector (Sunday first!)
                    const Text(
                      'Day',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final d in _weekDayOrder)
                          ChoiceChip(
                            label: Text(_dayNames[d]!),
                            selected: dayOfWeek == d,
                            onSelected: (sel) {
                              if (sel) setDialogState(() => dayOfWeek = d);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tier / Other selector
                    const Text(
                      'Category',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment<String>(
                          value: 's',
                          label: Text(
                            'S',
                            style: TextStyle(
                              color: !isOther && selectedTier == TierCategory.s
                                  ? const Color(0xFF1976D2)
                                  : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ButtonSegment<String>(
                          value: 'a',
                          label: Text(
                            'A',
                            style: TextStyle(
                              color: !isOther && selectedTier == TierCategory.a
                                  ? const Color(0xFF2E7D32)
                                  : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ButtonSegment<String>(
                          value: 'b',
                          label: Text(
                            'B',
                            style: TextStyle(
                              color: !isOther && selectedTier == TierCategory.b
                                  ? const Color(0xFFD97706)
                                  : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const ButtonSegment<String>(
                          value: 'other',
                          label: Text(
                            'Other',
                            style: TextStyle(
                              color: Color(0xFF616161),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      selected: {selectedCategoryCode},
                      onSelectionChanged: (newSel) {
                        final val = newSel.first;
                        setDialogState(() {
                          if (val == 'other') {
                            isOther = true;
                          } else {
                            isOther = false;
                            selectedTier = TierCategory.fromCode(val);
                          }
                        });
                      },
                    ),

                    if (isOther) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        autofocus: existingSlot == null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Slot Name',
                          hintText: 'e.g. Gym, Lunch, Break',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Time selection row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Time',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.schedule, size: 16),
                                label: Text(startDisplay),
                                onPressed: () async {
                                  final tod = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(
                                      hour: startMinutes ~/ 60,
                                      minute: startMinutes % 60,
                                    ),
                                    builder: (context, child) {
                                      return MediaQuery(
                                        data: MediaQuery.of(context).copyWith(
                                          alwaysUse24HourFormat: _is24Hour,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (tod != null) {
                                    setDialogState(() {
                                      startMinutes = tod.hour * 60 + tod.minute;
                                      if (endMinutes <= startMinutes) {
                                        endMinutes = (startMinutes + 60).clamp(0, 1440);
                                      }
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Time',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.schedule, size: 16),
                                label: Text(endDisplay),
                                onPressed: () async {
                                  final tod = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(
                                      hour: endMinutes ~/ 60,
                                      minute: endMinutes % 60,
                                    ),
                                    builder: (context, child) {
                                      return MediaQuery(
                                        data: MediaQuery.of(context).copyWith(
                                          alwaysUse24HourFormat: _is24Hour,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (tod != null) {
                                    setDialogState(() {
                                      endMinutes = tod.hour * 60 + tod.minute;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isDurationValid
                          ? 'Duration: ${durationHours.toStringAsFixed(1)} hrs'
                          : 'End time must be after start time',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDurationValid
                            ? activeColor
                            : Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (existingSlot != null)
                TextButton(
                  onPressed: () {
                    // Confirmation dialog for deleting a slot
                    showDialog(
                      context: context,
                      builder: (confirmCtx) => AlertDialog(
                        title: const Text('Delete Slot?'),
                        content: Text(
                          'Are you sure you want to delete "${existingSlot.displayName}" (${existingSlot.formatRange(is24Hour: _is24Hour)})?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmCtx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () {
                              Navigator.pop(confirmCtx);
                              Navigator.pop(ctx);
                              _deleteSlot(existingSlot.id);
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isDurationValid
                    ? () {
                        Navigator.pop(ctx);
                        final customTitle = titleController.text.trim();
                        _addOrUpdateSlot(
                          id: existingSlot?.id,
                          dayOfWeek: dayOfWeek,
                          startMinutes: startMinutes,
                          endMinutes: endMinutes,
                          tier: isOther ? null : selectedTier,
                          title: isOther
                              ? (customTitle.isNotEmpty ? customTitle : 'Other')
                              : null,
                        );
                      }
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Modern Material 3 Top Bar ---

  Widget _buildTopBar(ThemeData theme) {
    final total = _totalWeekMinutes;
    final totalHoursStr = (total / 60.0).toStringAsFixed(1);
    final sMin = _totalTierMinutes(TierCategory.s);
    final aMin = _totalTierMinutes(TierCategory.a);
    final bMin = _totalTierMinutes(TierCategory.b);
    final otherMin = _totalOtherMinutes;

    final sPct = total > 0 ? (sMin / total * 100).round() : 0;
    final aPct = total > 0 ? (aMin / total * 100).round() : 0;
    final bPct = total > 0 ? (bMin / total * 100).round() : 0;
    final otherPct = total > 0 ? (otherMin / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Total hours + Target summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${totalHoursStr}h',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showSettingsDialog,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Target: ${_weekTargets.sPct}% S • ${_weekTargets.aPct}% A • ${_weekTargets.bPct}% B',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.tune,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Thin Material 3 multi-color progress track
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: total == 0
                  ? Container(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25))
                  : Row(
                      children: [
                        if (sMin > 0)
                          Expanded(
                            flex: sMin,
                            child: Container(color: const Color(0xFF1976D2)),
                          ),
                        if (aMin > 0)
                          Expanded(
                            flex: aMin,
                            child: Container(color: const Color(0xFF2E7D32)),
                          ),
                        if (bMin > 0)
                          Expanded(
                            flex: bMin,
                            child: Container(color: const Color(0xFFD97706)),
                          ),
                        if (otherMin > 0)
                          Expanded(
                            flex: otherMin,
                            child: Container(color: const Color(0xFF616161)),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),

          // Bottom Row: Clean, simple percentage pills
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _buildTierStatItem('S', const Color(0xFF1976D2), sMin, sPct),
              _buildTierStatItem('A', const Color(0xFF2E7D32), aMin, aPct),
              _buildTierStatItem('B', const Color(0xFFD97706), bMin, bPct),
              if (otherMin > 0)
                _buildTierStatItem('Other', const Color(0xFF616161), otherMin, otherPct),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierStatItem(String label, Color color, int minutes, int pct) {
    final hours = (minutes / 60.0).toStringAsFixed(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ${hours}h ($pct%)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // --- Week Grid ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): _redo,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Weekly Loop'),
            actions: [
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo (Ctrl+Z)',
                onPressed: _undoStack.isNotEmpty ? _undo : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                tooltip: 'Redo (Ctrl+Shift+Z)',
                onPressed: _redoStack.isNotEmpty ? _redo : null,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add Slot',
                onPressed: () => _showSlotDialog(),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Calendar Settings',
                onPressed: _showSettingsDialog,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) {
                  if (val == 'settings') {
                    _showSettingsDialog();
                  } else if (val == 'undo') {
                    _undo();
                  } else if (val == 'redo') {
                    _redo();
                  } else if (val == 'clear_all') {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear Weekly Loop?'),
                        content: const Text(
                          'This will remove all scheduled slots for the entire week.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _recordAction();
                              setState(() => _slots.clear());
                              _notifySave();
                            },
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.tune, size: 20),
                        SizedBox(width: 12),
                        Text('Calendar Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'undo',
                    enabled: _undoStack.isNotEmpty,
                    child: const Row(
                      children: [
                        Icon(Icons.undo, size: 20),
                        SizedBox(width: 12),
                        Text('Undo (Ctrl+Z)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'redo',
                    enabled: _redoStack.isNotEmpty,
                    child: const Row(
                      children: [
                        Icon(Icons.redo, size: 20),
                        SizedBox(width: 12),
                        Text('Redo (Ctrl+Shift+Z)'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Text('Clear All Slots', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _buildTopBar(theme),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth - _timeGutterWidth;
                    final columnWidth = max(78.0, availableWidth / 7);
                    final totalGridWidth = _timeGutterWidth + (columnWidth * 7);

                    final visibleHours = _visibleHourCount;
                    final totalGridHeight = _topPadding +
                        (visibleHours * _hourHeight) +
                        _bottomPadding;

                    return Column(
                      children: [
                        // Sticky Header Row (Sunday starting!)
                        SizedBox(
                          height: 52,
                          child: SingleChildScrollView(
                            controller: _headerHorizontalController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: totalGridWidth,
                              child: Row(
                                children: [
                                  // Corner gutter
                                  SizedBox(
                                    width: _timeGutterWidth,
                                    child: Center(
                                      child: Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                  // 7 Day Headers (Starting with Sunday)
                                  for (final d in _weekDayOrder)
                                    SizedBox(
                                      width: columnWidth,
                                      child: _buildDayHeaderCell(theme, d),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),

                        // Scrollable Grid (focused, short scroll area, zero bloat)
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _verticalController,
                            child: SingleChildScrollView(
                              controller: _gridHorizontalController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: totalGridWidth,
                                height: totalGridHeight,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Time gutter column (cleanly padded)
                                    SizedBox(
                                      width: _timeGutterWidth,
                                      child: _buildTimeGutter(theme),
                                    ),
                                    // 7 Day time-columns (Starting with Sunday)
                                    for (final d in _weekDayOrder)
                                      SizedBox(
                                        width: columnWidth,
                                        height: totalGridHeight,
                                        child: _buildDayColumn(
                                          theme,
                                          isDark,
                                          d,
                                          columnWidth,
                                          visibleHours,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayHeaderCell(ThemeData theme, int day) {
    final dayMins = _dayMinutes(day);
    final hours = (dayMins / 60.0).toStringAsFixed(1);

    return InkWell(
      onTap: () => _showCopyDayMenu(context, day),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _dayNames[day] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.copy_outlined,
                  size: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${hours}h',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: dayMins > 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeGutter(ThemeData theme) {
    final startHour = _activeStartHour;
    final visibleCount = _visibleHourCount;

    return Padding(
      padding: const EdgeInsets.only(top: _topPadding - 7),
      child: Column(
        children: [
          for (int i = 0; i < visibleCount; i++)
            SizedBox(
              height: _hourHeight,
              child: Text(
                ScheduleSlot.formatGutterHour(startHour + i, is24Hour: _is24Hour),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(
    ThemeData theme,
    bool isDark,
    int day,
    double colWidth,
    int visibleHours,
  ) {
    final startHour = _activeStartHour;
    final wakingStartMinutes = startHour * 60;
    final daySlots = _slots.where((s) => s.dayOfWeek == day).toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final dy = details.localPosition.dy - _topPadding;
        final hourOffset = (dy / _hourHeight).floor().clamp(0, visibleHours - 1);
        final hour = startHour + hourOffset;
        _showSlotDialog(
          defaultDay: day,
          defaultStartMinutes: hour * 60,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Stack(
          children: [
            // Hour background grid lines
            for (int i = 0; i < visibleHours; i++) ...[
              Positioned(
                top: _topPadding + (i * _hourHeight),
                left: 0,
                right: 0,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              // Half hour subtle dotted line
              Positioned(
                top: _topPadding + ((i + 0.5) * _hourHeight),
                left: 0,
                right: 0,
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
            ],

            // Slots positioned by start and duration relative to visible start
            for (final slot in daySlots)
              _buildSlotBlock(theme, isDark, slot, wakingStartMinutes),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotBlock(
    ThemeData theme,
    bool isDark,
    ScheduleSlot slot,
    int wakingStartMinutes,
  ) {
    final pxPerMinute = _hourHeight / 60.0;
    final relativeMinutes = slot.startMinutes - wakingStartMinutes;
    final top = _topPadding + (relativeMinutes * pxPerMinute);
    final height = max(24.0, slot.durationMinutes * pxPerMinute);
    final solidColor = _getSolidColor(slot);
    final accentBarColor = _getAccentBarColor(slot);
    final displayName = slot.displayName;

    final durationHours = slot.durationMinutes / 60.0;
    final durationStr = durationHours == durationHours.toInt()
        ? '${durationHours.toInt()}h'
        : '${durationHours.toStringAsFixed(1)}h';

    return Positioned(
      top: top + 1.5,
      left: 2.5,
      right: 2.5,
      height: height - 3.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSlotDialog(existingSlot: slot),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: solidColor, // 100% SOLID fill, not transparent
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.20),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent color bar
                  Container(
                    width: 4.5,
                    color: accentBarColor,
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                      child: ClipRect(
                        child: height < 36.0
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '• ${slot.formatRange(is24Hour: _is24Hour)} ($durationStr)',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.90),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0,
                                            vertical: 1.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.22),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            durationStr,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    slot.formatRange(is24Hour: _is24Hour),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.90),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
