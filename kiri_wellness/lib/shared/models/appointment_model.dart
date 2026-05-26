import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus {
  requested,   // Solicitada (cliente o admin)
  confirmed,   // Confirmada (cliente o admin)
  cancelled,   // Cancelada (cliente o admin)
  completed,   // Completada (solo admin)
}

extension AppointmentStatusX on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.requested:  return 'Solicitada';
      case AppointmentStatus.confirmed:  return 'Confirmada';
      case AppointmentStatus.cancelled:  return 'Cancelada';
      case AppointmentStatus.completed:  return 'Completada';
    }
  }

  static AppointmentStatus fromString(String? s) {
    switch (s) {
      case 'confirmed':  return AppointmentStatus.confirmed;
      case 'cancelled':  return AppointmentStatus.cancelled;
      case 'completed':  return AppointmentStatus.completed;
      default:           return AppointmentStatus.requested;
    }
  }
}

class AppointmentModel {
  final String id;
  final String clientId;
  final String clientName;
  final String clientLastName;
  final String clientEmail;
  final String clientPhone;
  final String clientCode;
  final String serviceId;
  final String serviceName;
  final int serviceDurationMin;
  final double servicePrice;
  /// "YYYY-MM-DD"
  final String date;
  /// "HH:mm" 24h
  final String time;
  final String notes;
  final AppointmentStatus status;
  final DateTime? createdAt;
  final bool isReward;

  const AppointmentModel({
    required this.id,
    required this.clientId,
    this.clientName = '',
    this.clientLastName = '',
    this.clientEmail = '',
    this.clientPhone = '',
    this.clientCode = '',
    required this.serviceId,
    required this.serviceName,
    required this.serviceDurationMin,
    required this.servicePrice,
    required this.date,
    required this.time,
    this.notes = '',
    required this.status,
    this.createdAt,
    this.isReward = false,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppointmentModel(
      id: doc.id,
      clientId: d['clientId'] as String? ?? '',
      clientName: d['clientName'] as String? ?? '',
      clientLastName: d['clientLastName'] as String? ?? '',
      clientEmail: d['clientEmail'] as String? ?? '',
      clientPhone: d['clientPhone'] as String? ?? '',
      clientCode: d['clientCode'] as String? ?? '',
      serviceId: d['serviceId'] as String? ?? '',
      serviceName: d['serviceName'] as String? ?? '',
      serviceDurationMin: (d['serviceDurationMin'] as num?)?.toInt() ?? 60,
      servicePrice: (d['servicePrice'] as num?)?.toDouble() ?? 0,
      date: d['date'] as String? ?? '',
      time: d['time'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      status: AppointmentStatusX.fromString(d['status'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      isReward: d['isReward'] as bool? ?? false,
    );
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> d, String id) {
    return AppointmentModel(
      id: id,
      clientId: d['clientId'] as String? ?? '',
      clientName: d['clientName'] as String? ?? '',
      clientLastName: d['clientLastName'] as String? ?? '',
      clientEmail: d['clientEmail'] as String? ?? '',
      clientPhone: d['clientPhone'] as String? ?? '',
      clientCode: d['clientCode'] as String? ?? '',
      serviceId: d['serviceId'] as String? ?? '',
      serviceName: d['serviceName'] as String? ?? '',
      serviceDurationMin: (d['serviceDurationMin'] as num?)?.toInt() ?? 60,
      servicePrice: (d['servicePrice'] as num?)?.toDouble() ?? 0,
      date: d['date'] as String? ?? '',
      time: d['time'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      status: AppointmentStatusX.fromString(d['status'] as String?),
      createdAt: null,
      isReward: d['isReward'] as bool? ?? false,
    );
  }

  /// Whether this appointment can still be cancelled
  bool get isCancellable =>
      status == AppointmentStatus.requested ||
      status == AppointmentStatus.confirmed;

  String get fullClientName =>
      [clientName, clientLastName].where((s) => s.isNotEmpty).join(' ');

  String get displayTime {
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final amPm = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:${minute.toString().padLeft(2, '0')} $amPm';
  }

  AppointmentModel copyWith({AppointmentStatus? status, String? notes}) {
    return AppointmentModel(
      id: id,
      clientId: clientId,
      clientName: clientName,
      clientLastName: clientLastName,
      clientEmail: clientEmail,
      clientPhone: clientPhone,
      clientCode: clientCode,
      serviceId: serviceId,
      serviceName: serviceName,
      serviceDurationMin: serviceDurationMin,
      servicePrice: servicePrice,
      date: date,
      time: time,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
      isReward: isReward,
    );
  }
}
