import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tier_task.dart';

class TaskStorageData {
  final Map<TierCategory, List<TierTask>> tasks;
  final int activeThreshold;

  const TaskStorageData({
    required this.tasks,
    required this.activeThreshold,
  });
}

class TaskStorage {
  static const String _prefKey = 'kairos_tasks_data_json';

  /// Serializes tasks and threshold to a formatted JSON string
  static String serialize(
    Map<TierCategory, List<TierTask>> tasksByTier,
    int activeThreshold,
  ) {
    final Map<String, dynamic> tasksMap = {};
    for (final tier in TierCategory.values) {
      final list = tasksByTier[tier] ?? [];
      tasksMap[tier.code.toLowerCase()] = list.map((t) => t.toJson()).toList();
    }

    final data = {
      'activeThreshold': activeThreshold,
      'tasks': tasksMap,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Deserializes a JSON string into tasks and active threshold
  static TaskStorageData deserialize(String jsonStr) {
    final dynamic decoded = json.decode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root of JSON must be an object');
    }

    final int threshold = (decoded['activeThreshold'] as num?)?.toInt() ?? 2;
    final dynamic rawTasks = decoded['tasks'];

    final Map<TierCategory, List<TierTask>> result = {
      TierCategory.s: [],
      TierCategory.a: [],
      TierCategory.b: [],
    };

    if (rawTasks is Map<String, dynamic>) {
      for (final tier in TierCategory.values) {
        final key = tier.code.toLowerCase();
        final rawList = rawTasks[key];
        if (rawList is List) {
          final list = <TierTask>[];
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              list.add(TierTask.fromJson(item, tier));
            }
          }
          // Sort by rank and re-index 1..N
          list.sort((a, b) => a.rank.compareTo(b.rank));
          for (int i = 0; i < list.length; i++) {
            list[i].rank = i + 1;
          }
          result[tier] = list;
        }
      }
    }

    return TaskStorageData(
      tasks: result,
      activeThreshold: threshold.clamp(1, 10),
    );
  }

  /// Automatically persists the current state to local storage
  static Future<void> saveToLocalStorage(
    Map<TierCategory, List<TierTask>> tasksByTier,
    int activeThreshold,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = serialize(tasksByTier, activeThreshold);
      await prefs.setString(_prefKey, jsonStr);
    } catch (_) {
      // Non-fatal if storage fails
    }
  }

  /// Loads initial state: from SharedPreferences, then asset, then defaults
  static Future<TaskStorageData> loadInitialData() async {
    // 1. Try SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefKey);
      if (savedJson != null && savedJson.trim().isNotEmpty) {
        return deserialize(savedJson);
      }
    } catch (_) {}

    // 2. Try bundled asset (assets/tasks.json)
    try {
      final assetJson = await rootBundle.loadString('assets/tasks.json');
      if (assetJson.trim().isNotEmpty) {
        return deserialize(assetJson);
      }
    } catch (_) {}

    // 3. Fallback to default hardcoded seed
    return TaskStorageData(
      activeThreshold: 2,
      tasks: {
        TierCategory.s: [
          TierTask(id: 's1', title: 'Critical Server Hotfix', tier: TierCategory.s, rank: 1),
          TierTask(id: 's2', title: 'Payment Gateway Integration', tier: TierCategory.s, rank: 2),
          TierTask(id: 's3', title: 'Client Product Launch', tier: TierCategory.s, rank: 3),
        ],
        TierCategory.a: [
          TierTask(id: 'a1', title: 'Responsive UI Polish', tier: TierCategory.a, rank: 1),
          TierTask(id: 'a2', title: 'Database Indexing', tier: TierCategory.a, rank: 2),
          TierTask(id: 'a3', title: 'User Onboarding Flow', tier: TierCategory.a, rank: 3),
        ],
        TierCategory.b: [
          TierTask(id: 'b1', title: 'Clean Legacy Helper Code', tier: TierCategory.b, rank: 1),
          TierTask(id: 'b2', title: 'Update Readme Documentation', tier: TierCategory.b, rank: 2),
          TierTask(id: 'b3', title: 'Color Contrast Audit', tier: TierCategory.b, rank: 3),
        ],
      },
    );
  }

  /// Exports tasks to a JSON file via file download/picker
  static Future<bool> exportJson(
    Map<TierCategory, List<TierTask>> tasksByTier,
    int activeThreshold,
  ) async {
    final jsonStr = serialize(tasksByTier, activeThreshold);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    final result = await FilePicker.saveFile(
      dialogTitle: 'Export Tasks JSON',
      fileName: 'tasks.json',
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    return result != null;
  }

  /// Imports tasks from a user-selected JSON file
  static Future<TaskStorageData?> importJson() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import Tasks JSON',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result.isEmpty) return null;

    final file = result.first;
    final content = await file.xFile.readAsString();
    final data = deserialize(content);

    // Save imported data to local storage immediately
    await saveToLocalStorage(data.tasks, data.activeThreshold);
    return data;
  }
}
