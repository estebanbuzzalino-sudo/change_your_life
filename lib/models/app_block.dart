class AppBlock {
  final String appName;
  final String packageName;
  final String durationType;
  final int durationValue;
  final String friendName;
  final String friendEmail;
  final DateTime startDate;
  final DateTime endDate;

  AppBlock({
    required this.appName,
    required this.packageName,
    required this.durationType,
    required this.durationValue,
    required this.friendName,
    required this.friendEmail,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'packageName': packageName,
      'durationType': durationType,
      'durationValue': durationValue,
      'friendName': friendName,
      'friendEmail': friendEmail,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory AppBlock.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return AppBlock(
      appName: map['appName'] ?? '',
      packageName: map['packageName'] ?? '',
      durationType: map['durationType'] ?? 'Días',
      durationValue: map['durationValue'] ?? 1,
      friendName: map['friendName'] ?? '',
      friendEmail: map['friendEmail'] ?? '',
      startDate: _parseDateOr(map['startDate'], now),
      endDate: _parseDateOr(map['endDate'], now),
    );
  }

  static DateTime _parseDateOr(dynamic value, DateTime fallback) {
    if (value is! String || value.isEmpty) return fallback;
    return DateTime.tryParse(value) ?? fallback;
  }
}