import 'package:flutter/material.dart';

import '../models/tier_task.dart';

void showArchiveSheet({
  required BuildContext context,
  required List<TierTask> Function() getArchivedTasks,
  required void Function(TierTask task) onRestore,
  required void Function(TierTask task) onDelete,
  required void Function(TierTask task) onOpenDetails,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final tasks = getArchivedTasks();
          return ArchiveSheetContent(
            archivedTasks: tasks,
            onRestore: (task) {
              onRestore(task);
              setSheetState(() {});
            },
            onDelete: (task) {
              onDelete(task);
              setSheetState(() {});
            },
            onOpenDetails: (task) {
              onOpenDetails(task);
              setSheetState(() {});
            },
          );
        },
      ),
    ),
  );
}

class ArchiveSheetContent extends StatelessWidget {
  final List<TierTask> archivedTasks;
  final void Function(TierTask task) onRestore;
  final void Function(TierTask task) onDelete;
  final void Function(TierTask task) onOpenDetails;

  const ArchiveSheetContent({
    super.key,
    required this.archivedTasks,
    required this.onRestore,
    required this.onDelete,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.75,
        maxWidth: 600,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Archive',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      archivedTasks.isEmpty
                          ? '0 completed'
                          : '${archivedTasks.length} ${archivedTasks.length == 1 ? 'task' : 'tasks'} completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (archivedTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 40,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No archived tasks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tasks move here automatically when their total sittings are completed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: archivedTasks.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  indent: 64,
                ),
                itemBuilder: (context, index) {
                  final task = archivedTasks[index];
                  final tier = task.tier;
                  final isTargetSet = task.totalSittings > 0;
                  final subtitleText = isTargetSet
                      ? '${task.currentSittings} / ${task.totalSittings} Sittings completed'
                      : '${task.currentSittings} ${task.currentSittings == 1 ? 'Sitting' : 'Sittings'} completed';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: tier.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tier.code,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tier.color,
                        ),
                      ),
                    ),
                    title: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => onOpenDetails(task),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.unarchive_outlined, size: 20),
                          tooltip: 'Restore to active',
                          onPressed: () => onRestore(task),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Delete permanently',
                          onPressed: () => onDelete(task),
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
