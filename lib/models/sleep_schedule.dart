import 'package:flutter/material.dart';

import 'schedule_slot.dart';

class SleepSchedule {
  final int startMinutes; // Bedtime (minutes from midnight, e.g. 1380 = 23:00)
  final int endMinutes; // Wake time (minutes from midnight, e.g. 420 = 07:00)
  final bool isFocusEnabled; // When true, sleep hours are collapsed to shorten the calendar scroll

  const SleepSchedule({
    this.startMinutes = 23 * 60, // 11:00 PM
    this.endMinutes = 7 * 60, // 07:00 AM
    this.isFocusEnabled = true,
  });

  /// Total sleep duration in minutes per night (handles wrap-around midnight cleanly)
  int get durationMinutes {
    if (endMinutes >= startMinutes) {
      return endMinutes - startMinutes;
    } else {
      return (1440 - startMinutes) + endMinutes;
    }
  }

  /// Sleep duration in hours per night
  double get durationHours => durationMinutes / 60.0;

  /// Total weekly sleep duration in hours (7 nights)
  double get weeklySleepHours => durationHours * 7.0;

  /// Total weekly waking / active hours (168h total in a week)
  double get weeklyAwakeHours => (24.0 * 7.0) - weeklySleepHours;

  /// Daily waking / active hours
  double get dailyAwakeHours => 24.0 - durationHours;

  /// Percentage of total weekly time spent sleeping
  int get sleepPercentOfTotal => ((durationMinutes / 1440.0) * 100).round();

  /// Percentage of total weekly time spent awake
  int get awakePercentOfTotal => (100 - sleepPercentOfTotal).clamp(0, 100);

  /// Sleep health status insight
  String get healthInsight {
    final h = durationHours;
    if (h >= 7.0 && h <= 9.0) {
      return 'Optimal adult sleep window (7–9 hrs)';
    } else if (h < 7.0) {
      return 'Below recommended 7 hrs/night';
    } else {
      return 'Extended sleep duration (>9 hrs)';
    }
  }

  Color get healthColor {
    final h = durationHours;
    if (h >= 7.0 && h <= 9.0) {
      return const Color(0xFF4CAF50); // Green
    } else if (h < 7.0) {
      return const Color(0xFFFF9800); // Amber
    } else {
      return const Color(0xFF2196F3); // Blue
    }
  }

  String formatTime(int minutes, {bool is24Hour = false}) {
    return ScheduleSlot.formatMinutes(minutes, is24Hour: is24Hour);
  }

  String formatRange({bool is24Hour = false}) {
    return '${formatTime(startMinutes, is24Hour: is24Hour)} – ${formatTime(endMinutes, is24Hour: is24Hour)}';
  }

  Map<String, dynamic> toJson() => {
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'isFocusEnabled': isFocusEnabled,
      };

  factory SleepSchedule.fromJson(Map<String, dynamic> json) {
    return SleepSchedule(
      startMinutes: (json['startMinutes'] as num?)?.toInt().clamp(0, 1439) ??
          (23 * 60),
      endMinutes:
          (json['endMinutes'] as num?)?.toInt().clamp(0, 1439) ?? (7 * 60),
      isFocusEnabled: json['isFocusEnabled'] as bool? ?? true,
    );
  }

  SleepSchedule copyWith({
    int? startMinutes,
    int? endMinutes,
    bool? isFocusEnabled,
  }) {
    return SleepSchedule(
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      isFocusEnabled: isFocusEnabled ?? this.isFocusEnabled,
    );
  }
}
