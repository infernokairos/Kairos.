import 'package:flutter/material.dart';

enum TierCategory {
  s('S', 'S Tier', Color(0xFF2196F3)), // Blue
  a('A', 'A Tier', Color(0xFF4CAF50)), // Green
  b('B', 'B Tier', Color(0xFFFFC107)); // Yellow

  final String code;
  final String label;
  final Color color;

  const TierCategory(this.code, this.label, this.color);

  static TierCategory fromCode(String code) {
    return switch (code.toUpperCase()) {
      'S' => TierCategory.s,
      'A' => TierCategory.a,
      'B' => TierCategory.b,
      _ => TierCategory.s,
    };
  }
}

class TierTask {
  final String id;
  String title;
  TierCategory tier;
  int rank; // Independent rank 1..N within tier
  bool isCompleted;
  int totalSittings; // Total dedicated sittings target (0 = unset)
  bool isArchived;
  Set<String> completedDates; // "yyyy-MM-dd" dates marked Done (1 sitting per day)

  TierTask({
    required this.id,
    required this.title,
    required this.tier,
    required this.rank,
    this.isCompleted = false,
    this.totalSittings = 0,
    this.isArchived = false,
    Set<String>? completedDates,
  }) : completedDates = completedDates ?? {};

  int get currentSittings => completedDates.length;

  static String dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Map<String, dynamic> toJson() {
    final sortedDates = completedDates.toList()..sort();
    return {
      'id': id,
      'title': title,
      'rank': rank,
      'isCompleted': isCompleted,
      if (totalSittings > 0) 'totalSittings': totalSittings,
      if (isArchived) 'isArchived': true,
      if (sortedDates.isNotEmpty) 'completedDates': sortedDates,
    };
  }

  factory TierTask.fromJson(
    Map<String, dynamic> json,
    TierCategory defaultTier, {
    int fallbackRank = 1,
  }) {
    final dates = <String>{};

    final rawDates = json['completedDates'];
    if (rawDates is List) {
      for (final d in rawDates) {
        final s = d.toString().trim();
        if (s.isNotEmpty) dates.add(s);
      }
    }

    // Migrate legacy repetitions map (only Done = 1 entries)
    final rawReps = json['repetitions'];
    if (rawReps is Map) {
      for (final entry in rawReps.entries) {
        if (entry.value is num && (entry.value as num).toInt() == 1) {
          dates.add(entry.key.toString());
        }
      }
    }

    final dynamic rankVal = json['rank'];
    final dynamic totalSittingsVal = json['totalSittings'];
    final dynamic isArchivedVal = json['isArchived'];

    return TierTask(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled Task',
      tier: defaultTier,
      rank: rankVal is num ? rankVal.toInt() : fallbackRank,
      isCompleted: json['isCompleted'] as bool? ?? false,
      totalSittings: totalSittingsVal is num ? totalSittingsVal.toInt() : 0,
      isArchived: isArchivedVal is bool ? isArchivedVal : false,
      completedDates: dates,
    );
  }
}
