import 'package:flutter/material.dart';

enum TierCategory {
  s('S', 'S Tier', Color(0xFFFFC107)),
  a('A', 'A Tier', Color(0xFF4CAF50)),
  b('B', 'B Tier', Color(0xFF2196F3));

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

  TierTask({
    required this.id,
    required this.title,
    required this.tier,
    required this.rank,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'rank': rank,
      'isCompleted': isCompleted,
    };
  }

  factory TierTask.fromJson(Map<String, dynamic> json, TierCategory defaultTier) {
    return TierTask(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled Task',
      tier: defaultTier,
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}
