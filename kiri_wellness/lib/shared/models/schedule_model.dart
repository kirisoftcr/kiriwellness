import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single availability time block for a given day of the week.
class ScheduleModel {
  final String id;

  /// 1 = Monday … 7 = Sunday  (ISO weekday)
  final int dayOfWeek;

  /// "HH:mm" 24h format, e.g. "08:00"
  final String startTime;

  /// "HH:mm" 24h format, e.g. "12:00"
  final String endTime;

  final bool isActive;

  const ScheduleModel({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  // ---------------------------------------------------------------------------
  // Day label helpers
  // ---------------------------------------------------------------------------

  static const _dayNames = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };

  String get dayName => _dayNames[dayOfWeek] ?? 'Día $dayOfWeek';

  String get timeRange => '$startTime – $endTime';

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ScheduleModel(
      id: doc.id,
      dayOfWeek: (d['dayOfWeek'] as num).toInt(),
      startTime: d['startTime'] as String? ?? '08:00',
      endTime: d['endTime'] as String? ?? '17:00',
      isActive: d['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'isActive': isActive,
      };

  ScheduleModel copyWith({
    String? id,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isActive,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
    );
  }
}
