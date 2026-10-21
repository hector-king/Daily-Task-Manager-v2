import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/task.dart';

class TaskNotificationService {
  TaskNotificationService._();

  static final instance = TaskNotificationService._();
  static const _channelId = 'task_reminders';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<T> _platformCall<T>(Future<T> Function() action, T fallback) async {
    try {
      return await action();
    } on PlatformException catch (error) {
      debugPrint('Task reminders unavailable: $error');
      return fallback;
    } on MissingPluginException catch (error) {
      debugPrint('Task reminders unavailable: $error');
      return fallback;
    }
  }

  Future<void> initialize() => _platformCall(_initialize, null);
  Future<bool> requestPermission() => _platformCall(_requestPermission, false);
  Future<void> syncTasks(Iterable<Task> tasks) =>
      _platformCall(() => _syncTasks(tasks), null);
  Future<void> scheduleTask(Task task) =>
      _platformCall(() => _scheduleTask(task), null);
  Future<void> cancelTask(Task task) =>
      _platformCall(() => _cancelTask(task), null);

  Future<void> _initialize() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _isInitialized) {
      return;
    }

    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_launcher'),
      ),
    );
    _isInitialized = true;
  }

  Future<bool> _requestPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    if (!_isInitialized) return false;

    final granted = await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> _syncTasks(Iterable<Task> tasks) async {
    if (!_isInitialized) return;

    final taskList = tasks.toList();
    final now = DateTime.now();
    final expectedIds = taskList
        .where((task) => !task.isCompleted && task.dueAt.isAfter(now))
        .map(_notificationId)
        .toSet();
    final pending = await _notifications.pendingNotificationRequests();

    for (final notification in pending) {
      if (!expectedIds.contains(notification.id)) {
        await _notifications.cancel(id: notification.id);
      }
    }

    for (final task in taskList) {
      // A delivered reminder must not be recreated when its notification opens
      // the app. Only restore reminders whose original time is still ahead.
      if (!task.isCompleted &&
          task.dueAt.subtract(const Duration(minutes: 10)).isAfter(now)) {
        await scheduleTask(task);
      }
    }
  }

  Future<void> _scheduleTask(Task task) async {
    if (!_isInitialized) return;

    final id = _notificationId(task);
    await _notifications.cancel(id: id);

    final dueAt = task.dueAt;
    if (task.isCompleted || !dueAt.isAfter(DateTime.now())) return;

    final reminderAt = dueAt.subtract(const Duration(minutes: 10));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Task reminders',
        channelDescription: 'Reminders for upcoming tasks',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    if (!reminderAt.isAfter(DateTime.now())) {
      // Tasks created close to their due time need an immediate notification,
      // not a scheduled date which is already past by the time it is checked.
      await _notifications.show(
        id: id,
        title: 'Task coming up',
        body: task.title,
        notificationDetails: details,
      );
      return;
    }

    await _notifications.zonedSchedule(
      id: id,
      title: 'Task coming up',
      body: task.title,
      scheduledDate: timezone.TZDateTime.from(reminderAt, timezone.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _cancelTask(Task task) async {
    if (!_isInitialized) return;
    await _notifications.cancel(id: _notificationId(task));
  }

  int _notificationId(Task task) {
    var hash = 0x811c9dc5;
    for (final codeUnit in task.id.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
