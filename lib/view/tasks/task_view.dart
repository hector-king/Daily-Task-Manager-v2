import '../../data/hive_data_store.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../services/task_notification_service.dart';
import '../../utils/colors.dart';

class TaskView extends StatefulWidget {
  const TaskView({super.key, required this.dataStore, this.task});

  final HiveDataStore dataStore;
  final Task? task;

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  late TaskPriority _priority;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _noteController = TextEditingController(text: task?.subtitle ?? '');
    _dueDate = task?.createdAtDate ?? DateTime.now();
    _dueTime = task == null
        ? TimeOfDay.now()
        : TimeOfDay.fromDateTime(task.createdAtTime);
    _priority = task?.priorityLevel ?? TaskPriority.medium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return Scaffold(
      backgroundColor: MyColors.canvas,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit task' : 'New task'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete task',
              onPressed: _isSaving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: (constraints.maxWidth - 48).clamp(0.0, 680.0),
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveTask,
                    icon: Icon(
                      isEditing ? Icons.save_rounded : Icons.add_rounded,
                    ),
                    label: Text(isEditing ? 'Save changes' : 'Create task'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth > 680 ? 680 : constraints.maxWidth,
              height: constraints.maxHeight,
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    Text(
                      isEditing ? 'Make an update' : 'What needs to get done?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add the details now. You can always change them later.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: MyColors.muted),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _titleController,
                      autofocus: false,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Task name',
                        hintText: 'e.g. Prepare project proposal',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a name for this task'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Add a few details (optional)',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Priority',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<TaskPriority>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: TaskPriority.values
                          .map(
                            (priority) => DropdownMenuItem(
                              value: priority,
                              child: Text(_priorityLabel(priority)),
                            ),
                          )
                          .toList(),
                      onChanged: (priority) {
                        if (priority != null) {
                          setState(() => _priority = priority);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Due date and time',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: Text(
                              DateFormat('MMM d, yyyy').format(_dueDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectTime,
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(_dueTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null && mounted) {
      setState(() => _dueDate = selectedDate);
    }
  }

  Future<void> _selectTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (selectedTime != null && mounted) {
      setState(() => _dueTime = selectedTime);
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      final dueAt = DateTime(
        _dueDate.year,
        _dueDate.month,
        _dueDate.day,
        _dueTime.hour,
        _dueTime.minute,
      );
      final task = widget.task;
      final dataStore = widget.dataStore;
      final needsReminder =
          !(task?.isCompleted ?? false) && dueAt.isAfter(DateTime.now());
      final notifications = TaskNotificationService.instance;
      final permissionGranted = needsReminder
          ? await notifications.requestPermission()
          : true;
      final savedTask = task == null
          ? Task.create(
              title: _titleController.text.trim(),
              subtitle: _noteController.text.trim(),
              createdAtTime: dueAt,
              createdAtDate: _dueDate,
              priority: _priority.name,
            )
          : Task(
              id: task.id,
              title: _titleController.text.trim(),
              subtitle: _noteController.text.trim(),
              createdAtTime: dueAt,
              createdAtDate: _dueDate,
              isCompleted: task.isCompleted,
              priority: _priority.name,
            );

      if (task == null) {
        await dataStore.addTask(task: savedTask);
      } else {
        await dataStore.updateTask(task: savedTask);
      }
      await notifications.scheduleTask(savedTask);

      if (mounted) {
        if (!permissionGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Task saved, but notifications are disabled. Enable them in Settings to receive reminders.',
              ),
            ),
          );
        }
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the task: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final dataStore = widget.dataStore;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this task?'),
        content: const Text('This task will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MyColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      try {
        await dataStore.deleteTask(task: widget.task!);
        await TaskNotificationService.instance.cancelTask(widget.task!);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete task: $error')),
          );
        }
      }
    }
  }

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
    };
  }
}
