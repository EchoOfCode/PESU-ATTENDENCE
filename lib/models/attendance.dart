import 'dart:convert';
import 'dart:math';

/// Represents a single subject's attendance data scraped from PESU Academy.
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

  /// Quick colour bucket for UI indicators.
  AttendanceLevel get level {
    if (percentage == null) return AttendanceLevel.unknown;
    if (percentage! >= 85) return AttendanceLevel.good;
    if (percentage! >= 75) return AttendanceLevel.warning;
    return AttendanceLevel.danger;
  }

  /// How many consecutive classes can be skipped and still stay >= [target]%.
  /// If [futureClasses] is provided, calculates how many classes out of the remaining scheduled classes can be skipped.
  int canBunk(double target, {int? futureClasses}) {
    if (attended == null || total == null || total == 0) return 0;
    final f = target / 100.0;
    
    if (futureClasses != null) {
      final totalExpected = total! + futureClasses;
      final maxSkips = attended! + futureClasses - (f * totalExpected);
      if (maxSkips < 0) return 0;
      return min(maxSkips.floor(), futureClasses);
    } else {
      final max = (attended! / f) - total!;
      return max < 0 ? 0 : max.floor();
    }
  }

  /// How many extra classes must be attended to reach [target]%.
  /// Returns -1 when the target is mathematically impossible.
  int mustAttend(double target, {int? futureClasses}) {
    if (attended == null || total == null || total == 0) return 0;
    
    // If not using future classes terminology, we optionally short-circuit:
    if (futureClasses == null && percentage != null && percentage! >= target) return 0;

    if (target >= 100.0) {
      return attended! < total! ? -1 : 0;
    }

    final f = target / 100.0;
    
    if (futureClasses != null) {
      final totalExpected = total! + futureClasses;
      final needed = (f * totalExpected) - attended!;
      if (needed <= 0) return 0;
      final y = needed.ceil();
      return y > futureClasses ? -1 : y;
    } else {
      final needed = ((f * total!) - attended!) / (1 - f);
      return needed <= 0 ? 0 : needed.ceil();
    }
  }
}

/// Aggregate attendance snapshot used for caching and widget sync.
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

  /// Weighted overall average across all subjects that have data.
  static double? computeOverall(List<SubjectAttendance> subjects) {
    final valid = subjects.where(
        (s) => s.attended != null && s.total != null && s.total! > 0);
    if (valid.isEmpty) return null;
    final totalAttended = valid.fold<int>(0, (sum, s) => sum + s.attended!);
    final totalClasses = valid.fold<int>(0, (sum, s) => sum + s.total!);
    if (totalClasses == 0) return null;
    return (totalAttended / totalClasses) * 100;
  }
}

enum AttendanceLevel { good, warning, danger, unknown }
