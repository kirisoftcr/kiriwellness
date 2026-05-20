import 'package:cloud_firestore/cloud_firestore.dart';

enum PromotionType { percentage, fixedAmount, freeSession }

class PromotionModel {
  final String id;
  final String title;
  final String description;
  final PromotionType type;
  final double value;
  final String? code;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int? maxUses;
  final int usedCount;
  final List<String> applicableServiceIds;

  const PromotionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.value,
    this.code,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.maxUses,
    this.usedCount = 0,
    this.applicableServiceIds = const [],
  });

  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isValid => isActive && !isExpired && (maxUses == null || usedCount < maxUses!);

  factory PromotionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromotionModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: PromotionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => PromotionType.percentage,
      ),
      value: (data['value'] ?? 0).toDouble(),
      code: data['code'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      maxUses: data['maxUses'],
      usedCount: data['usedCount'] ?? 0,
      applicableServiceIds: List<String>.from(data['applicableServiceIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'type': type.name,
    'value': value,
    'code': code,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'isActive': isActive,
    'maxUses': maxUses,
    'usedCount': usedCount,
    'applicableServiceIds': applicableServiceIds,
  };
}
