import 'package:flutter/material.dart';

import 'models/tier_task.dart';
import 'services/task_storage.dart';

export 'models/tier_task.dart';
export 'services/task_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskPlannerApp());
}

class TaskPlannerApp extends StatefulWidget {
  const TaskPlannerApp({super.key});

  @override
  State<TaskPlannerApp> createState() => _TaskPlannerAppState();
}

class _TaskPlannerAppState extends State<TaskPlannerApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await TaskStorage.loadIsDarkTheme();
    if (mounted) {
      setState(() {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      TaskStorage.saveThemeMode(_themeMode == ThemeMode.dark);
    });
  }

  ThemeData _buildDarkTheme() {
    const bg = Color(0xFF0F1113);
    const surface = Color(0xFF16191C);
    const surfaceContainer = Color(0xFF1C2025);
    const border = Color(0xFF272C33);
    const primary = Color(0xFF34D399); // Crisp mint emerald

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: surface,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: Color(0xFF242A31),
        outline: border,
        onSurface: Color(0xFFEDEDED),
        onSurfaceVariant: Color(0xFF9EA4AC),
      ),
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFEDEDED)),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const bg = Color(0xFFF3F5F7);
    const surface = Color(0xFFFFFFFF);
    const surfaceContainer = Color(0xFFF8F9FA);
    const border = Color(0xFFE2E6EB);
    const primary = Color(0xFF059669); // Crisp forest emerald

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        surface: surface,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: Color(0xFFEDF0F4),
        outline: border,
        onSurface: Color(0xFF111827),
        onSurfaceVariant: Color(0xFF6B7280),
      ),
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF111827)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Planner',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: MainScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const MainScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

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
            backgroundColor: Color(0xFF1E3A2F),
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
            backgroundColor: Color(0xFF1E3A2F),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Task Planner',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          // Theme Toggle Button
          IconButton(
            key: const ValueKey('theme_toggle_btn'),
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
              color: isDark ? const Color(0xFFFFB300) : const Color(0xFF4B5563),
            ),
          ),
          // Import button
          IconButton(
            key: const ValueKey('import_json_btn'),
            tooltip: 'Import JSON',
            onPressed: _importJson,
            icon: Icon(Icons.file_upload_outlined, size: 20, color: theme.colorScheme.onSurface),
          ),
          // Export button
          IconButton(
            key: const ValueKey('export_json_btn'),
            tooltip: 'Export JSON',
            onPressed: _exportJson,
            icon: Icon(Icons.file_download_outlined, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 4),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 14.0),
              child: Text(
                'Top-$_activeThreshold Active',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
              // Splitter handle
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
                    color: theme.scaffoldBackgroundColor,
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Tier selection tab bar (clean pills with crystal clear contrast)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: _buildTierTabs(theme, isDark),
          ),

          // Active threshold controller
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Active Threshold: Top ${widget.activeThreshold}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
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

          Divider(height: 1, color: theme.colorScheme.outline),

          // Tasks: Reorderable list or All Tiers overview
          Expanded(
            child: _currentTier == null
                ? _buildAllTiers(theme, isDark)
                : _buildReorderableList(_currentTier!, theme, isDark),
          ),

          Divider(height: 1, color: theme.colorScheme.outline),

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
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: _currentTier == null ? 'Add task to S Tier...' : 'Add task to ${_currentTier!.label}...',
                      hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: isDark ? const Color(0xFF0F1113) : Colors.white,
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

  Widget _buildTierTabs(ThemeData theme, bool isDark) {
    final containerBg = isDark ? const Color(0xFF111316) : const Color(0xFFE9ECF0);
    final border = isDark ? const Color(0xFF262C33) : const Color(0xFFD6DBE2);

    final tabs = [
      (tier: TierCategory.s, label: 'S Tier', color: const Color(0xFFFFB300)),
      (tier: TierCategory.a, label: 'A Tier', color: const Color(0xFF34D399)),
      (tier: TierCategory.b, label: 'B Tier', color: const Color(0xFF38BDF8)),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          for (final item in tabs) ...[
            Expanded(
              child: _buildTabPill(
                label: item.label,
                tierColor: item.color,
                isSelected: _currentTier == item.tier,
                onTap: () => setState(() => _currentTier = item.tier),
                isDark: isDark,
                theme: theme,
              ),
            ),
            const SizedBox(width: 3),
          ],
          // All Tiers View Button
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _currentTier = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _currentTier == null
                    ? (isDark ? theme.colorScheme.primary.withValues(alpha: 0.2) : theme.colorScheme.primary)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _currentTier == null ? theme.colorScheme.primary : Colors.transparent,
                ),
              ),
              child: Icon(
                Icons.layers_rounded,
                size: 16,
                color: _currentTier == null
                    ? (isDark ? theme.colorScheme.primary : Colors.white)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String label,
    required Color tierColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required ThemeData theme,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? tierColor.withValues(alpha: 0.18) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? tierColor
                : Colors.transparent,
            width: isSelected ? 1.2 : 1.0,
          ),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? tierColor : tierColor.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? tierColor : const Color(0xFF111827))
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableList(TierCategory tier, ThemeData theme, bool isDark) {
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
          theme: theme,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildAllTiers(ThemeData theme, bool isDark) {
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tier.color,
                ),
              ),
            ),
            ...list.map((t) => _buildTaskRow(
                  key: ValueKey(t.id),
                  index: list.indexOf(t),
                  task: t,
                  isActive: t.rank <= widget.activeThreshold,
                  canDrag: false,
                  theme: theme,
                  isDark: isDark,
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
    required ThemeData theme,
    required bool isDark,
  }) {
    // Refined, subtle active and queued colors (no jarring neon green)
    final Color cardBg;
    final Color borderColor;
    final Color rankBg;
    final Color rankText;

    if (isActive) {
      cardBg = isDark ? const Color(0xFF141E18) : const Color(0xFFF0FDF4);
      borderColor = isDark ? const Color(0xFF234B36) : const Color(0xFF86EFAC);
      rankBg = isDark ? const Color(0xFF34D399).withValues(alpha: 0.16) : const Color(0xFFDCFCE7);
      rankText = isDark ? const Color(0xFF34D399) : const Color(0xFF15803D);
    } else {
      cardBg = isDark ? const Color(0xFF16191C) : Colors.white;
      borderColor = isDark ? const Color(0xFF262C33) : const Color(0xFFE2E6EB);
      rankBg = isDark ? const Color(0xFF22262C) : const Color(0xFFF1F3F5);
      rankText = isDark ? const Color(0xFF9EA4AC) : const Color(0xFF6B7280);
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: isActive ? 1.2 : 1.0,
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
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: rankBg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '#${task.rank}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: rankText,
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
            color: task.isCompleted
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: task.isCompleted,
              activeColor: theme.colorScheme.primary,
              onChanged: (_) => widget.onToggleTask(task),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
      color: isDark ? const Color(0xFF0F1113) : const Color(0xFFF9FAFB),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active Tasks Focus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14241B) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF285C3F) : const Color(0xFF86EFAC),
                  ),
                ),
                child: Text(
                  '${activeTasks.length} Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Expanded(
            child: activeTasks.isEmpty
                ? Center(
                    child: Text(
                      'No active tasks',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: activeTasks.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final t = activeTasks[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.tier.color.withValues(alpha: isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: t.tier.color),
                              ),
                              child: Text(
                                '${t.tier.code} #${t.rank}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: t.tier.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                  color: t.isCompleted
                                      ? theme.colorScheme.onSurfaceVariant
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Checkbox(
                              value: t.isCompleted,
                              activeColor: theme.colorScheme.primary,
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
