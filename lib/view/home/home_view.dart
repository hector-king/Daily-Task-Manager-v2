import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../models/task.dart';
import '../../services/task_notification_service.dart';
import '../../utils/colors.dart';
import '../tasks/task_view.dart';
import 'widgets/task_widget.dart';

enum _TaskFilter { all, active, completed }

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController _searchController = TextEditingController();
  _TaskFilter _filter = _TaskFilter.all;
  String _searchQuery = '';
  final Set<String> _temporarilyHiddenTaskIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataStore = BaseWidget.of(context).dataStore;

    return ValueListenableBuilder<Box<Task>>(
      valueListenable: dataStore.listenToTask(),
      builder: (context, box, _) {
        final tasks = box.values.toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
        final completedCount = tasks.where((task) => task.isCompleted).length;
        final activeCount = tasks.length - completedCount;
        final visibleTasks = tasks.where((task) {
          final matchesFilter = switch (_filter) {
            _TaskFilter.all => true,
            _TaskFilter.active => !task.isCompleted,
            _TaskFilter.completed => task.isCompleted,
          };
          final query = _searchQuery.trim().toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              task.title.toLowerCase().contains(query) ||
              task.subtitle.toLowerCase().contains(query);
          return matchesFilter &&
              matchesSearch &&
              !_temporarilyHiddenTaskIds.contains(task.id);
        }).toList();

        return Scaffold(
          backgroundColor: MyColors.canvas,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openTaskEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New task'),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context, tasks),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                            child: _buildSummaryCard(
                              total: tasks.length,
                              active: activeCount,
                              completed: completedCount,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'Search your tasks',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _searchQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _FilterChip(
                                  label: 'All',
                                  count: tasks.length,
                                  selected: _filter == _TaskFilter.all,
                                  onSelected: () =>
                                      setState(() => _filter = _TaskFilter.all),
                                ),
                                _FilterChip(
                                  label: 'To do',
                                  count: activeCount,
                                  selected: _filter == _TaskFilter.active,
                                  onSelected: () => setState(
                                    () => _filter = _TaskFilter.active,
                                  ),
                                ),
                                _FilterChip(
                                  label: 'Done',
                                  count: completedCount,
                                  selected: _filter == _TaskFilter.completed,
                                  onSelected: () => setState(
                                    () => _filter = _TaskFilter.completed,
                                  ),
                                ),
                                if (tasks.isNotEmpty)
                                  PopupMenuButton<String>(
                                    tooltip: 'Task options',
                                    icon: const Icon(Icons.more_horiz_rounded),
                                    onSelected: (action) {
                                      if (action == 'clear_completed') {
                                        _confirmClearCompleted(context, tasks);
                                      } else if (action == 'delete_all') {
                                        _confirmDeleteAll(context, tasks);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (completedCount > 0)
                                        const PopupMenuItem(
                                          value: 'clear_completed',
                                          child: Text('Clear completed'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete_all',
                                        child: Text('Delete all tasks'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (visibleTasks.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox(
                          height: 280,
                          child: _EmptyState(
                            hasTasks: tasks.isNotEmpty,
                            isSearching: _searchQuery.trim().isNotEmpty,
                            onCreateTask: () => _openTaskEditor(context),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        sliver: SliverList.builder(
                          itemCount: visibleTasks.length,
                          itemBuilder: (context, index) {
                            final task = visibleTasks[index];
                            return Dismissible(
                              key: ValueKey(task.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: MyColors.danger,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) async {
                                try {
                                  await dataStore.deleteTask(task: task);
                                  await TaskNotificationService.instance
                                      .cancelTask(task);
                                } catch (error) {
                                  if (context.mounted) {
                                    setState(
                                      () => _temporarilyHiddenTaskIds.add(
                                        task.id,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not delete task: $error',
                                        ),
                                      ),
                                    );
                                  }
                                  await Future<void>.delayed(
                                    const Duration(milliseconds: 500),
                                  );
                                  if (mounted) {
                                    setState(
                                      () => _temporarilyHiddenTaskIds.remove(
                                        task.id,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text('Task deleted'),
                                      ),
                                    );
                                }
                              },
                              child: TaskWidget(task: task),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, List<Task> tasks) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: MyColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              color: MyColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My tasks',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: MyColors.muted),
                ),
              ],
            ),
          ),
          if (tasks.any((task) => task.isCompleted))
            IconButton(
              tooltip: 'View completed tasks',
              onPressed: () => setState(() => _filter = _TaskFilter.completed),
              icon: const Icon(Icons.history_rounded),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              try {
                await BaseWidget.of(context).dataStore.signOut();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not sign out: $error')),
                  );
                }
              }
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required int total,
    required int active,
    required int completed,
  }) {
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MyColors.primary, MyColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: MyColors.primary.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 0 ? 'A fresh start' : 'Your progress',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  total == 0
                      ? 'Make today count.'
                      : '$completed of $total tasks done',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  total == 0
                      ? 'Add a task to get things moving.'
                      : '$active ${active == 1 ? 'task' : 'tasks'} left to go',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  Future<void> _openTaskEditor(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final dataStore = BaseWidget.of(context).dataStore;
    final taskCreated = await Navigator.of(
      context,
    ).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TaskView(dataStore: dataStore),
      ),
    );
    if (taskCreated == true && mounted) {
      _searchController.clear();
      setState(() {
        _searchQuery = '';
        _filter = _TaskFilter.all;
      });
    }
  }

  Future<void> _confirmClearCompleted(
    BuildContext context,
    List<Task> tasks,
  ) async {
    final dataStore = BaseWidget.of(context).dataStore;
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear completed tasks?'),
        content: const Text('This permanently removes all completed tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear == true && context.mounted) {
      final completedTasks = tasks.where((task) => task.isCompleted).toList();
      try {
        await dataStore.deleteTasks(completedTasks);
        await Future.wait(
          completedTasks.map(
            TaskNotificationService.instance.cancelTask,
          ),
        );
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not clear completed tasks: $error')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteAll(BuildContext context, List<Task> tasks) async {
    final dataStore = BaseWidget.of(context).dataStore;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all tasks?'),
        content: const Text(
          'This permanently removes every task and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MyColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && context.mounted) {
      try {
        await dataStore.deleteTasks(tasks);
        await Future.wait(
          tasks.map(TaskNotificationService.instance.cancelTask),
        );
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete tasks: $error')),
          );
        }
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('$label  $count'),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasTasks,
    required this.isSearching,
    required this.onCreateTask,
  });

  final bool hasTasks;
  final bool isSearching;
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    final title = isSearching
        ? 'No matching tasks'
        : hasTasks
        ? 'Nothing in this view'
        : 'Nothing on your list yet';
    final message = isSearching
        ? 'Try another search term.'
        : hasTasks
        ? 'Choose another filter to see your tasks.'
        : 'Add your first task and make a little progress.';

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: MyColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: MyColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: MyColors.muted),
              ),
              if (!hasTasks && !isSearching) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onCreateTask,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create a task'),
                ),
              ],
            ],
          ),
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
