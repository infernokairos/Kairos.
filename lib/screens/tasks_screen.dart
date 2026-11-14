import 'dart:async';
import 'package:flutter/material.dart';

import '../models/tier_task.dart';
import '../services/task_storage.dart';
import '../widgets/habit_details_dialog.dart';
import '../widgets/task_tile.dart';
import '../widgets/threshold_sheet.dart';

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
    if (mounted) {
      setState(() {
        _tasksByTier = data.tasks;
        _activeThresholds = data.activeThresholds;
        _checkDailyReset();
        _isLoading = false;
      });
    }
  }

  void _saveState() {
    TaskStorage.saveToLocalStorage(_tasksByTier, _activeThresholds);
  }

  TierCategory get _currentSelectedTier =>
      _tabController.index < 3
          ? TierCategory.values[_tabController.index]
          : TierCategory.s;

  // --- Actions ---

  void _addTask(String title, TierCategory tier) {
    if (title.trim().isEmpty) return;
    setState(() {
      final list = _tasksByTier[tier]!;
      list.add(TierTask(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title.trim(),
        tier: tier,
        rank: list.length + 1,
      ));
      _saveState();
    });
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
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
                      _addTask(text, selectedTier);
                    }
                    Navigator.pop(context);
                  },
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
                  _addTask(text, selectedTier);
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
        setState(() {});
        _saveState();
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

  void _deleteTask(TierTask task) {
    setState(() {
      final list = _tasksByTier[task.tier]!;
      list.remove(task);
      for (int i = 0; i < list.length; i++) {
        list[i].rank = i + 1;
      }
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
        .where((t) => t.rank <= threshold)
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
      _saveState();
    });
  }

  void _reorderTier(TierCategory tier, int oldIndex, int newIndex) {
    setState(() {
      final list = _tasksByTier[tier]!;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      for (int i = 0; i < list.length; i++) {
        list[i].rank = i + 1;
      }
      _saveState();
    });
  }

  void _moveTask(TierTask task, TierCategory newTier) {
    setState(() {
      final oldTier = task.tier;
      // Remove from old tier
      final oldList = _tasksByTier[oldTier]!;
      oldList.remove(task);
      for (int i = 0; i < oldList.length; i++) {
        oldList[i].rank = i + 1;
      }
      // Add to new tier as pending
      task.tier = newTier;
      task.isCompleted = false;
      final newList = _tasksByTier[newTier]!;
      task.rank = newList.length + 1;
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
      final success =
          await TaskStorage.exportJson(_tasksByTier, _activeThresholds);
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

  void _showThresholds() {
    showThresholdSheet(
      context: context,
      thresholds: _activeThresholds,
      taskCounts: {
        for (final tier in TierCategory.values)
          tier: (_tasksByTier[tier] ?? []).length,
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
    final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minuteStr = now.minute.toString().padLeft(2, '0');
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    return '${now.day} $monthName $hour12:$minuteStr $amPm';
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('Kairos'),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _formattedNow(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'theme':
                  widget.onToggleTheme();
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
                    Text(widget.isDarkMode ? 'Light mode' : 'Dark mode'),
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
                    Text('Thresholds'),
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
                    Text('Import'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Export'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTierList(TierCategory tier) {
    final list = _tasksByTier[tier] ?? [];
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
          .where((t) => t.rank <= threshold)
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
