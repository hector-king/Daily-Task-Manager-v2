import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task.dart';

class HiveDataStore {
  static const boxName = "tasksBox";
  static const settingsBoxName = 'appSettingsBox';
  static const _localOwnerKey = 'localTasksOwner';

  HiveDataStore({this.userId}) : box = Hive.box<Task>(boxName);

  final String? userId;
  final Box<Task> box;
  Box<String> get _settings => Hive.box<String>(settingsBoxName);

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> initialize() async {
    final currentUserId = userId;
    if (currentUserId == null) return;
    final localOwner = _settings.get(_localOwnerKey);
    final localTasks = localOwner == null ? box.values.toList() : <Task>[];
    final rows = await _client
        .from('tasks')
        .select()
        .eq('user_id', currentUserId)
        .order('due_at');
    final remoteTasks = rows.map(Task.fromSupabaseJson).toList();

    if (remoteTasks.isEmpty && localTasks.isNotEmpty) {
      for (final task in localTasks) {
        await _upsert(task);
      }
      await _settings.put(_localOwnerKey, currentUserId);
      return;
    }

    await box.clear();
    await box.putAll({for (final task in remoteTasks) task.id: task});
    await _settings.put(_localOwnerKey, currentUserId);
  }

  Future<void> addTask({required Task task}) async {
    await _upsert(task);
    await box.put(task.id, task);
  }

  Future<Task?> getTask({required String id}) async {
    return box.get(id);
  }

  Future<void> updateTask({required Task task}) async {
    await _upsert(task);
    if (task.isInBox) {
      await task.save();
    } else {
      await box.put(task.id, task);
    }
  }

  Future<void> deleteTask({required Task task}) async {
    if (userId != null) {
      await _client
          .from('tasks')
          .delete()
          .eq('id', task.id)
          .eq('user_id', userId!);
    }
    await box.delete(task.id);
  }

  Future<void> deleteTasks(Iterable<Task> tasks) async {
    final ids = tasks.map((task) => task.id).toList();
    if (ids.isEmpty) return;

    if (userId != null) {
      await _client
          .from('tasks')
          .delete()
          .eq('user_id', userId!)
          .inFilter('id', ids);
    }
    await box.deleteAll(ids);
  }

  Future<void> deleteAllTasks() async {
    if (userId != null) {
      await _client.from('tasks').delete().eq('user_id', userId!);
    }
    await box.clear();
  }

  Future<void> signOut() async {
    if (userId == null) return;
    await _client.auth.signOut();
    await box.clear();
    await _settings.delete(_localOwnerKey);
  }

  ValueListenable<Box<Task>> listenToTask() {
    return box.listenable();
  }

  Future<void> _upsert(Task task) async {
    final currentUserId = userId;
    if (currentUserId == null) return;
    await _client
        .from('tasks')
        .upsert(task.toSupabaseJson(currentUserId), onConflict: 'id');
  }
}
