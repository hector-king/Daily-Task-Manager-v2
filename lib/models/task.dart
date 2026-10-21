import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  Task({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.createdAtTime,
    required this.createdAtDate,
    required this.isCompleted,
    this.priority = 'medium',
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String subtitle;

  @HiveField(3)
  DateTime createdAtTime;

  @HiveField(4)
  DateTime createdAtDate;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  String priority;

  DateTime get dueAt => DateTime(
    createdAtDate.year,
    createdAtDate.month,
    createdAtDate.day,
    createdAtTime.hour,
    createdAtTime.minute,
  );

  TaskPriority get priorityLevel => TaskPriority.values.firstWhere(
    (value) => value.name == priority,
    orElse: () => TaskPriority.medium,
  );

  factory Task.fromSupabaseJson(Map<String, dynamic> json) {
    final dueAt = DateTime.parse(json['due_at'] as String).toLocal();
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      createdAtTime: dueAt,
      createdAtDate: DateTime(dueAt.year, dueAt.month, dueAt.day),
      isCompleted: json['is_completed'] as bool,
      priority: json['priority'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toSupabaseJson(String userId) => {
    'id': id,
    'user_id': userId,
    'title': title,
    'subtitle': subtitle,
    'due_at': dueAt.toUtc().toIso8601String(),
    'is_completed': isCompleted,
    'priority': priority,
  };

  factory Task.create({
    required String? title,
    required String? subtitle,
    DateTime? createdAtTime,
    DateTime? createdAtDate,
    String priority = 'medium',
  }) => Task(
    id: const Uuid().v1(),
    title: title ?? "",
    subtitle: subtitle ?? "",
    createdAtTime: createdAtTime ?? DateTime.now(),
    isCompleted: false,
    createdAtDate: createdAtDate ?? DateTime.now(),
    priority: priority,
  );
}

enum TaskPriority { low, medium, high }
