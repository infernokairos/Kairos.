import 'dart:async';
import 'package:flutter/material.dart';

import '../models/schedule_slot.dart';
import '../models/sleep_schedule.dart';
import '../models/tier_task.dart';
import '../models/week_targets.dart';
import '../services/task_storage.dart';
import '../widgets/archive_sheet.dart';
import '../widgets/habit_details_dialog.dart';
import '../widgets/task_tile.dart';
import '../widgets/threshold_sheet.dart';
import 'week_schedule_screen.dart';

class TasksScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const TasksScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _clockTimer;
  AppLifecycleListener? _lifecycleListener;
  String _lastCheckedDateKey = TierTask.dateKey(DateTime.now());

  bool _isLoading = true;
  Map<TierCategory, List<TierTask>> _tasksByTier = {
    TierCategory.s: [],
    TierCategory.a: [],
    TierCategory.b: [],
  };
  Map<TierCategory, int> _activeThresholds =
      TaskStorageData.defaultThresholds();
  List<ScheduleSlot> _weeklySchedule = [];
  SleepSchedule _sleepSchedule = const SleepSchedule();
  WeekTargets _weekTargets = const WeekTargets();
  bool _is24Hour = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final nowKey = TierTask.dateKey(DateTime.now());
      if (nowKey != _lastCheckedDateKey) {
        _lastCheckedDateKey = nowKey;
        _checkDailyReset();
      }
      setState(() {});
    });
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;
        final nowKey = TierTask.dateKey(DateTime.now());
        if (nowKey != _lastCheckedDateKey) {
          _lastCheckedDateKey = nowKey;
          _checkDailyReset();
          setState(() {});
        }
      },
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _clockTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // --- Data ---

  Future<void> _loadInitialData() async {
    final data = await TaskStorage.loadInitialData();
    final is24 = await TaskStorage.loadIs24Hour();
    final sleep = await TaskStorage.loadSleepSchedule();
    final targets = await TaskStorage.loadWeekTargets();
    if (mounted) {
      setState(() {
        _tasksByTier = data.tasks;
        _activeThresholds = data.activeThresholds;
        _weeklySchedule = data.weeklySchedule;
        _sleepSchedule = data.sleepSchedule.startMinutes != (23 * 60)
            ? data.sleepSchedule
            : sleep;
        _weekTargets = (data.weekTargets.sPct != 60 ||
                data.weekTargets.aPct != 25 ||
                data.weekTargets.bPct != 15)
            ? data.weekTargets
            : targets;
        _is24Hour = is24;
        _checkDailyReset();
        _isLoading = false;
      });
    }
  }

  void _saveState() {
    TaskStorage.saveToLocalStorage(
      _tasksByTier,
      _activeThresholds,
      _weeklySchedule,
      _sleepSchedule,
      _weekTargets,
    );
  }

  TierCategory get _currentSelectedTier =>
      _tabController.index < 3
          ? TierCategory.values[_tabController.index]
          : TierCategory.s;

  // --- Actions ---

  void _addTask(String title, TierCategory tier, [int totalSittings = 0]) {
    if (title.trim().isEmpty) return;
    setState(() {
      final list = _tasksByTier[tier]!;
      final activeCount = list.where((t) => !t.isArchived).length;
      list.add(TierTask(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title.trim(),
        tier: tier,
        rank: activeCount + 1,
        totalSittings: totalSittings,
      ));
      _saveState();
    });
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final sittingsController = TextEditingController();
    TierCategory selectedTier = _currentSelectedTier;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Task'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Task Name',
                    hintText: 'What needs to be done?',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (val) {
                    final text = val.trim();
                    if (text.isNotEmpty) {
                      final target =
                          int.tryParse(sittingsController.text.trim()) ?? 0;
                      _addTask(text, selectedTier, target);
                    }
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sittingsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Sittings (optional)',
                    hintText: 'e.g. 20',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Tier selector
                const Text(
                  'Tier',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SegmentedButton<TierCategory>(
                  segments: [
                    for (final t in TierCategory.values)
                      ButtonSegment<TierCategory>(
                        value: t,
                        label: Text(t.label),
                      ),
                  ],
                  selected: {selectedTier},
                  onSelectionChanged: (newSelection) {
                    setDialogState(() {
                      selectedTier = newSelection.first;
                    });
                  },
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
              onPressed: () {
                final text = titleController.text.trim();
                if (text.isNotEmpty) {
                  final target =
                      int.tryParse(sittingsController.text.trim()) ?? 0;
                  _addTask(text, selectedTier, target);
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _openHabitDetails(TierTask task) {
    showHabitDetailsDialog(
      context: context,
      task: task,
      onUpdate: () {
        setState(() {
          if (!_checkAndArchiveIfGoalReached(task)) {
            _saveState();
          }
        });
      },
    );
  }

  int _thresholdFor(TierCategory tier) =>
      _activeThresholds[tier] ?? TaskStorageData.defaultThreshold;

  void _checkDailyReset() {
    final todayKey = TierTask.dateKey(DateTime.now());
    bool changed = false;
    for (final tier in TierCategory.values) {
      final list = _tasksByTier[tier] ?? [];
      for (final task in list) {
        final completedToday = task.completedDates.contains(todayKey);
        if (task.isCompleted != completedToday) {
          task.isCompleted = completedToday;
          changed = true;
        }
      }
    }
    if (changed) {
      _saveState();
    }
  }

  void _reindexTierRanks(TierCategory tier) {
    final active = (_tasksByTier[tier] ?? []).where((t) => !t.isArchived).toList();
    for (int i = 0; i < active.length; i++) {
      active[i].rank = i + 1;
    }
  }

  bool _checkAndArchiveIfGoalReached(TierTask task) {
    if (task.totalSittings > 0 &&
        task.currentSittings >= task.totalSittings &&
        !task.isArchived) {
      task.isArchived = true;
      _reindexTierRanks(task.tier);
      _saveState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${task.title}" completed all sittings and moved to Archive.'),
          action: SnackBarAction(
            label: 'View',
            onPressed: _showArchiveSheet,
          ),
        ),
      );
      return true;
    }
    return false;
  }

  void _deleteTask(TierTask task) {
    setState(() {
      final list = _tasksByTier[task.tier]!;
      list.remove(task);
      _reindexTierRanks(task.tier);
      _saveState();
    });
  }

  void _renameTask(TierTask task, String newTitle) {
    setState(() {
      task.title = newTitle;
      _saveState();
    });
  }

  void _completeLoopTask(TierTask task) {
    final threshold = _thresholdFor(task.tier);
    final activeTasks = (_tasksByTier[task.tier] ?? [])
        .where((t) => !t.isArchived && t.rank <= threshold)
        .toList();

    TierTask? firstPending;
    for (final t in activeTasks) {
      if (!t.isCompleted) {
        firstPending = t;
        break;
      }
    }
    if (firstPending?.id != task.id) return;

    setState(() {
      final todayKey = TierTask.dateKey(DateTime.now());
      task.isCompleted = true;
      task.completedDates.add(todayKey);
      if (!_checkAndArchiveIfGoalReached(task)) {
        _saveState();
      }
    });
  }

  void _reorderTier(TierCategory tier, int oldIndex, int newIndex) {
    setState(() {
      final list = _tasksByTier[tier]!;
      final active = list.where((t) => !t.isArchived).toList();
      final archived = list.where((t) => t.isArchived).toList();
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = active.removeAt(oldIndex);
      active.insert(newIndex, item);
      for (int i = 0; i < active.length; i++) {
        active[i].rank = i + 1;
      }
      _tasksByTier[tier] = [...active, ...archived];
      _saveState();
    });
  }

  void _moveTask(TierTask task, TierCategory newTier) {
    setState(() {
      final oldTier = task.tier;
      // Remove from old tier
      final oldList = _tasksByTier[oldTier]!;
      oldList.remove(task);
      _reindexTierRanks(oldTier);

      // Add to new tier as pending
      task.tier = newTier;
      task.isCompleted = false;
      final newList = _tasksByTier[newTier]!;
      final newActive = newList.where((t) => !t.isArchived).toList();
      task.rank = newActive.length + 1;
      newList.add(task);
      _saveState();
    });
  }

  void _setThreshold(TierCategory tier, int value) {
    setState(() {
      _activeThresholds = {
        ..._activeThresholds,
        tier: value.clamp(
          TaskStorageData.minThreshold,
          TaskStorageData.maxThreshold,
        ),
      };
      _saveState();
    });
  }

  Future<void> _exportJson() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final success = await TaskStorage.exportJson(
        _tasksByTier,
        _activeThresholds,
        _weeklySchedule,
        _sleepSchedule,
        _weekTargets,
      );
      if (success) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Exported successfully')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importJson() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final imported = await TaskStorage.importJson();
      if (imported != null && mounted) {
        setState(() {
          _tasksByTier = imported.tasks;
          _activeThresholds = imported.activeThresholds;
          _weeklySchedule = imported.weeklySchedule;
          _sleepSchedule = imported.sleepSchedule;
          _weekTargets = imported.weekTargets;
          _checkDailyReset();
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Imported successfully')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  void _toggleTimeFormat() {
    setState(() {
      _is24Hour = !_is24Hour;
    });
    TaskStorage.saveIs24Hour(_is24Hour);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _is24Hour ? 'Switched to 24-hour time' : 'Switched to 12-hour time',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openWeekScheduleView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeekScheduleScreen(
          initialSchedule: _weeklySchedule,
          is24Hour: _is24Hour,
          sleepSchedule: _sleepSchedule,
          weekTargets: _weekTargets,
          onToggleTimeFormat: (val) {
            setState(() {
              _is24Hour = val;
            });
            TaskStorage.saveIs24Hour(_is24Hour);
          },
          onUpdateSleepSchedule: (val) {
            setState(() {
              _sleepSchedule = val;
            });
            TaskStorage.saveSleepSchedule(val);
            _saveState();
          },
          onUpdateWeekTargets: (val) {
            setState(() {
              _weekTargets = val;
            });
            TaskStorage.saveWeekTargets(val);
            _saveState();
          },
          onSave: (newSchedule) {
            setState(() {
              _weeklySchedule = newSchedule;
            });
            _saveState();
          },
        ),
      ),
    );
  }

  List<TierTask> get _allArchivedTasks {
    final archived = <TierTask>[];
    for (final tier in TierCategory.values) {
      archived.addAll((_tasksByTier[tier] ?? []).where((t) => t.isArchived));
    }
    return archived;
  }

  void _unarchiveTask(TierTask task) {
    setState(() {
      task.isArchived = false;
      final active = (_tasksByTier[task.tier] ?? [])
          .where((t) => !t.isArchived && t.id != task.id)
          .toList();
      task.rank = active.length + 1;
      _saveState();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${task.title}" restored to ${task.tier.label}.'),
      ),
    );
  }

  void _showArchiveSheet() {
    showArchiveSheet(
      context: context,
      getArchivedTasks: () => _allArchivedTasks,
      onRestore: _unarchiveTask,
      onDelete: _deleteTask,
      onOpenDetails: _openHabitDetails,
    );
  }

  void _showThresholds() {
    showThresholdSheet(
      context: context,
      thresholds: _activeThresholds,
      taskCounts: {
        for (final tier in TierCategory.values)
          tier: (_tasksByTier[tier] ?? []).where((t) => !t.isArchived).length,
      },
      onChanged: _setThreshold,
    );
  }

  String _formattedNow() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthName = months[now.month - 1];
    final minuteStr = now.minute.toString().padLeft(2, '0');
    if (_is24Hour) {
      final hourStr = now.hour.toString().padLeft(2, '0');
      return '${now.day} $monthName $hourStr:$minuteStr';
    } else {
      final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
      final amPm = now.hour >= 12 ? 'PM' : 'AM';
      return '${now.day} $monthName $hour12:$minuteStr $amPm';
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Kairos'),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _formattedNow(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.normal,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'S'),
            Tab(text: 'A'),
            Tab(text: 'B'),
            Tab(text: 'Loop'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_week_outlined),
            tooltip: 'Weekly Loop Schedule',
            onPressed: _openWeekScheduleView,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add task',
            onPressed: _showAddTaskDialog,
          ),
          PopupMenuButton<String>(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
            onSelected: (value) {
              switch (value) {
                case 'theme':
                  widget.onToggleTheme();
                case 'time_format':
                  _toggleTimeFormat();
                case 'archive':
                  _showArchiveSheet();
                case 'thresholds':
                  _showThresholds();
                case 'import':
                  _importJson();
                case 'export':
                  _exportJson();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      widget.isDarkMode
                          ? Icons.light_mode
                          : Icons.dark_mode,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.isDarkMode ? 'Light mode' : 'Dark mode',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'time_format',
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _is24Hour ? '12-hour time (AM/PM)' : '24-hour time',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Archive',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'thresholds',
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Thresholds',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Import',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Export',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTierList(TierCategory.s),
          _buildTierList(TierCategory.a),
          _buildTierList(TierCategory.b),
          _buildAllActive(),
        ],
      ),
    );
  }

  Widget _buildTierList(TierCategory tier) {
    final list = (_tasksByTier[tier] ?? []).where((t) => !t.isArchived).toList();
    final threshold =
        _activeThresholds[tier] ?? TaskStorageData.defaultThreshold;

    if (list.isEmpty) {
      return Center(
        child: Text(
          'No tasks',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      buildDefaultDragHandles: false,
      itemCount: list.length,
      onReorderItem: (oldIdx, newIdx) => _reorderTier(tier, oldIdx, newIdx),
      itemBuilder: (context, index) {
        final task = list[index];
        return TaskTile(
          key: ValueKey(task.id),
          task: task,
          isActive: task.rank <= threshold,
          index: index,
          showDragHandle: true,
          onTap: () => _openHabitDetails(task),
          onToggle: () {},
          onDelete: () => _deleteTask(task),
          onRename: (newTitle) => _renameTask(task, newTitle),
          onMoveTier: (newTier) => _moveTask(task, newTier),
        );
      },
    );
  }

  Widget _buildAllActive() {
    final grouped = <TierCategory, List<TierTask>>{};
    for (final tier in TierCategory.values) {
      final threshold = _thresholdFor(tier);
      final active = (_tasksByTier[tier] ?? [])
          .where((t) => !t.isArchived && t.rank <= threshold)
          .toList();
      if (active.isEmpty) continue;

      final pending = active.where((t) => !t.isCompleted).toList();
      final done = active.where((t) => t.isCompleted).toList();
      grouped[tier] = [...pending, ...done];
    }

    if (grouped.isEmpty) {
      return Center(
        child: Text(
          'No active tasks',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final tier in TierCategory.values)
          if (grouped.containsKey(tier)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                tier.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final task in grouped[tier]!)
              _buildLoopTile(
                task,
                !task.isCompleted &&
                    grouped[tier]!.where((t) => !t.isCompleted).firstOrNull?.id ==
                        task.id,
              ),
          ],
      ],
    );
  }

  Widget _buildLoopTile(TierTask task, bool isFirstPending) {
    return TaskTile(
      key: ValueKey('all_${task.id}'),
      task: task,
      isActive: true,
      isLoopMode: true,
      index: task.rank - 1,
      showCheckbox: isFirstPending,
      showTierBadge: true,
      onTap: () => _openHabitDetails(task),
      onToggle: isFirstPending ? () => _completeLoopTask(task) : () {},
      onDelete: () => _deleteTask(task),
      onRename: (newTitle) => _renameTask(task, newTitle),
      onMoveTier: (newTier) => _moveTask(task, newTier),
    );
  }
}
