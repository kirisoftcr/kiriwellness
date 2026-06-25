import 'package:cloud_firestore/cloud_firestore.dart';

/// Status de una reseña de cliente.
enum ReviewStatus { pending, approved, rejected }

/// Modelo de reseña/testimonial de cliente.
class ReviewModel {
  final String id;
  final String clientName;
  final String clientLastName;
  final String reviewText;
  final double rating; // 1 – 5
  final ReviewStatus status;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.clientName,
    required this.clientLastName,
    required this.reviewText,
    this.rating = 5,
    this.status = ReviewStatus.pending,
    required this.createdAt,
  });

  /// Nombre público: "Fabian V."
  String get displayName {
    final first = clientName.trim();
    final last = clientLastName.trim();
    if (last.isEmpty) return first;
    return '$first ${last[0].toUpperCase()}.';
  }

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      clientName: data['clientName'] ?? '',
      clientLastName: data['clientLastName'] ?? '',
      reviewText: data['reviewText'] ?? '',
      rating: (data['rating'] ?? 5).toDouble(),
      status: _statusFromString(data['status']),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'clientName': clientName,
        'clientLastName': clientLastName,
        'reviewText': reviewText,
        'rating': rating,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  ReviewModel copyWith({
    String? id,
    String? clientName,
    String? clientLastName,
    String? reviewText,
    double? rating,
    ReviewStatus? status,
    DateTime? createdAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      clientLastName: clientLastName ?? this.clientLastName,
      reviewText: reviewText ?? this.reviewText,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static ReviewStatus _statusFromString(dynamic value) {
    switch (value) {
      case 'approved':
        return ReviewStatus.approved;
      case 'rejected':
        return ReviewStatus.rejected;
      default:
        return ReviewStatus.pending;
    }
  }

  /// Handles both Firestore [Timestamp] and legacy [int] (millisecondsSinceEpoch).
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
