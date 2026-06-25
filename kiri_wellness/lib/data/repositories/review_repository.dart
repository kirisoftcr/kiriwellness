import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_firebase.dart';
import '../../shared/models/review_model.dart';

class ReviewRepository {
  final FirebaseFirestore _db;

  ReviewRepository({FirebaseFirestore? db})
      : _db = db ?? AppFirebase.firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('reviews');

  /// Stream de todas las reseñas (para el panel de admin).
  Stream<List<ReviewModel>> watchAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ReviewModel.fromFirestore).toList());
  }

  /// Stream únicamente de las reseñas aprobadas (para la landing).
  Stream<List<ReviewModel>> watchApproved() {
    return _col
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ReviewModel.fromFirestore).toList());
  }

  /// Envía una nueva reseña (estado inicial: pendiente).
  Future<void> submit({
    required String clientName,
    required String clientLastName,
    required String reviewText,
    required double rating,
  }) async {
    await _col.doc().set(
          ReviewModel(
            id: '',
            clientName: clientName.trim(),
            clientLastName: clientLastName.trim(),
            reviewText: reviewText.trim(),
            rating: rating,
            status: ReviewStatus.pending,
            createdAt: DateTime.now(),
          ).toFirestore(),
        );
  }

  /// Aprueba una reseña (la hace visible en la landing).
  Future<void> approve(String id) async {
    await _col.doc(id).update({'status': ReviewStatus.approved.name});
  }

  /// Rechaza una reseña (no se mostrará en la landing).
  Future<void> reject(String id) async {
    await _col.doc(id).update({'status': ReviewStatus.rejected.name});
  }

  /// Elimina permanentemente una reseña.
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(),
);

/// Todas las reseñas — usado en el panel admin.
final allReviewsStreamProvider = StreamProvider<List<ReviewModel>>(
  (ref) => ref.watch(reviewRepositoryProvider).watchAll(),
);

/// Solo reseñas aprobadas — usado en la landing.
final approvedReviewsStreamProvider = StreamProvider<List<ReviewModel>>(
  (ref) => ref.watch(reviewRepositoryProvider).watchApproved(),
);
