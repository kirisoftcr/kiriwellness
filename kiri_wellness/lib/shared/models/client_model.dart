import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String id;
  final String clientCode; // KW-00001
  final String name;
  final String lastName;
  final String phone;
  final String? email;
  final DateTime? birthDate;
  final String? notes;
  final HealthFormModel? healthForm;
  final int loyaltyPoints;
  final DateTime createdAt;
  final String? photoUrl;

  const ClientModel({
    required this.id,
    required this.clientCode,
    required this.name,
    required this.lastName,
    required this.phone,
    this.email,
    this.birthDate,
    this.notes,
    this.healthForm,
    this.loyaltyPoints = 0,
    required this.createdAt,
    this.photoUrl,
  });

  String get fullName => '$name $lastName';

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClientModel(
      id: doc.id,
      clientCode: data['clientCode'] ?? '',
      name: data['name'] ?? data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      birthDate: data['birthDate'] != null
          ? (data['birthDate'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
      healthForm: data['healthForm'] != null
          ? HealthFormModel.fromMap(data['healthForm'])
          : null,
      loyaltyPoints: data['loyaltyPoints'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'clientCode': clientCode,
    'name': name,
    'lastName': lastName,
    'phone': phone,
    'email': email,
    'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
    'notes': notes,
    'healthForm': healthForm?.toMap(),
    'loyaltyPoints': loyaltyPoints,
    'createdAt': Timestamp.fromDate(createdAt),
    'photoUrl': photoUrl,
  };
}

class HealthFormModel {
  final List<String> conditions;
  final List<String> allergies;
  final String? medications;
  final String? injuries;
  final String pressurePreference;
  final String? additionalInfo;
  final DateTime completedAt;

  const HealthFormModel({
    this.conditions = const [],
    this.allergies = const [],
    this.medications,
    this.injuries,
    this.pressurePreference = 'Medio',
    this.additionalInfo,
    required this.completedAt,
  });

  factory HealthFormModel.fromMap(Map<String, dynamic> data) {
    return HealthFormModel(
      conditions: List<String>.from(data['conditions'] ?? []),
      allergies: List<String>.from(data['allergies'] ?? []),
      medications: data['medications'],
      injuries: data['injuries'],
      pressurePreference: data['pressurePreference'] ?? 'Medio',
      additionalInfo: data['additionalInfo'],
      completedAt: (data['completedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'conditions': conditions,
    'allergies': allergies,
    'medications': medications,
    'injuries': injuries,
    'pressurePreference': pressurePreference,
    'additionalInfo': additionalInfo,
    'completedAt': Timestamp.fromDate(completedAt),
  };
}
