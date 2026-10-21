import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../main.dart';
import '../../../models/task.dart';
import '../../../services/task_notification_service.dart';
import '../../../utils/colors.dart';
import '../../tasks/task_view.dart';

class TaskWidget extends StatelessWidget {
  const TaskWidget({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (task.priorityLevel) {
      TaskPriority.low => const Color(0xFF438B68),
      TaskPriority.medium => const Color(0xFFB27629),
      TaskPriority.high => MyColors.danger,
    };
    final isOverdue = !task.isCompleted && task.dueAt.isBefore(DateTime.now());
    final dueLabel = isOverdue
        ? 'Overdue · ${DateFormat('MMM d, h:mm a').format(task.dueAt)}'
        : DateFormat('MMM d · h:mm a').format(task.dueAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: (value) async {
                if (value == null) return;
                final wasCompleted = task.isCompleted;
                task.isCompleted = value;
                try {
                  await BaseWidget.of(context).dataStore.updateTask(task: task);
                } catch (error) {
                  task.isCompleted = wasCompleted;
                  await task.save();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not update task: $error')),
                    );
                  }
                  return;
                }
                final notifications = TaskNotificationService.instance;
                if (value) {
                  await notifications.cancelTask(task);
                } else {
                  final permissionGranted = await notifications
                      .requestPermission();
                  await notifications.scheduleTask(task);
                  if (!permissionGranted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Notifications are disabled. Enable them in Settings to receive reminders.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TaskView(
                      dataStore: BaseWidget.of(context).dataStore,
                      task: task,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: task.isCompleted
                                        ? MyColors.muted
                                        : const Color(0xFF202238),
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                            ),
                            if (task.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                task.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: MyColors.muted,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 11),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _MetadataPill(
                                  icon: isOverdue
                                      ? Icons.warning_amber_rounded
                                      : Icons.schedule_rounded,
                                  label: dueLabel,
                                  color: isOverdue
                                      ? MyColors.danger
                                      : MyColors.muted,
                                ),
                                _MetadataPill(
                                  icon: Icons.flag_rounded,
                                  label: _priorityLabel(task.priorityLevel),
                                  color: priorityColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: MyColors.muted.withValues(alpha: 0.55),
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
    );
  }

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
    };
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
