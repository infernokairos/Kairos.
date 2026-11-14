import 'package:flutter/material.dart';

import '../models/tier_task.dart';

void showHabitDetailsDialog({
  required BuildContext context,
  required TierTask task,
  required VoidCallback onUpdate,
}) {
  showDialog(
    context: context,
    builder: (context) => _HabitDetailsDialog(
      task: task,
      onUpdate: onUpdate,
    ),
  );
}

class _HabitDetailsDialog extends StatefulWidget {
  final TierTask task;
  final VoidCallback onUpdate;

  const _HabitDetailsDialog({
    required this.task,
    required this.onUpdate,
  });

  @override
  State<_HabitDetailsDialog> createState() => _HabitDetailsDialogState();
}

class _HabitDetailsDialogState extends State<_HabitDetailsDialog> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _toggleDay(DateTime date) {
    setState(() {
      final key = TierTask.dateKey(date);
      final todayKey = TierTask.dateKey(DateTime.now());
      if (widget.task.completedDates.contains(key)) {
        widget.task.completedDates.remove(key);
        if (key == todayKey) {
          widget.task.isCompleted = false;
        }
      } else {
        widget.task.completedDates.add(key);
        if (key == todayKey) {
          widget.task.isCompleted = true;
        }
      }

      widget.onUpdate();
    });
  }

  void _showSetTargetDialog(BuildContext context) {
    final controller = TextEditingController(
      text: widget.task.totalSittings > 0 ? '${widget.task.totalSittings}' : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Target Sittings'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Total Sittings',
            hintText: 'e.g. 25',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final n = int.tryParse(val.trim());
            if (n != null && n >= 0) {
              setState(() {
                widget.task.totalSittings = n;
                widget.onUpdate();
              });
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n != null && n >= 0) {
                setState(() {
                  widget.task.totalSittings = n;
                  widget.onUpdate();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSittings(
    BuildContext context,
    ThemeData theme,
    Color tierColor,
  ) {
    final task = widget.task;
    final current = task.currentSittings;
    final total = task.totalSittings;
    final isTargetSet = total > 0;
    final progress = isTargetSet ? (current / total).clamp(0.0, 1.0) : 0.0;
    final percent = isTargetSet ? ((current / total) * 100).toInt() : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isTargetSet) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: tierColor),
                    const SizedBox(width: 6),
                    Text(
                      isTargetSet
                          ? '$current / $total Sittings'
                          : '$current ${current == 1 ? 'Sitting' : 'Sittings'} completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tierColor,
                      ),
                    ),
                    if (isTargetSet) ...[
                      const SizedBox(width: 6),
                      Text(
                        '($percent%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTargetSet)
                  IconButton(
                    icon: const Icon(Icons.remove, size: 14),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    tooltip: 'Decrease target sittings',
                    onPressed: () {
                      setState(() {
                        widget.task.totalSittings = total - 1;
                        widget.onUpdate();
                      });
                    },
                  ),
                InkWell(
                  onTap: () => _showSetTargetDialog(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: Text(
                      isTargetSet ? 'Goal: $total' : 'Set Goal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 14),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: 'Increase target sittings',
                  onPressed: () {
                    setState(() {
                      widget.task.totalSittings = total + 1;
                      widget.onUpdate();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final tierColor = task.tier.color;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title & Tier chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: tierColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Calendar View
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _monthYearLabel(_selectedMonth),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                            );
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildCalendarGrid(context, theme, tierColor),
              const SizedBox(height: 16),

              // Bottom Sittings Bar Analysis & Goal Stepper (down, zero bloat, no repetition)
              _buildBottomSittings(context, theme, tierColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, ThemeData theme, Color tierColor) {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday; // 1=Mon, 7=Sun
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        // Weekday headers
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42, // 6 weeks * 7 days
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            final dayOffset = index - (firstWeekday - 1);
            if (dayOffset < 0 || dayOffset >= daysInMonth) {
              return const SizedBox.shrink();
            }

            final dayNumber = dayOffset + 1;
            final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayNumber);
            final key = TierTask.dateKey(date);
            final isDone = widget.task.completedDates.contains(key);
            final isToday = date.isAtSameMomentAs(today);
            final isFuture = date.isAfter(today);

            Color bgColor;
            Color textColor;
            Border? border;

            if (isDone) {
              bgColor = tierColor;
              textColor = Colors.white;
            } else {
              bgColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
              textColor = isFuture
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                  : theme.colorScheme.onSurface;
            }

            if (isToday) {
              border = Border.all(color: tierColor, width: 1.5);
            }

            return InkWell(
              onTap: isFuture ? null : () => _toggleDay(date),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: border,
                ),
                child: Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _monthYearLabel(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

