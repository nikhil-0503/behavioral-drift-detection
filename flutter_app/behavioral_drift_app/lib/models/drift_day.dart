class DriftDay {
  final String date;
  final bool drift;

  DriftDay({
    required this.date,
    required this.drift,
  });

  factory DriftDay.fromJson(Map<String, dynamic> json) {
    return DriftDay(
      date: json['date'] as String,
      drift: json['drift'] as bool,
    );
  }
}
