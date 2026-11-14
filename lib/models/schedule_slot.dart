import 'package:flutter/material.dart';

import 'tier_task.dart';

class ScheduleSlot {
  final String id;
  int dayOfWeek; // 1 = Monday .. 7 = Sunday (ISO 8601)
  int startMinutes; // Minutes from midnight (e.g. 540 = 09:00)
  int endMinutes; // Minutes from midnight (e.g. 720 = 12:00)
  TierCategory? tier; // S, A, B, or null for Other
  String? title; // Custom name (e.g. "Gym", "Lunch")

  ScheduleSlot({
    required this.id,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.tier,
    this.title,
  });

  bool get isOther => tier == null;

  Color get color => tier?.color ?? const Color(0xFF9E9E9E); // Grey for Other

  String get displayName => (title != null && title!.trim().isNotEmpty)
      ? title!.trim()
      : (tier != null ? '${tier!.code}-Tier' : 'Other');

  int get durationMinutes => endMinutes - startMinutes;

  String get startTimeFormatted => formatMinutes(startMinutes, is24Hour: true);
  String get endTimeFormatted => formatMinutes(endMinutes, is24Hour: true);

  static String formatMinutes(int minutes, {bool is24Hour = false}) {
    final h = (minutes ~/ 60).clamp(0, 24);
    final m = (minutes % 60).clamp(0, 59).toString().padLeft(2, '0');
    if (is24Hour) {
      return '${h.toString().padLeft(2, '0')}:$m';
    }
    final amPm = h >= 12 && h < 24 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $amPm';
  }

  static String formatGutterHour(int hour, {bool is24Hour = false}) {
    if (is24Hour) {
      return '${hour.toString().padLeft(2, '0')}:00';
    }
    if (hour == 0 || hour == 24) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }

  String formatRange({bool is24Hour = false}) {
    return '${formatMinutes(startMinutes, is24Hour: is24Hour)} - ${formatMinutes(endMinutes, is24Hour: is24Hour)}';
  }

  static int parseTimeString(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h * 60 + m).clamp(0, 1440);
  }

  ScheduleSlot copyWith({
    String? id,
    int? dayOfWeek,
    int? startMinutes,
    int? endMinutes,
    TierCategory? tier,
    String? title,
    bool clearTier = false,
  }) {
    return ScheduleSlot(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      tier: clearTier ? null : (tier ?? this.tier),
      title: title ?? this.title,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dayOfWeek': dayOfWeek,
        'start': startTimeFormatted,
        'end': endTimeFormatted,
        'tier': tier != null ? tier!.code.toLowerCase() : 'other',
        if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
      };

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) {
    final startStr = json['start'] as String? ?? '09:00';
    final endStr = json['end'] as String? ?? '10:00';
    final tierCode = json['tier'] as String?;
    final titleStr = json['title'] as String?;

    TierCategory? tier;
    if (tierCode != null && tierCode.toLowerCase() != 'other') {
      tier = TierCategory.fromCode(tierCode);
    }

    return ScheduleSlot(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt().clamp(1, 7) ?? 1,
      startMinutes: parseTimeString(startStr),
      endMinutes: parseTimeString(endStr),
      tier: tier,
      title: titleStr,
    );
  }
}
