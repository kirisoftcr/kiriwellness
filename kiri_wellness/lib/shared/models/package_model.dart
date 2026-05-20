import 'package:cloud_firestore/cloud_firestore.dart';

class PackageModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int totalSessions;
  final List<String> serviceIds;
  final List<String> serviceNames;
  final double discountPercent;
  final int validityDays;
  final bool isActive;
  final String? imageUrl;

  const PackageModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.totalSessions,
    required this.serviceIds,
    required this.serviceNames,
    required this.discountPercent,
    required this.validityDays,
    this.isActive = true,
    this.imageUrl,
  });

  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PackageModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      totalSessions: data['totalSessions'] ?? 1,
      serviceIds: List<String>.from(data['serviceIds'] ?? []),
      serviceNames: List<String>.from(data['serviceNames'] ?? []),
      discountPercent: (data['discountPercent'] ?? 0).toDouble(),
      validityDays: data['validityDays'] ?? 30,
      isActive: data['isActive'] ?? true,
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'price': price,
    'totalSessions': totalSessions,
    'serviceIds': serviceIds,
    'serviceNames': serviceNames,
    'discountPercent': discountPercent,
    'validityDays': validityDays,
    'isActive': isActive,
    'imageUrl': imageUrl,
  };
}

/// Paquete comprado por un cliente
class ClientPackageModel {
  final String id;
  final String clientId;
  final String packageId;
  final String packageName;
  final int totalSessions;
  final int usedSessions;
  final DateTime purchasedAt;
  final DateTime expiresAt;

  const ClientPackageModel({
    required this.id,
    required this.clientId,
    required this.packageId,
    required this.packageName,
    required this.totalSessions,
    required this.usedSessions,
    required this.purchasedAt,
    required this.expiresAt,
  });

  int get remainingSessions => totalSessions - usedSessions;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory ClientPackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClientPackageModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      packageId: data['packageId'] ?? '',
      packageName: data['packageName'] ?? '',
      totalSessions: data['totalSessions'] ?? 0,
      usedSessions: data['usedSessions'] ?? 0,
      purchasedAt: (data['purchasedAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'clientId': clientId,
    'packageId': packageId,
    'packageName': packageName,
    'totalSessions': totalSessions,
    'usedSessions': usedSessions,
    'purchasedAt': Timestamp.fromDate(purchasedAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
  };
}
