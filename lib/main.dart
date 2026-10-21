import 'package:flutter/material.dart';

import 'models/tier_task.dart';
import 'services/task_storage.dart';

export 'models/tier_task.dart';
export 'services/task_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskPlannerApp());
}

class TaskPlannerApp extends StatelessWidget {
  const TaskPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141618),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4EBE88),
          surface: Color(0xFF141618),
          surfaceContainer: Color(0xFF1E2124),
          surfaceContainerHigh: Color(0xFF282C30),
          outline: Color(0xFF383D43),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  double _splitRatio = 0.52;
  int _activeThreshold = 2; // Top-N per tier considered active
  bool _isLoading = true;

  // Independent task lists & ranks for each tier
  Map<TierCategory, List<TierTask>> _tasksByTier = {
    TierCategory.s: [],
    TierCategory.a: [],
    TierCategory.b: [],
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final data = await TaskStorage.loadInitialData();
    if (mounted) {
      setState(() {
        _tasksByTier = data.tasks;
        _activeThreshold = data.activeThreshold;
        _isLoading = false;
      });
    }
  }

  void _saveState() {
    TaskStorage.saveToLocalStorage(_tasksByTier, _activeThreshold);
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

  void _addTask(TierCategory tier, String title) {
    if (title.trim().isEmpty) return;
    setState(() {
      final list = _tasksByTier[tier]!;
      list.add(
        TierTask(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.trim(),
          tier: tier,
          rank: list.length + 1,
        ),
      );
      _saveState();
    });
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

  void _toggleTask(TierTask task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
      _saveState();
    });
  }

  void _setThreshold(int value) {
    setState(() {
      _activeThreshold = value.clamp(1, 10);
      _saveState();
    });
  }

  Future<void> _exportJson() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final success = await TaskStorage.exportJson(_tasksByTier, _activeThreshold);
      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Tasks exported to tasks.json successfully.'),
            backgroundColor: Color(0xFF285C3F),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red[800],
        ),
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
          _activeThreshold = imported.activeThreshold;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Tasks imported successfully from JSON file.'),
            backgroundColor: Color(0xFF285C3F),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Import failed: Invalid JSON ($e)'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4EBE88)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 22, color: Color(0xFF4EBE88)),
            SizedBox(width: 8),
            Text('Task Planner', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF1A1D20),
        elevation: 0,
        actions: [
          // Import button
          IconButton(
            key: const ValueKey('import_json_btn'),
            tooltip: 'Import JSON',
            onPressed: _importJson,
            icon: const Icon(Icons.file_upload_outlined, size: 20),
          ),
          // Export button
          IconButton(
            key: const ValueKey('export_json_btn'),
            tooltip: 'Export JSON',
            onPressed: _exportJson,
            icon: const Icon(Icons.file_download_outlined, size: 20, color: Color(0xFF4EBE88)),
          ),
          const SizedBox(width: 4),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 14.0),
              child: Text(
                'Top-$_activeThreshold Active',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const dividerWidth = 10.0;
          final totalWidth = constraints.maxWidth;
          final availableWidth = (totalWidth - dividerWidth).clamp(0.0, double.infinity);
          final leftWidth = (availableWidth * _splitRatio).clamp(availableWidth * 0.25, availableWidth * 0.75);
          final rightWidth = (availableWidth - leftWidth).clamp(0.0, availableWidth);

          return Row(
            children: [
              SizedBox(
                width: leftWidth,
                child: LeftTierPanel(
                  tasksByTier: _tasksByTier,
                  activeThreshold: _activeThreshold,
                  onReorder: _reorderTier,
                  onAddTask: _addTask,
                  onDeleteTask: _deleteTask,
                  onToggleTask: _toggleTask,
                  onSetThreshold: _setThreshold,
                ),
              ),
              // Middle splitter handle
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => setState(() => _splitRatio = 0.5),
                  onHorizontalDragUpdate: (details) {
                    if (availableWidth > 0) {
                      setState(() {
                        _splitRatio = (_splitRatio + details.delta.dx / availableWidth).clamp(0.25, 0.75);
                      });
                    }
                  },
                  child: Container(
                    width: dividerWidth,
                    color: const Color(0xFF141618),
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF383D43),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: rightWidth,
                child: RightFocusPanel(
                  tasksByTier: _tasksByTier,
                  activeThreshold: _activeThreshold,
                  onToggleTask: _toggleTask,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Left Panel: Tier-Loops with independent rankings, drag-to-reorder, and instant quick-add
class LeftTierPanel extends StatefulWidget {
  final Map<TierCategory, List<TierTask>> tasksByTier;
  final int activeThreshold;
  final Function(TierCategory tier, int oldIndex, int newIndex) onReorder;
  final Function(TierCategory tier, String title) onAddTask;
  final Function(TierTask task) onDeleteTask;
  final Function(TierTask task) onToggleTask;
  final Function(int value) onSetThreshold;

  const LeftTierPanel({
    super.key,
    required this.tasksByTier,
    required this.activeThreshold,
    required this.onReorder,
    required this.onAddTask,
    required this.onDeleteTask,
    required this.onToggleTask,
    required this.onSetThreshold,
  });

  @override
  State<LeftTierPanel> createState() => _LeftTierPanelState();
}

class _LeftTierPanelState extends State<LeftTierPanel> {
  TierCategory? _currentTier = TierCategory.s; // null = All Tiers
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _submit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    widget.onAddTask(_currentTier ?? TierCategory.s, text);
    _inputController.clear();
    // Keep focus in text field for instant, frictionless consecutive entry
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1D20),
      child: Column(
        children: [
          // Tier selection tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<TierCategory?>(
                    segments: const [
                      ButtonSegment(value: TierCategory.s, label: Text('S Tier')),
                      ButtonSegment(value: TierCategory.a, label: Text('A Tier')),
                      ButtonSegment(value: TierCategory.b, label: Text('B Tier')),
                    ],
                    selected: {_currentTier},
                    emptySelectionAllowed: true,
                    onSelectionChanged: (val) {
                      setState(() => _currentTier = val.isNotEmpty ? val.first : TierCategory.s);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: const Color(0xFF282C30),
                      backgroundColor: const Color(0xFF141618),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'View all tiers in one tab',
                  onPressed: () => setState(() => _currentTier = null),
                  icon: const Icon(Icons.layers_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: _currentTier == null ? const Color(0xFF4EBE88) : const Color(0xFF282C30),
                    foregroundColor: _currentTier == null ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Active threshold controller
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF4EBE88)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Active Threshold: Top ${widget.activeThreshold}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.activeThreshold > 1 ? () => widget.onSetThreshold(widget.activeThreshold - 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => widget.onSetThreshold(widget.activeThreshold + 1),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF282C30)),

          // Tasks: Reorderable list or All Tiers overview
          Expanded(
            child: _currentTier == null
                ? _buildAllTiers()
                : _buildReorderableList(_currentTier!),
          ),

          const Divider(height: 1, color: Color(0xFF282C30)),

          // Instant quick-add input with auto-focus retention
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: _currentTier == null ? 'Add task to S Tier...' : 'Add task to ${_currentTier!.label}...',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF141618),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF383D43)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4EBE88),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList(TierCategory tier) {
    final list = widget.tasksByTier[tier] ?? [];

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      buildDefaultDragHandles: false,
      itemCount: list.length,
      onReorderItem: (oldIdx, newIdx) => widget.onReorder(tier, oldIdx, newIdx),
      itemBuilder: (context, index) {
        final task = list[index];
        final isActive = task.rank <= widget.activeThreshold;

        return _buildTaskRow(
          key: ValueKey(task.id),
          index: index,
          task: task,
          isActive: isActive,
          canDrag: true,
        );
      },
    );
  }

  Widget _buildAllTiers() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: TierCategory.values.map((tier) {
        final list = widget.tasksByTier[tier] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Text(
                '${tier.label} (${list.length} tasks)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tier.color),
              ),
            ),
            ...list.map((t) => _buildTaskRow(
                  key: ValueKey(t.id),
                  index: list.indexOf(t),
                  task: t,
                  isActive: t.rank <= widget.activeThreshold,
                  canDrag: false,
                )),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTaskRow({
    required Key key,
    required int index,
    required TierTask task,
    required bool isActive,
    required bool canDrag,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1B2E24) : const Color(0xFF1E2124),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? const Color(0xFF4EBE88) : const Color(0xFF282C30),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDrag)
              ReorderableDragStartListener(
                index: index,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drag_indicator_rounded, size: 18, color: Colors.grey),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF4EBE88) : const Color(0xFF282C30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#${task.rank}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.black : Colors.white,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: task.isCompleted ? Colors.grey : Colors.white,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: task.isCompleted,
              activeColor: const Color(0xFF4EBE88),
              onChanged: (_) => widget.onToggleTask(task),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
              onPressed: () => widget.onDeleteTask(task),
            ),
          ],
        ),
      ),
    );
  }
}

