class WaterLevel {
  final int percentage;
  final String status;
  final bool buzzerActive;

  WaterLevel({
    required this.percentage,
    required this.status,
    required this.buzzerActive,
  });
  factory WaterLevel.fromJson(Map<String, dynamic> json) {
    return WaterLevel(
      percentage: json['percentage'] is int
          ? json['percentage']
          : int.parse(json['percentage'].toString()),
      status: json['status'] as String,
      buzzerActive: json['buzzer_active'] is bool
          ? json['buzzer_active']
          : json['buzzer_active'].toString().toLowerCase() == 'true',
    );
  }

  factory WaterLevel.initial() {
    return WaterLevel(
      percentage: 0,
      status: 'unknown',
      buzzerActive: false,
    );
  }
}
