import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskPlannerApp());
}

class TaskPlannerApp extends StatelessWidget {
  const TaskPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF288760); // Jade green seed

    return MaterialApp(
      title: 'Task Planner - Tier-Loops',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F261E),
      ),
      home: const JadeBackgroundScreen(),
    );
  }
}

/// Tier categories for Tier-Loops
enum TierCategory {
  s('S', 'S Tier - Critical Priority', Color(0xFFFFD54F)), // Amber Gold
  a('A', 'A Tier - High Impact Core', Color(0xFF81C784)),  // Mint Jade
  b('B', 'B Tier - Standard Queue', Color(0xFF64B5F6));   // Sky Blue

  final String code;
  final String title;
  final Color badgeColor;

  const TierCategory(this.code, this.title, this.badgeColor);
}

/// Data model for a Tier-Loop task with priority ranking and completion
class TierTask {
  final String id;
  String title;
  TierCategory tier;
  int rank; // 1-based priority ranking
  bool isCompleted;

  TierTask({
    required this.id,
    required this.title,
    required this.tier,
    required this.rank,
    this.isCompleted = false,
  });
}

class JadeBackgroundScreen extends StatelessWidget {
  const JadeBackgroundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Organic calibrated mesh gradient
          const JadeGradientBackground(),

          // 2. High-blur glass diffusion filter
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: const SizedBox.expand(),
            ),
          ),

          // 3. Vector grid overlay
          const Positioned.fill(
            child: GridOverlay(
              gridSpacing: 38.0,
              gridColor: Color(0x1AFFFFFF),
              lineWidth: 1.0,
            ),
          ),

          // 4. Subtle top/bottom glass vignette sheen
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.22),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 5. Material 3 Expressive Application Scaffold
          const SafeArea(
            child: Column(
              children: [
                // M3 Expressive Top App Bar
                Material3ExpressiveAppBar(),

                // Two-panel split view with M3 slider
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                    child: ResizableSplitView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Material 3 Expressive Top Bar with branding and live status
class Material3ExpressiveAppBar extends StatelessWidget {
  const Material3ExpressiveAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        children: [
          // Logo Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.loop_rounded,
              color: colorScheme.onPrimaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Tier-Loops status pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      'Task Planner',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'TIER-LOOPS',
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'S / A / B Priority Ranking • Active Threshold Engine',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Expressive Action Buttons
          IconButton.filledTonal(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded, size: 20),
            tooltip: 'Search tasks',
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () {},
            icon: Badge(
              backgroundColor: colorScheme.primary,
              smallSize: 8,
              child: const Icon(Icons.bolt_rounded, size: 20),
            ),
            tooltip: 'Active task alerts',
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary,
            child: Text(
              'TL',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 2-part resizable split view connecting Tier-Loops to the Studio Canvas
class ResizableSplitView extends StatefulWidget {
  final double initialRatio;
  final double minRatio;
  final double maxRatio;
  final double dividerWidth;

  const ResizableSplitView({
    super.key,
    this.initialRatio = 0.50,
    this.minRatio = 0.20,
    this.maxRatio = 0.80,
    this.dividerWidth = 14.0,
  });

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _splitRatio;
  bool _isHovered = false;
  bool _isDragging = false;

  // Active tasks threshold (e.g. top-5 ranking priority)
  int _activeThreshold = 5;

  // Global list of Tier-Loop tasks
  final List<TierTask> _tasks = [
    TierTask(
      id: '1',
      title: 'Deploy Production Security Patch',
      tier: TierCategory.s,
      rank: 1,
    ),
    TierTask(
      id: '2',
      title: 'Database Failover Replication Check',
      tier: TierCategory.s,
      rank: 2,
    ),
    TierTask(
      id: '3',
      title: 'Key Stakeholder Sprint Demo',
      tier: TierCategory.s,
      rank: 3,
    ),
    TierTask(
      id: '4',
      title: 'Tier-Loop Active Threshold Engine',
      tier: TierCategory.a,
      rank: 4,
    ),
    TierTask(
      id: '5',
      title: 'Adaptive Dual-Pane Splitter Polish',
      tier: TierCategory.a,
      rank: 5,
    ),
    TierTask(
      id: '6',
      title: 'Real-time WebSocket Push Sync',
      tier: TierCategory.a,
      rank: 6,
    ),
    TierTask(
      id: '7',
      title: 'Automated CI/CD Pipeline Artifacts',
      tier: TierCategory.b,
      rank: 7,
    ),
    TierTask(
      id: '8',
      title: 'Audit Contrast & Accessibility Tokens',
      tier: TierCategory.b,
      rank: 8,
    ),
    TierTask(
      id: '9',
      title: 'Developer Documentation & Onboarding',
      tier: TierCategory.b,
      rank: 9,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _splitRatio = widget.initialRatio;
    _normalizeRanks();
  }

  void _normalizeRanks() {
    // Sort tasks by rank ascending and ensure sequential 1..N
    _tasks.sort((a, b) => a.rank.compareTo(b.rank));
    for (int i = 0; i < _tasks.length; i++) {
      _tasks[i].rank = i + 1;
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final task = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, task);
      _normalizeRanks();
    });
  }

  void _moveRank(TierTask task, int direction) {
    final currentIndex = _tasks.indexOf(task);
    if (currentIndex == -1) return;
    final targetIndex = currentIndex + direction;
    if (targetIndex >= 0 && targetIndex < _tasks.length) {
      setState(() {
        final item = _tasks.removeAt(currentIndex);
        _tasks.insert(targetIndex, item);
        _normalizeRanks();
      });
    }
  }

  void _addTask({required String title, required TierCategory tier}) {
    setState(() {
      final newTask = TierTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        tier: tier,
        rank: _tasks.length + 1,
      );
      _tasks.add(newTask);
      _normalizeRanks();
    });
  }

  void _setThreshold(int newThreshold) {
    setState(() {
      _activeThreshold = newThreshold.clamp(1, _tasks.isEmpty ? 1 : _tasks.length + 5);
    });
  }

  void _toggleTaskCompletion(TierTask task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final availableWidth =
            (totalWidth - widget.dividerWidth).clamp(0.0, double.infinity);

        final leftWidth = (availableWidth * _splitRatio).clamp(
          availableWidth * widget.minRatio,
          availableWidth * widget.maxRatio,
        );
        final rightWidth =
            (availableWidth - leftWidth).clamp(0.0, availableWidth);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Window / Panel 1: Tier-Loops
            SizedBox(
              width: leftWidth,
              child: LeftPanelWidget(
                splitRatio: _splitRatio,
                tasks: _tasks,
                activeThreshold: _activeThreshold,
                onReorder: _onReorder,
                onMoveRank: _moveRank,
                onAddTask: _addTask,
                onSetThreshold: _setThreshold,
                onToggleCompletion: _toggleTaskCompletion,
              ),
            ),

            // Middle Resizable M3 Splitter
            _buildM3Divider(availableWidth),

            // Right Window / Studio Canvas
            SizedBox(
              width: rightWidth,
              child: RightPanelWidget(
                splitRatio: 1.0 - _splitRatio,
                tasks: _tasks,
                activeThreshold: _activeThreshold,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildM3Divider(double availableWidth) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () {
          setState(() {
            _splitRatio = 0.5;
          });
        },
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
        },
        onHorizontalDragCancel: () {
          setState(() => _isDragging = false);
        },
        onHorizontalDragUpdate: (details) {
          if (availableWidth <= 0) return;
          setState(() {
            _splitRatio += details.delta.dx / availableWidth;
            _splitRatio = _splitRatio.clamp(widget.minRatio, widget.maxRatio);
          });
        },
        child: SizedBox(
          width: widget.dividerWidth,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle seam line
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: (_isHovered || _isDragging) ? 2 : 1,
                  decoration: BoxDecoration(
                    color: (_isHovered || _isDragging)
                        ? colorScheme.primary.withValues(alpha: 0.6)
                        : colorScheme.outlineVariant.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),

                // Pill Handle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: (_isHovered || _isDragging) ? 14 : 12,
                  height: (_isHovered || _isDragging) ? 52 : 42,
                  decoration: BoxDecoration(
                    color: (_isHovered || _isDragging)
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_isHovered || _isDragging)
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: (_isHovered || _isDragging) ? 10 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 2,
                          height: 10,
                          decoration: BoxDecoration(
                            color: (_isHovered || _isDragging)
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 2,
                          height: 10,
                          decoration: BoxDecoration(
                            color: (_isHovered || _isDragging)
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            borderRadius: BorderRadius.circular(1),
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
      ),
    );
  }
}

/// Panel 1: Tier-Loops
/// - 3 tabs: S, A, B tiers + small icon button to view all tiers in one tab
/// - Add tasks to each tier
/// - Priority ranking with dynamic re-ranking & numbering
/// - Active tasks threshold with distinct vibrant styling
class LeftPanelWidget extends StatefulWidget {
  final double splitRatio;
  final List<TierTask> tasks;
  final int activeThreshold;
  final Function(int oldIndex, int newIndex) onReorder;
  final Function(TierTask task, int direction) onMoveRank;
  final Function({required String title, required TierCategory tier}) onAddTask;
  final Function(int newThreshold) onSetThreshold;
  final Function(TierTask task) onToggleCompletion;

  const LeftPanelWidget({
    super.key,
    required this.splitRatio,
    required this.tasks,
    required this.activeThreshold,
    required this.onReorder,
    required this.onMoveRank,
    required this.onAddTask,
    required this.onSetThreshold,
    required this.onToggleCompletion,
  });

  @override
  State<LeftPanelWidget> createState() => _LeftPanelWidgetState();
}

class _LeftPanelWidgetState extends State<LeftPanelWidget> {
  // Current active tier filter: S, A, B or null for "All Tiers"
  TierCategory? _selectedTier = TierCategory.s;

  List<TierTask> get _filteredTasks {
    if (_selectedTier == null) {
      return widget.tasks; // All Tiers
    }
    return widget.tasks.where((t) => t.tier == _selectedTier).toList();
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    TierCategory chosenTier = _selectedTier ?? TierCategory.s;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;

            return AlertDialog(
              backgroundColor: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Icon(Icons.add_task_rounded, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  const Text('Add Tier-Loop Task'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      hintText: 'e.g. Optimize SQL indexing',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Tier',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: TierCategory.values.map((tier) {
                      final isChosen = chosenTier == tier;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text('${tier.code} Tier'),
                          selected: isChosen,
                          selectedColor: tier.badgeColor.withValues(alpha: 0.25),
                          side: BorderSide(
                            color: isChosen
                                ? tier.badgeColor
                                : colorScheme.outlineVariant,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                chosenTier = tier;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      widget.onAddTask(title: title, tier: chosenTier);
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Add Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showThresholdInputDialog(BuildContext context) {
    final controller =
        TextEditingController(text: widget.activeThreshold.toString());

    showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Set Active Tasks Threshold'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Top-N Priority Threshold',
              hintText: 'e.g. 5',
              helperText: 'Tasks ranked 1 to N will be highlighted as Active',
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val != null && val > 0) {
                  widget.onSetThreshold(val);
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeCount =
        widget.tasks.where((t) => t.rank <= widget.activeThreshold).length;

    return _buildM3PanelContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.layers_rounded,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Panel 1 • Tier-Loops',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                // Width Percentage
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${(widget.splitRatio * 100).toInt()}%',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3 Tabs (S, A, B) + Small Icon Button for All Tiers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
            child: Row(
              children: [
                // 3 Segmented Tabs: S, A, B
                Expanded(
                  child: SegmentedButton<TierCategory?>(
                    segments: [
                      ButtonSegment<TierCategory?>(
                        value: TierCategory.s,
                        label: const Text('S Tier'),
                        icon: Icon(
                          Icons.workspace_premium_rounded,
                          size: 16,
                          color: TierCategory.s.badgeColor,
                        ),
                      ),
                      ButtonSegment<TierCategory?>(
                        value: TierCategory.a,
                        label: const Text('A Tier'),
                        icon: Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: TierCategory.a.badgeColor,
                        ),
                      ),
                      ButtonSegment<TierCategory?>(
                        value: TierCategory.b,
                        label: const Text('B Tier'),
                        icon: Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: TierCategory.b.badgeColor,
                        ),
                      ),
                    ],
                    selected: {_selectedTier},
                    emptySelectionAllowed: true,
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedTier = newSelection.isNotEmpty
                            ? newSelection.first
                            : TierCategory.s;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: colorScheme.primaryContainer,
                      selectedForegroundColor: colorScheme.onPrimaryContainer,
                      backgroundColor: colorScheme.surfaceContainerLow
                          .withValues(alpha: 0.5),
                      foregroundColor: colorScheme.onSurfaceVariant,
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Small Icon to view ALL tiers in one tab
                Tooltip(
                  message: 'View all tiers in one tab',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _selectedTier = null; // Toggle All Tiers
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedTier == null
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedTier == null
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.view_agenda_rounded,
                        size: 18,
                        color: _selectedTier == null
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Tasks Threshold Control Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14.0, 8.0, 14.0, 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            const Text(
                              'Active Threshold:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            InkWell(
                              onTap: () => _showThresholdInputDialog(context),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Top-${widget.activeThreshold}',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$activeCount tasks currently active',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stepper [-] / [+]
                  IconButton.filledTonal(
                    onPressed: widget.activeThreshold > 1
                        ? () => widget.onSetThreshold(widget.activeThreshold - 1)
                        : null,
                    icon: const Icon(Icons.remove_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Decrease active threshold',
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    onPressed: () =>
                        widget.onSetThreshold(widget.activeThreshold + 1),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Increase active threshold',
                  ),
                ],
              ),
            ),
          ),

          // Task List with Priority Ranking & Numbering
          Expanded(
            child: _filteredTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 36,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No tasks in this tier yet',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    itemCount: _filteredTasks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = _filteredTasks[index];
                      final isActive = task.rank <= widget.activeThreshold;

                      return _buildTaskCard(
                        context: context,
                        task: task,
                        isActive: isActive,
                        onMoveUp: () => widget.onMoveRank(task, -1),
                        onMoveDown: () => widget.onMoveRank(task, 1),
                        canMoveUp: widget.tasks.indexOf(task) > 0,
                        canMoveDown:
                            widget.tasks.indexOf(task) < widget.tasks.length - 1,
                      );
                    },
                  ),
          ),

          // Add Task Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _showAddTaskDialog(context),
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: Text(
                  _selectedTier == null
                      ? 'Add Task to Tier-Loop'
                      : 'Add Task to ${_selectedTier!.code} Tier',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard({
    required BuildContext context,
    required TierTask task,
    required bool isActive,
    required VoidCallback onMoveUp,
    required VoidCallback onMoveDown,
    required bool canMoveUp,
    required bool canMoveDown,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    // Distinct styling for Active vs Remaining tasks
    final backgroundColor = isActive
        ? colorScheme.primaryContainer.withValues(alpha: 0.85)
        : colorScheme.surfaceContainerLow.withValues(alpha: 0.70);

    final borderColor = isActive
        ? colorScheme.primary
        : colorScheme.outlineVariant.withValues(alpha: 0.45);

    return Card(
      elevation: isActive ? 2 : 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: isActive ? 1.8 : 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onToggleCompletion(task),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              Checkbox(
                value: task.isCompleted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                activeColor: colorScheme.primary,
                onChanged: (_) => widget.onToggleCompletion(task),
              ),

              const SizedBox(width: 4),

              // Priority Rank Number Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? '#${task.rank} ACTIVE' : '#${task.rank} QUEUED',
                  style: TextStyle(
                    color: isActive
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Tier Code Badge (S, A, B)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: task.tier.badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: task.tier.badgeColor.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Text(
                  task.tier.code,
                  style: TextStyle(
                    color: task.tier.badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Title
              Expanded(
                child: Text(
                  task.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: task.isCompleted
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // Priority Ranking Adjustment Arrows
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Rank higher',
                onPressed: canMoveUp ? onMoveUp : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Rank lower',
                onPressed: canMoveDown ? onMoveDown : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel 2: Right Window - Workspace Canvas & Tier-Loop Analytics
class RightPanelWidget extends StatelessWidget {
  final double splitRatio;
  final List<TierTask> tasks;
  final int activeThreshold;

  const RightPanelWidget({
    super.key,
    required this.splitRatio,
    required this.tasks,
    required this.activeThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final activeTasks = tasks.where((t) => t.rank <= activeThreshold).toList();
    final sCount = tasks.where((t) => t.tier == TierCategory.s).length;
    final aCount = tasks.where((t) => t.tier == TierCategory.a).length;
    final bCount = tasks.where((t) => t.tier == TierCategory.b).length;

    return _buildM3PanelContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.space_dashboard_rounded,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Right Window • Focus Canvas',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                // Width Percentage
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${(splitRatio * 100).toInt()}%',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),

          // Expressive Studio Canvas
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 3 Expressive Tonal Metric Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context: context,
                        label: 'Active Tasks',
                        value: '${activeTasks.length}',
                        icon: Icons.bolt_rounded,
                        containerColor: colorScheme.primaryContainer,
                        onColor: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        context: context,
                        label: 'Active Limit',
                        value: '$activeThreshold Top',
                        icon: Icons.tune_rounded,
                        containerColor: colorScheme.tertiaryContainer,
                        onColor: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        context: context,
                        label: 'S / A / B Tiers',
                        value: '$sCount/$aCount/$bCount',
                        icon: Icons.layers_rounded,
                        containerColor: colorScheme.secondaryContainer,
                        onColor: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Active Tasks Execution Focus Box
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow.withValues(alpha: 0.75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.offline_bolt_rounded,
                                color: colorScheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Execution Stream',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tasks within threshold top-$activeThreshold priority ranking',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // List of Active Tasks inside Focus box
                        ...activeTasks.map((t) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${t.rank}',
                                      style: TextStyle(
                                        color: colorScheme.onPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: t.tier.badgeColor
                                          .withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      t.tier.code,
                                      style: TextStyle(
                                        color: t.tier.badgeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.play_arrow_rounded, size: 18),
                              label: const Text('Execute Active Loop'),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.sync_rounded, size: 18),
                              label: const Text('Refresh Threshold'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color containerColor,
    required Color onColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: onColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: onColor,
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onColor.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper container for Material 3 Expressive frosted glass panels
Widget _buildM3PanelContainer({
  required BuildContext context,
  required Widget child,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

/// Dynamic mesh-like gradient by composing overlapping positioned radial spots
class JadeGradientBackground extends StatelessWidget {
  const JadeGradientBackground({super.key});

  static const Color lightMint = Color(0xFFB7E5BA);
  static const Color sageGreen = Color(0xFF5CA87C);
  static const Color jadeMedium = Color(0xFF288760);
  static const Color deepForest = Color(0xFF1A5140);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF3E8F6F),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            height: 520,
            child: _buildGlowOval(
              color: lightMint,
              opacity: 0.90,
              radius: 0.85,
            ),
          ),
          Positioned(
            top: 20,
            left: 60,
            right: 60,
            height: 280,
            child: _buildGlowSphere(
              color: lightMint,
              opacity: 0.75,
              radius: 0.7,
            ),
          ),
          Positioned(
            top: 280,
            left: -100,
            width: 420,
            height: 480,
            child: _buildGlowSphere(
              color: deepForest,
              opacity: 0.92,
              radius: 0.65,
            ),
          ),
          Positioned(
            top: 340,
            right: -80,
            width: 440,
            height: 420,
            child: _buildGlowSphere(
              color: jadeMedium,
              opacity: 0.95,
              radius: 0.75,
            ),
          ),
          Positioned(
            bottom: 120,
            left: -60,
            width: 380,
            height: 380,
            child: _buildGlowSphere(
              color: deepForest,
              opacity: 0.85,
              radius: 0.7,
            ),
          ),
          Positioned(
            bottom: -100,
            left: -40,
            right: -40,
            height: 360,
            child: _buildGlowOval(
              color: sageGreen,
              opacity: 0.90,
              radius: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowSphere({
    required Color color,
    required double opacity,
    required double radius,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          radius: radius,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.45),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildGlowOval({
    required Color color,
    required double opacity,
    required double radius,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(500),
        gradient: RadialGradient(
          radius: radius,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.4),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

/// Custom painter for the background grid lines
class GridOverlay extends StatelessWidget {
  final double gridSpacing;
  final Color gridColor;
  final double lineWidth;

  const GridOverlay({
    super.key,
    this.gridSpacing = 38.0,
    this.gridColor = const Color(0x1AFFFFFF),
    this.lineWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(
        gridSpacing: gridSpacing,
        gridColor: gridColor,
        lineWidth: lineWidth,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double gridSpacing;
  final Color gridColor;
  final double lineWidth;

  _GridPainter({
    required this.gridSpacing,
    required this.gridColor,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.gridSpacing != gridSpacing ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.lineWidth != lineWidth;
}
