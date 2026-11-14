class WeekTargets {
  final int sPct;
  final int aPct;
  final int bPct;

  const WeekTargets({
    this.sPct = 60,
    this.aPct = 25,
    this.bPct = 15,
  });

  int get total => sPct + aPct + bPct;
  bool get isValid => total == 100;

  Map<String, dynamic> toJson() => {
        's': sPct,
        'a': aPct,
        'b': bPct,
      };

  factory WeekTargets.fromJson(Map<String, dynamic> json) {
    return WeekTargets(
      sPct: (json['s'] as num?)?.toInt().clamp(0, 100) ?? 60,
      aPct: (json['a'] as num?)?.toInt().clamp(0, 100) ?? 25,
      bPct: (json['b'] as num?)?.toInt().clamp(0, 100) ?? 15,
    );
  }

  WeekTargets copyWith({
    int? sPct,
    int? aPct,
    int? bPct,
  }) {
    return WeekTargets(
      sPct: sPct ?? this.sPct,
      aPct: aPct ?? this.aPct,
      bPct: bPct ?? this.bPct,
    );
  }
}
