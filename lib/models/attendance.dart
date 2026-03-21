/// Data models for PESU Academy attendance data.
library;

import 'dart:convert';

class SubjectAttendance {
  final String code;
  final String title;
  final int? attended;
  final int? total;
  final double? percentage;

  SubjectAttendance({
    required this.code,
    required this.title,
    this.attended,
    this.total,
    this.percentage,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'attended': attended,
        'total': total,
        'percentage': percentage,
      };

  factory SubjectAttendance.fromJson(Map<String, dynamic> json) {
    return SubjectAttendance(
      code: json['code'] as String,
      title: json['title'] as String,
      attended: json['attended'] as int?,
      total: json['total'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }

  /// Color bucket for this subject's attendance.
  AttendanceLevel get level {
    if (percentage == null) return AttendanceLevel.unknown;
    if (percentage! >= 85) return AttendanceLevel.good;
    if (percentage! >= 75) return AttendanceLevel.warning;
    return AttendanceLevel.danger;
  }

  /// How many consecutive classes can be bunked while staying >= targetPercentage.
  /// Returns 0 if already below target or no data.
  int canBunk(double targetPercentage) {
    if (attended == null || total == null || total == 0) return 0;
    final targetFraction = targetPercentage / 100.0;
    // We want: attended / (total + x) >= targetFraction
    // => attended >= targetFraction * (total + x)
    // => x <= (attended / targetFraction) - total
    final maxBunkable = (attended! / targetFraction) - total!;
    return maxBunkable < 0 ? 0 : maxBunkable.floor();
  }

  /// How many classes need to be attended to reach targetPercentage.
  /// Returns 0 if already at or above target.
  /// Returns -1 if it is mathematically impossible (e.g. target is 100% but a class is already missed).
  int mustAttend(double targetPercentage) {
    if (attended == null || total == null || total == 0) return 0;
    if (percentage != null && percentage! >= targetPercentage) return 0;
    
    if (targetPercentage >= 100.0) {
      if (attended! < total!) return -1; // impossible to get 100% if missed any
      return 0; // already 100%
    }
    
    final targetFraction = targetPercentage / 100.0;
    // We want: (attended + x) / (total + x) >= targetFraction
    // => attended + x >= targetFraction * total + targetFraction * x
    // => (1 - targetFraction) * x >= targetFraction * total - attended
    // => x >= (targetFraction * total - attended) / (1 - targetFraction)
    final needed = ((targetFraction * total!) - attended!) / (1 - targetFraction);
    return needed <= 0 ? 0 : needed.ceil();
  }
}

class AttendanceData {
  final List<SubjectAttendance> subjects;
  final double? overallPercentage;
  final DateTime lastUpdated;

  AttendanceData({
    required this.subjects,
    this.overallPercentage,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'subjects': subjects.map((s) => s.toJson()).toList(),
        'overallPercentage': overallPercentage,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory AttendanceData.fromJson(Map<String, dynamic> json) {
    return AttendanceData(
      subjects: (json['subjects'] as List)
          .map((s) => SubjectAttendance.fromJson(s as Map<String, dynamic>))
          .toList(),
      overallPercentage: (json['overallPercentage'] as num?)?.toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AttendanceData.fromJsonString(String jsonString) {
    return AttendanceData.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Compute overall percentage from individual subjects.
  static double? computeOverall(List<SubjectAttendance> subjects) {
    final withData = subjects.where(
        (s) => s.attended != null && s.total != null && s.total! > 0);
    if (withData.isEmpty) return null;
    final totalAttended = withData.fold<int>(0, (sum, s) => sum + s.attended!);
    final totalClasses = withData.fold<int>(0, (sum, s) => sum + s.total!);
    if (totalClasses == 0) return null;
    return (totalAttended / totalClasses) * 100;
  }
}

enum AttendanceLevel { good, warning, danger, unknown }
