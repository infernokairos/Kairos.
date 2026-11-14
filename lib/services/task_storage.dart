import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_slot.dart';
import '../models/sleep_schedule.dart';
import '../models/tier_task.dart';
import '../models/week_targets.dart';
import 'file_helper.dart';

class TaskStorageData {
  static const int defaultThreshold = 2;
  static const int minThreshold = 0;
  static const int maxThreshold = 50;

  final Map<TierCategory, List<TierTask>> tasks;
  final Map<TierCategory, int> activeThresholds;
  final List<ScheduleSlot> weeklySchedule;
  final SleepSchedule sleepSchedule;
  final WeekTargets weekTargets;

  const TaskStorageData({
    required this.tasks,
    required this.activeThresholds,
    this.weeklySchedule = const [],
    this.sleepSchedule = const SleepSchedule(),
    this.weekTargets = const WeekTargets(),
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

  /// Serializes tasks, per-tier thresholds, weekly schedule, sleep schedule, and target ratios to a formatted JSON string
  static String serialize(
    Map<TierCategory, List<TierTask>> tasksByTier,
    Map<TierCategory, int> activeThresholds, [
    List<ScheduleSlot> weeklySchedule = const [],
    SleepSchedule sleepSchedule = const SleepSchedule(),
    WeekTargets weekTargets = const WeekTargets(),
  ]) {
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

    final data = <String, dynamic>{
      'activeThresholds': thresholdsMap,
      'tasks': tasksMap,
      if (weeklySchedule.isNotEmpty)
        'weeklySchedule': weeklySchedule.map((s) => s.toJson()).toList(),
      if (sleepSchedule.startMinutes != 23 * 60 ||
          sleepSchedule.endMinutes != 7 * 60 ||
          !sleepSchedule.isFocusEnabled)
        'sleepSchedule': sleepSchedule.toJson(),
      if (weekTargets.sPct != 60 || weekTargets.aPct != 25 || weekTargets.bPct != 15)
        'weekTargets': weekTargets.toJson(),
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

    final dynamic rawSchedule = decoded['weeklySchedule'];
    final List<ScheduleSlot> schedule = [];
    if (rawSchedule is List) {
      for (final item in rawSchedule) {
        if (item is Map<String, dynamic>) {
          schedule.add(ScheduleSlot.fromJson(item));
        }
      }
    }

    final dynamic rawSleep = decoded['sleepSchedule'];
    final SleepSchedule sleepSchedule = rawSleep is Map<String, dynamic>
        ? SleepSchedule.fromJson(rawSleep)
        : const SleepSchedule();

    final dynamic rawTargets = decoded['weekTargets'];
    final WeekTargets weekTargets = rawTargets is Map<String, dynamic>
        ? WeekTargets.fromJson(rawTargets)
        : const WeekTargets();

    return TaskStorageData(
      tasks: result,
      activeThresholds: thresholds,
      weeklySchedule: schedule,
      sleepSchedule: sleepSchedule,
      weekTargets: weekTargets,
    );
  }

  /// Automatically persists the current state to local storage
  static Future<void> saveToLocalStorage(
    Map<TierCategory, List<TierTask>> tasksByTier,
    Map<TierCategory, int> activeThresholds, [
    List<ScheduleSlot> weeklySchedule = const [],
    SleepSchedule sleepSchedule = const SleepSchedule(),
    WeekTargets weekTargets = const WeekTargets(),
  ]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = serialize(
        tasksByTier,
        activeThresholds,
        weeklySchedule,
        sleepSchedule,
        weekTargets,
      );
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
    Map<TierCategory, int> activeThresholds, [
    List<ScheduleSlot> weeklySchedule = const [],
    SleepSchedule sleepSchedule = const SleepSchedule(),
    WeekTargets weekTargets = const WeekTargets(),
  ]) async {
    final jsonStr = serialize(
      tasksByTier,
      activeThresholds,
      weeklySchedule,
      sleepSchedule,
      weekTargets,
    );
    return await PlatformFileHelper.downloadJson('tasks.json', jsonStr);
  }

  /// Imports tasks from a user-selected JSON file
  static Future<TaskStorageData?> importJson() async {
    final content = await PlatformFileHelper.pickJson();
    if (content == null || content.trim().isEmpty) return null;

    final data = deserialize(content);
    // Save imported data to local storage immediately
    await saveToLocalStorage(
      data.tasks,
      data.activeThresholds,
      data.weeklySchedule,
      data.sleepSchedule,
      data.weekTargets,
    );
    return data;
  }

  static const String _themeKey = 'kairos_theme_mode';
  static const String _timeFormatKey = 'kairos_time_format_24h';
  static const String _sleepStartKey = 'kairos_sleep_start_minutes';
  static const String _sleepEndKey = 'kairos_sleep_end_minutes';
  static const String _sleepFocusKey = 'kairos_sleep_focus_enabled';
  static const String _targetSKey = 'kairos_target_s_pct';
  static const String _targetAKey = 'kairos_target_a_pct';
  static const String _targetBKey = 'kairos_target_b_pct';

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

  /// Saves 12h vs 24h time format preference
  static Future<void> saveIs24Hour(bool is24Hour) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_timeFormatKey, is24Hour);
    } catch (_) {}
  }

  /// Loads 12h vs 24h time format preference (defaults to false = 12h)
  static Future<bool> loadIs24Hour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_timeFormatKey) ?? false;
    } catch (_) {}
    return false;
  }

  /// Saves sleep schedule settings
  static Future<void> saveSleepSchedule(SleepSchedule schedule) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sleepStartKey, schedule.startMinutes);
      await prefs.setInt(_sleepEndKey, schedule.endMinutes);
      await prefs.setBool(_sleepFocusKey, schedule.isFocusEnabled);
    } catch (_) {}
  }

  /// Loads sleep schedule settings
  static Future<SleepSchedule> loadSleepSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final start = prefs.getInt(_sleepStartKey) ?? (23 * 60);
      final end = prefs.getInt(_sleepEndKey) ?? (7 * 60);
      final focus = prefs.getBool(_sleepFocusKey) ?? true;
      return SleepSchedule(
        startMinutes: start,
        endMinutes: end,
        isFocusEnabled: focus,
      );
    } catch (_) {}
    return const SleepSchedule();
  }

  /// Saves week target percentages
  static Future<void> saveWeekTargets(WeekTargets targets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_targetSKey, targets.sPct);
      await prefs.setInt(_targetAKey, targets.aPct);
      await prefs.setInt(_targetBKey, targets.bPct);
    } catch (_) {}
  }

  /// Loads week target percentages
  static Future<WeekTargets> loadWeekTargets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getInt(_targetSKey) ?? 60;
      final a = prefs.getInt(_targetAKey) ?? 25;
      final b = prefs.getInt(_targetBKey) ?? 15;
      return WeekTargets(sPct: s, aPct: a, bPct: b);
    } catch (_) {}
    return const WeekTargets();
  }
}
