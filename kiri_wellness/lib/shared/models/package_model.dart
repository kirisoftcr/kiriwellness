import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PackageService — one service line inside a package catalog entry
// ─────────────────────────────────────────────────────────────────────────────

class PackageService {
  final String serviceId;
  final String serviceName;
  final int sessionCount;

  const PackageService({
    required this.serviceId,
    required this.serviceName,
    required this.sessionCount,
  });

  factory PackageService.fromMap(Map<String, dynamic> m) => PackageService(
        serviceId: m['serviceId'] as String? ?? '',
        serviceName: m['serviceName'] as String? ?? '',
        sessionCount: (m['sessionCount'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'serviceId': serviceId,
        'serviceName': serviceName,
        'sessionCount': sessionCount,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// PackageModel — catalog entry (admin creates these)
// ─────────────────────────────────────────────────────────────────────────────

class PackageModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<PackageService> services;
  final double discountPercent;
  final int validityDays;
  final bool isActive;

  const PackageModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.services,
    required this.discountPercent,
    required this.validityDays,
    this.isActive = true,
  });

  int get totalSessions =>
      services.fold(0, (sum, s) => sum + s.sessionCount);

  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PackageModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      services: (data['services'] as List<dynamic>? ?? [])
          .map((e) => PackageService.fromMap(e as Map<String, dynamic>))
          .toList(),
      discountPercent: (data['discountPercent'] as num?)?.toDouble() ?? 0,
      validityDays: (data['validityDays'] as num?)?.toInt() ?? 30,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'description': description,
        'price': price,
        'services': services.map((s) => s.toMap()).toList(),
        'discountPercent': discountPercent,
        'validityDays': validityDays,
        'isActive': isActive,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// ClientPackageService — per-service session tracking within a client package
// ─────────────────────────────────────────────────────────────────────────────

class ClientPackageService {
  final String serviceId;
  final String serviceName;
  final int totalSessions;
  final int usedSessions;

  const ClientPackageService({
    required this.serviceId,
    required this.serviceName,
    required this.totalSessions,
    required this.usedSessions,
  });

  int get remainingSessions => totalSessions - usedSessions;
  bool get isComplete => usedSessions >= totalSessions;

  factory ClientPackageService.fromMap(Map<String, dynamic> m) =>
      ClientPackageService(
        serviceId: m['serviceId'] as String? ?? '',
        serviceName: m['serviceName'] as String? ?? '',
        totalSessions: (m['totalSessions'] as num?)?.toInt() ?? 0,
        usedSessions: (m['usedSessions'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'serviceId': serviceId,
        'serviceName': serviceName,
        'totalSessions': totalSessions,
        'usedSessions': usedSessions,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// ClientPackageModel — package assigned to a specific client
// ─────────────────────────────────────────────────────────────────────────────

enum ClientPackageStatus { active, completed, expired, pending, rejected }

class ClientPackageModel {
  final String id;
  final String clientId;
  final String packageId;
  final String packageName;
  final String packageDescription;
  final List<ClientPackageService> services;
  final int totalSessions;
  final int usedSessions;
  final DateTime purchasedAt;
  final DateTime expiresAt;
  final ClientPackageStatus status;
  final String requestNotes;
  final String rejectReason;
  final String clientFirstName;
  final String clientLastName;
  final String clientEmail;
  final String clientPhone;

  const ClientPackageModel({
    required this.id,
    required this.clientId,
    required this.packageId,
    required this.packageName,
    this.packageDescription = '',
    required this.services,
    required this.totalSessions,
    required this.usedSessions,
    required this.purchasedAt,
    required this.expiresAt,
    this.status = ClientPackageStatus.active,
    this.requestNotes = '',
    this.rejectReason = '',
    this.clientFirstName = '',
    this.clientLastName = '',
    this.clientEmail = '',
    this.clientPhone = '',
  });

  int get remainingSessions => totalSessions - usedSessions;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isComplete => usedSessions >= totalSessions;

  factory ClientPackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    ClientPackageStatus parseStatus(String? s) {
      switch (s) {
        case 'completed':
          return ClientPackageStatus.completed;
        case 'expired':
          return ClientPackageStatus.expired;
        case 'pending':
          return ClientPackageStatus.pending;
        case 'rejected':
          return ClientPackageStatus.rejected;
        default:
          return ClientPackageStatus.active;
      }
    }

    return ClientPackageModel(
      id: doc.id,
      clientId: data['clientId'] as String? ?? '',
      packageId: data['packageId'] as String? ?? '',
      packageName: data['packageName'] as String? ?? '',
      packageDescription: data['packageDescription'] as String? ?? '',
      services: (data['services'] as List<dynamic>? ?? [])
          .map((e) => ClientPackageService.fromMap(e as Map<String, dynamic>))
          .toList(),
      totalSessions: (data['totalSessions'] as num?)?.toInt() ?? 0,
      usedSessions: (data['usedSessions'] as num?)?.toInt() ?? 0,
      purchasedAt: (data['purchasedAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      status: parseStatus(data['status'] as String?),
      requestNotes: data['requestNotes'] as String? ?? '',
      rejectReason: data['rejectReason'] as String? ?? '',
      clientFirstName: data['clientFirstName'] as String? ?? '',
      clientLastName: data['clientLastName'] as String? ?? '',
      clientEmail: data['clientEmail'] as String? ?? '',
      clientPhone: data['clientPhone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'clientId': clientId,
        'packageId': packageId,
        'packageName': packageName,
        'packageDescription': packageDescription,
        'services': services.map((s) => s.toMap()).toList(),
        'totalSessions': totalSessions,
        'usedSessions': usedSessions,
        'purchasedAt': Timestamp.fromDate(purchasedAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'status': status.name,
      };
}
