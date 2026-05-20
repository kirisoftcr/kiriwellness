import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettings {
  /// Minutes of rest between appointments
  final int breakMinutes;
  /// How many hours before an appointment a client can still cancel
  final int cancellationHoursLimit;
  /// Allow same-day bookings
  final bool allowSameDayBooking;
  /// Emails that receive appointment notifications
  final List<String> adminEmails;

  const AppSettings({
    this.breakMinutes = 30,
    this.cancellationHoursLimit = 24,
    this.allowSameDayBooking = true,
    this.adminEmails = const [],
  });

  factory AppSettings.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppSettings(
      breakMinutes: (d['breakMinutes'] as num?)?.toInt() ?? 30,
      cancellationHoursLimit:
          (d['cancellationHoursLimit'] as num?)?.toInt() ?? 24,
      allowSameDayBooking: d['allowSameDayBooking'] as bool? ?? true,
      adminEmails: List<String>.from(
          (d['adminEmails'] as List?)?.map((e) => e.toString()) ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'breakMinutes': breakMinutes,
        'cancellationHoursLimit': cancellationHoursLimit,
        'allowSameDayBooking': allowSameDayBooking,
        'adminEmails': adminEmails,
      };

  AppSettings copyWith({
    int? breakMinutes,
    int? cancellationHoursLimit,
    bool? allowSameDayBooking,
    List<String>? adminEmails,
  }) {
    return AppSettings(
      breakMinutes: breakMinutes ?? this.breakMinutes,
      cancellationHoursLimit:
          cancellationHoursLimit ?? this.cancellationHoursLimit,
      allowSameDayBooking: allowSameDayBooking ?? this.allowSameDayBooking,
      adminEmails: adminEmails ?? this.adminEmails,
    );
  }
}
