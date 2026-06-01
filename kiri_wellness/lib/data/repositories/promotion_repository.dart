import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_firebase.dart';
import '../../shared/models/promotion_model.dart';

class PromotionRepository {
  final FirebaseFirestore _db;

  PromotionRepository({FirebaseFirestore? db})
      : _db = db ?? AppFirebase.firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('promotions');

  Stream<List<PromotionModel>> watchAll() {
    return _col
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PromotionModel.fromFirestore).toList());
  }

  Stream<List<PromotionModel>> watchActive() {
    final now = Timestamp.now();
    return _col
        .where('isActive', isEqualTo: true)
        .where('endDate', isGreaterThanOrEqualTo: now)
        .orderBy('endDate')
        .snapshots()
        .map((s) => s.docs.map(PromotionModel.fromFirestore).toList());
  }

  Future<void> create(PromotionModel promo) async {
    await _col.doc().set(promo.toFirestore());
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _col.doc(id).update(data);
  }

  Future<void> setActive(String id, bool active) async {
    await _col.doc(id).update({'isActive': active});
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final promotionRepositoryProvider = Provider<PromotionRepository>(
  (ref) => PromotionRepository(),
);

final promotionsStreamProvider = StreamProvider<List<PromotionModel>>(
  (ref) => ref.watch(promotionRepositoryProvider).watchAll(),
);
