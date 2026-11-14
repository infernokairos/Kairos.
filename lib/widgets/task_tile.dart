import 'package:flutter/material.dart';

import '../models/tier_task.dart';

class TaskTile extends StatefulWidget {
  final TierTask task;
  final bool isActive;
  final bool isLoopMode;
  final int index;
  final bool showCheckbox;
  final bool showDragHandle;
  final bool showTierBadge;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final void Function(String newTitle)? onRename;
  final void Function(TierCategory newTier)? onMoveTier;

  const TaskTile({
    super.key,
    required this.task,
    required this.isActive,
    this.isLoopMode = false,
    this.index = 0,
    this.showCheckbox = false,
    this.showDragHandle = false,
    this.showTierBadge = false,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    this.onRename,
    this.onMoveTier,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  Offset? _tapPosition;

  void _storePosition(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: widget.task.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Task name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) {
              widget.onRename?.call(trimmed);
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
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                widget.onRename?.call(trimmed);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context) async {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final Offset targetPos = _tapPosition ??
        (context.findRenderObject() as RenderBox?)
            ?.localToGlobal(Offset.zero) ??
        Offset.zero;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(targetPos.dx, targetPos.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Rename'),
            ],
          ),
        ),
        for (final tier in TierCategory.values)
          if (tier != widget.task.tier)
            PopupMenuItem<String>(
              value: 'move_${tier.code}',
              child: Row(
                children: [
                  Icon(Icons.drive_file_move_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Move to ${tier.label}'),
                ],
              ),
            ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;
    if (selected == 'rename') {
      _showRenameDialog();
    } else if (selected == 'delete') {
      widget.onDelete();
    } else if (selected.startsWith('move_')) {
      final code = selected.substring(5);
      final targetTier = TierCategory.fromCode(code);
      widget.onMoveTier?.call(targetTier);
    }
  }

  Widget _buildLeading(BuildContext context, ThemeData theme) {
    if (widget.isLoopMode) {
      if (widget.task.isCompleted) {
        return const IgnorePointer(
          child: Checkbox(
            value: true,
            onChanged: null,
          ),
        );
      }

      if (widget.showCheckbox) {
        return Checkbox(
          value: false,
          onChanged: (_) => widget.onToggle(),
        );
      }

      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(
            Icons.circle_outlined,
            size: 10,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    if (widget.isActive) {
      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.task.tier.color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Text(
          '${widget.task.rank}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: widget.task.tier.color,
          ),
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      child: Icon(
        Icons.circle_outlined,
        size: 10,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDoneInLoop = widget.isLoopMode && widget.task.isCompleted;

    final Color? tileColor;
    if (isDoneInLoop) {
      tileColor = theme.colorScheme.onSurface.withValues(
        alpha: isDark ? 0.04 : 0.03,
      );
    } else if (widget.isActive) {
      // Rank 1 gets the strongest tint, decaying gently for lower ranks
      final tierColor = widget.task.tier.color;
      final rankStep = (widget.task.rank - 1).clamp(0, 9);
      final double baseAlpha = isDark ? 0.22 : 0.16;
      final double minAlpha = isDark ? 0.06 : 0.04;
      final double alpha = (baseAlpha - (rankStep * (isDark ? 0.025 : 0.02)))
          .clamp(minAlpha, baseAlpha);
      tileColor = tierColor.withValues(alpha: alpha);
    } else {
      tileColor = null;
    }

    return Dismissible(
      key: ValueKey('dismiss_${widget.task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _storePosition,
        onSecondaryTapDown: _storePosition,
        onSecondaryTap: () => _showContextMenu(context),
        child: ListTile(
          onTap: widget.onTap,
          tileColor: tileColor,
          leading: _buildLeading(context, theme),
          title: Text(
            widget.task.title,
            style: TextStyle(
              decoration: widget.task.isCompleted ? TextDecoration.lineThrough : null,
              color: widget.task.isCompleted
                  ? theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: widget.isLoopMode ? 0.55 : 1.0,
                    )
                  : widget.isActive
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: widget.showTierBadge
              ? Text(
                  '#${widget.task.rank}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: isDoneInLoop ? 0.5 : 1.0,
                    ),
                  ),
                )
              : (widget.task.totalSittings > 0
                  ? Text(
                      '${widget.task.currentSittings}/${widget.task.totalSittings} Sittings',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null),
          onLongPress: () => _showContextMenu(context),
          trailing: widget.showDragHandle
              ? ReorderableDragStartListener(
                  index: widget.index,
                  child: Icon(
                    Icons.drag_handle,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
