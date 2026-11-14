import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tier_task.dart';
import 'file_helper.dart';

class TaskStorageData {
  static const int defaultThreshold = 2;
  static const int minThreshold = 0;
  static const int maxThreshold = 50;

  final Map<TierCategory, List<TierTask>> tasks;
  final Map<TierCategory, int> activeThresholds;

  const TaskStorageData({
    required this.tasks,
    required this.activeThresholds,
  });

  int thresholdFor(TierCategory tier) =>
      activeThresholds[tier] ?? defaultThreshold;

  static Map<TierCategory, int> defaultThresholds([
    int value = defaultThreshold,
  ]) {
    final clamped = value.clamp(minThreshold, maxThreshold);
    return {
      for (final tier in TierCategory.values) tier: clamped,
    };
  }
}

class TaskStorage {
  static const String _prefKey = 'kairos_tasks_data_json';

  /// Serializes tasks and per-tier thresholds to a formatted JSON string
  static String serialize(
    Map<TierCategory, List<TierTask>> tasksByTier,
    Map<TierCategory, int> activeThresholds,
  ) {
    final Map<String, int> thresholdsMap = {};
    final Map<String, dynamic> tasksMap = {};

    for (final tier in TierCategory.values) {
      final key = tier.code.toLowerCase();
      final threshold = (activeThresholds[tier] ?? TaskStorageData.defaultThreshold)
          .clamp(TaskStorageData.minThreshold, TaskStorageData.maxThreshold);
      thresholdsMap[key] = threshold;

      final list = tasksByTier[tier] ?? [];
      tasksMap[key] = list.map((t) => t.toJson()).toList();
    }

    final data = {
      'activeThresholds': thresholdsMap,
      'tasks': tasksMap,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static void _applyThresholdMap(
    dynamic rawMap,
    Map<TierCategory, int> thresholds,
  ) {
    if (rawMap is! Map) return;
    for (final entry in rawMap.entries) {
      final key = entry.key.toString().toLowerCase();
      for (final tier in TierCategory.values) {
        if (tier.code.toLowerCase() == key && entry.value is num) {
          thresholds[tier] = (entry.value as num).toInt().clamp(
                TaskStorageData.minThreshold,
                TaskStorageData.maxThreshold,
              );
          break;
        }
      }
    }
  }

  /// Deserializes a JSON string into tasks and per-tier active thresholds.
  /// Supports both per-tier maps (`activeThresholds`) and legacy scalar
  /// (`activeThreshold`) export formats.
  static TaskStorageData deserialize(String jsonStr) {
    final dynamic decoded = json.decode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root of JSON must be an object');
    }

    final dynamic rawLegacyThreshold = decoded['activeThreshold'];
    final int fallbackThreshold = rawLegacyThreshold is num
        ? rawLegacyThreshold.toInt().clamp(
              TaskStorageData.minThreshold,
              TaskStorageData.maxThreshold,
            )
        : TaskStorageData.defaultThreshold;

    final Map<TierCategory, int> thresholds =
        TaskStorageData.defaultThresholds(fallbackThreshold);
    _applyThresholdMap(rawLegacyThreshold, thresholds);
    _applyThresholdMap(decoded['activeThresholds'], thresholds);

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
              list.add(
                TierTask.fromJson(item, tier, fallbackRank: list.length + 1),
              );
            }
          }
          // Active tasks sorted by rank and re-indexed 1..N
          final active = list.where((t) => !t.isArchived).toList()
            ..sort((a, b) => a.rank.compareTo(b.rank));
          for (int i = 0; i < active.length; i++) {
            active[i].rank = i + 1;
          }
          final archived = list.where((t) => t.isArchived).toList();
          result[tier] = [...active, ...archived];
        }
      }
    }

    return TaskStorageData(
      tasks: result,
      activeThresholds: thresholds,
    );
  }

  /// Automatically persists the current state to local storage
  static Future<void> saveToLocalStorage(
    Map<TierCategory, List<TierTask>> tasksByTier,
    Map<TierCategory, int> activeThresholds,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = serialize(tasksByTier, activeThresholds);
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
      activeThresholds: TaskStorageData.defaultThresholds(),
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
    Map<TierCategory, int> activeThresholds,
  ) async {
    final jsonStr = serialize(tasksByTier, activeThresholds);
    return await PlatformFileHelper.downloadJson('tasks.json', jsonStr);
  }

  /// Imports tasks from a user-selected JSON file
  static Future<TaskStorageData?> importJson() async {
    final content = await PlatformFileHelper.pickJson();
    if (content == null || content.trim().isEmpty) return null;

    final data = deserialize(content);
    // Save imported data to local storage immediately
    await saveToLocalStorage(data.tasks, data.activeThresholds);
    return data;
  }

  static const String _themeKey = 'kairos_theme_mode';

  /// Saves the user selected ThemeMode
  static Future<void> saveThemeMode(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, isDark ? 'dark' : 'light');
    } catch (_) {}
  }

  /// Loads the persisted ThemeMode (defaults to dark)
  static Future<bool> loadIsDarkTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(_themeKey);
      if (mode == 'light') return false;
    } catch (_) {}
    return true;
  }
}
