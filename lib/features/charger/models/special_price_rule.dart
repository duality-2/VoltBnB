class SpecialPriceRule {
  final int startHour; // 0-23
  final int endHour;   // 0-23
  final double multiplier;
  final String label;   // e.g. 'Surge', 'Happy Hour'

  SpecialPriceRule({
    required this.startHour,
    required this.endHour,
    required this.multiplier,
    required this.label,
  });

  factory SpecialPriceRule.fromMap(Map<String, dynamic> map) {
    return SpecialPriceRule(
      startHour: map['startHour'] ?? 0,
      endHour: map['endHour'] ?? 0,
      multiplier: (map['multiplier'] ?? 1.0).toDouble(),
      label: map['label'] ?? 'Special',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startHour': startHour,
      'endHour': endHour,
      'multiplier': multiplier,
      'label': label,
    };
  }
}
