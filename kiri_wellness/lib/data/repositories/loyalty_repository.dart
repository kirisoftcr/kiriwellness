import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/loyalty_model.dart';

class LoyaltyRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  LoyaltyRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: "us-central1");

  DocumentReference<Map<String, dynamic>> get _configDoc =>
      _db.collection('settings').doc('loyalty');

  CollectionReference<Map<String, dynamic>> _rewardsCol(String clientId) =>
      _db.collection('clients').doc(clientId).collection('rewards');

  // ── Loyalty Configuration ─────────────────────────────────────────────────

  /// Stream de la configuración global del programa de regalías
  Stream<LoyaltyConfig> watchConfig() {
    return _configDoc.snapshots().map((snap) {
      if (!snap.exists) return const LoyaltyConfig();
      return LoyaltyConfig.fromFirestore(snap);
    });
  }

  Future<LoyaltyConfig> getConfig() async {
    final snap = await _configDoc.get();
    if (!snap.exists) return const LoyaltyConfig();
    return LoyaltyConfig.fromFirestore(snap);
  }

  /// Guarda la configuración completa del programa (vía Cloud Function para
  /// que quede auditable y bajo autenticación de admin)
  Future<void> saveConfig(LoyaltyConfig config) async {
    await _functions.httpsCallable('updateLoyaltySettings').call(
          config.toFirestore(),
        );
  }

  // ── Client Rewards ────────────────────────────────────────────────────────

  /// Stream de regalías de un cliente, ordenadas por fecha
  Stream<List<ClientReward>> watchClientRewards(String clientId) {
    return _rewardsCol(clientId)
        .orderBy('earnedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ClientReward.fromFirestore).toList());
  }

  /// Regalías pendientes de un cliente
  Stream<List<ClientReward>> watchPendingRewards(String clientId) {
    return _rewardsCol(clientId)
        .where('status', isEqualTo: 'pending')
        .orderBy('earnedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ClientReward.fromFirestore).toList());
  }

  /// Canjear una regalía (marca como redeemed y la asocia a una cita)
  Future<void> redeemReward({
    required String clientId,
    required String rewardId,
    required String appointmentId,
  }) async {
    await _functions.httpsCallable('redeemLoyaltyReward').call({
      'clientId': clientId,
      'rewardId': rewardId,
      'appointmentId': appointmentId,
    });
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>(
  (_) => LoyaltyRepository(),
);

final loyaltyConfigStreamProvider = StreamProvider<LoyaltyConfig>((ref) {
  return ref.watch(loyaltyRepositoryProvider).watchConfig();
});

final clientRewardsProvider =
    StreamProvider.family<List<ClientReward>, String>((ref, clientId) {
  return ref.watch(loyaltyRepositoryProvider).watchClientRewards(clientId);
});

final clientPendingRewardsProvider =
    StreamProvider.family<List<ClientReward>, String>((ref, clientId) {
  return ref.watch(loyaltyRepositoryProvider).watchPendingRewards(clientId);
});
