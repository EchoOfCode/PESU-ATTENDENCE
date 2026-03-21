import 'dart:convert';

/// Represents one class slot in a weekly timetable.
class ClassSlot {
  /// 1=Monday, 2=Tuesday ... 7=Sunday
  final int dayOfWeek;
  final String startTime; // "HH:mm" format
  final String endTime;   // "HH:mm" format
  final String subjectTitle;

  ClassSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subjectTitle,
  });

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'subjectTitle': subjectTitle,
      };

  factory ClassSlot.fromJson(Map<String, dynamic> json) => ClassSlot(
        dayOfWeek: json['dayOfWeek'] as int,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        subjectTitle: json['subjectTitle'] as String,
      );

  /// Parse "HH:mm" into a DateTime on [date].
  DateTime startDateTime(DateTime date) {
    final parts = startTime.split(':');
    return DateTime(date.year, date.month, date.day,
        int.parse(parts[0]), int.parse(parts[1]));
  }

  DateTime endDateTime(DateTime date) {
    final parts = endTime.split(':');
    return DateTime(date.year, date.month, date.day,
        int.parse(parts[0]), int.parse(parts[1]));
  }

  static const _dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String get dayName => _dayNames[dayOfWeek];
}

/// Key academic dates the user can configure.
class AcademicDates {
  final DateTime? isa1;
  final DateTime? isa2;
  final DateTime? esa;
  final DateTime? lwd;

  AcademicDates({this.isa1, this.isa2, this.esa, this.lwd});

  Map<String, dynamic> toJson() => {
        'isa1': isa1?.toIso8601String(),
        'isa2': isa2?.toIso8601String(),
        'esa': esa?.toIso8601String(),
        'lwd': lwd?.toIso8601String(),
      };

  factory AcademicDates.fromJson(Map<String, dynamic> json) => AcademicDates(
        isa1: json['isa1'] != null ? DateTime.parse(json['isa1'] as String) : null,
        isa2: json['isa2'] != null ? DateTime.parse(json['isa2'] as String) : null,
        esa: json['esa'] != null ? DateTime.parse(json['esa'] as String) : null,
        lwd: json['lwd'] != null ? DateTime.parse(json['lwd'] as String) : null,
      );

  String toJsonString() => jsonEncode(toJson());

  factory AcademicDates.fromJsonString(String s) =>
      AcademicDates.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Returns the nearest upcoming event label and date, or null.
  ({String label, DateTime date})? get nextEvent {
    final now = DateTime.now();
    final events = <({String label, DateTime date})>[
      if (isa1 != null && isa1!.isAfter(now)) (label: 'ISA-1', date: isa1!),
      if (isa2 != null && isa2!.isAfter(now)) (label: 'ISA-2', date: isa2!),
      if (esa != null && esa!.isAfter(now)) (label: 'ESA', date: esa!),
      if (lwd != null && lwd!.isAfter(now)) (label: 'LWD', date: lwd!),
    ];
    if (events.isEmpty) return null;
    events.sort((a, b) => a.date.compareTo(b.date));
    return events.first;
  }
}

/// Serialise/deserialise a full weekly timetable.
class Timetable {
  final List<ClassSlot> slots;

  Timetable({required this.slots});

  String toJsonString() =>
      jsonEncode(slots.map((s) => s.toJson()).toList());

  factory Timetable.fromJsonString(String s) {
    final list = jsonDecode(s) as List;
    return Timetable(
      slots: list.map((e) => ClassSlot.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Today's classes, sorted by start time.
  List<ClassSlot> todayClasses() {
    final dow = DateTime.now().weekday; // 1=Mon .. 7=Sun
    return slots.where((s) => s.dayOfWeek == dow).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// The next upcoming class today, or null if all done / no classes.
  ClassSlot? nextClass() {
    final now = DateTime.now();
    final today = todayClasses();
    for (final slot in today) {
      if (slot.startDateTime(now).isAfter(now)) return slot;
      if (slot.endDateTime(now).isAfter(now)) return slot; // currently ongoing
    }
    return null;
  }
}
