import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;
  final String? imageUrl;
  final String category;
  final bool isActive;
  final List<String> benefits;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    this.imageUrl,
    required this.category,
    this.isActive = true,
    this.benefits = const [],
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      durationMinutes: data['durationMinutes'] ?? 60,
      imageUrl: data['imageUrl'],
      category: data['category'] ?? 'General',
      isActive: data['isActive'] ?? true,
      benefits: List<String>.from(data['benefits'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'price': price,
    'durationMinutes': durationMinutes,
    'imageUrl': imageUrl,
    'category': category,
    'isActive': isActive,
    'benefits': benefits,
  };
}
