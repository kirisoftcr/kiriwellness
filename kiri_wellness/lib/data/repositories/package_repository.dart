import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/package_model.dart';

class PackageRepository {
  final FirebaseFirestore _db;
  late final FirebaseFunctions _functions;

  PackageRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance {
    _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');
  }

  CollectionReference<Map<String, dynamic>> get _packagesCol =>
      _db.collection('packages');

  CollectionReference<Map<String, dynamic>> get _clientPackagesCol =>
      _db.collection('client_packages');

  // ── Package catalog ─────────────────────────────────────────────────────

  Stream<List<PackageModel>> watchAll() {
    return _packagesCol
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(PackageModel.fromFirestore).toList());
  }

  Future<String> create(PackageModel pkg) async {
    final callable = _functions.httpsCallable('createPackage');
    final result = await callable.call({
      'name': pkg.name,
      'description': pkg.description,
      'price': pkg.price,
      'services': pkg.services.map((s) => s.toMap()).toList(),
      'discountPercent': pkg.discountPercent,
      'validityDays': pkg.validityDays,
    });
    return result.data['id'] as String;
  }

  Future<void> update(String id, PackageModel pkg) async {
    final callable = _functions.httpsCallable('updatePackage');
    await callable.call({
      'id': id,
      'name': pkg.name,
      'description': pkg.description,
      'price': pkg.price,
      'services': pkg.services.map((s) => s.toMap()).toList(),
      'discountPercent': pkg.discountPercent,
      'validityDays': pkg.validityDays,
      'isActive': pkg.isActive,
    });
  }

  Future<void> delete(String id) async {
    final callable = _functions.httpsCallable('deletePackage');
    await callable.call({'id': id});
  }

  // ── Client packages ─────────────────────────────────────────────────────

  Stream<List<ClientPackageModel>> watchClientPackages(String clientId) {
    return _clientPackagesCol
        .where('clientId', isEqualTo: clientId)
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ClientPackageModel.fromFirestore).toList());
  }

  Future<String> assignPackageToClient({
    required String clientId,
    required String packageId,
  }) async {
    final callable = _functions.httpsCallable('assignPackageToClient');
    final result = await callable.call({'clientId': clientId, 'packageId': packageId});
    return result.data['id'] as String;
  }

  Stream<List<ClientPackageModel>> watchAllActiveClientPackages() {
    final now = Timestamp.now();
    return _clientPackagesCol
        .where('expiresAt', isGreaterThan: now)
        .snapshots()
        .map((s) => s.docs
            .map(ClientPackageModel.fromFirestore)
            .where((cp) => cp.remainingSessions > 0)
            .toList());
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final packageRepositoryProvider = Provider<PackageRepository>(
  (ref) => PackageRepository(),
);

final packagesStreamProvider = StreamProvider<List<PackageModel>>(
  (ref) => ref.watch(packageRepositoryProvider).watchAll(),
);

final clientPackagesStreamProvider =
    StreamProvider.family<List<ClientPackageModel>, String>((ref, clientId) {
  return ref.watch(packageRepositoryProvider).watchClientPackages(clientId);
});

final allActiveClientPackagesStreamProvider =
    StreamProvider<List<ClientPackageModel>>((ref) {
  return ref.watch(packageRepositoryProvider).watchAllActiveClientPackages();
});
