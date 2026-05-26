import 'dart:convert';

class WorkSession {
  final DateTime date;
  final int durationSeconds;

  WorkSession({
    required this.date,
    required this.durationSeconds,
  });

  // Convert a session to a Map/JSON
  Map<String, dynamic> toJson() {
    return {
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'durationSeconds': durationSeconds,
    };
  }

  // Create a session from a Map/JSON
  factory WorkSession.fromJson(Map<String, dynamic> json) {
    return WorkSession(
      date: DateTime.parse(json['date'] as String),
      durationSeconds: json['durationSeconds'] as int,
    );
  }

  // Get YYYY-MM-DD string representation of the date
  String get dateString =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