/// Right Panel: Simple Active Focus stream
class RightFocusPanel extends StatelessWidget {
  final Map<TierCategory, List<TierTask>> tasksByTier;
  final int activeThreshold;
  final Function(TierTask task) onToggleTask;

  const RightFocusPanel({
    super.key,
    required this.tasksByTier,
    required this.activeThreshold,
    required this.onToggleTask,
  });

  @override
  Widget build(BuildContext context) {
    final activeTasks = <TierTask>[];
    for (final tier in TierCategory.values) {
      final list = tasksByTier[tier] ?? [];
      for (final t in list) {
        if (t.rank <= activeThreshold) {
          activeTasks.add(t);
        }
      }
    }

    return Container(
      color: const Color(0xFF141618),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFF4EBE88)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Active Tasks Focus',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2E24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4EBE88)),
                ),
                child: Text(
                  '${activeTasks.length} Active',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4EBE88)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF282C30)),
          const SizedBox(height: 12),
          Expanded(
            child: activeTasks.isEmpty
                ? const Center(child: Text('No active tasks', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: activeTasks.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final t = activeTasks[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2124),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF282C30)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.tier.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: t.tier.color),
                              ),
                              child: Text(
                                '${t.tier.code} #${t.rank}',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: t.tier.color),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                  color: t.isCompleted ? Colors.grey : Colors.white,
                                ),
                              ),
                            ),
                            Checkbox(
                              value: t.isCompleted,
                              activeColor: const Color(0xFF4EBE88),
                              onChanged: (_) => onToggleTask(t),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
