import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/package_model.dart';

class PackageRepository {
  final FirebaseFirestore _db;

  PackageRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _packagesCol =>
      _db.collection('packages');

  CollectionReference<Map<String, dynamic>> get _clientPackagesCol =>
      _db.collection('client_packages');

  // Packages (catalog)
  Stream<List<PackageModel>> watchAll() {
    return _packagesCol
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(PackageModel.fromFirestore).toList());
  }

  Future<void> create(PackageModel pkg) async {
    await _packagesCol.doc().set(pkg.toFirestore());
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _packagesCol.doc(id).update(data);
  }

  // Client packages
  Stream<List<ClientPackageModel>> watchClientPackages(String clientId) {
    return _clientPackagesCol
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((s) => s.docs.map(ClientPackageModel.fromFirestore).toList());
  }

  Future<void> assignPackageToClient(ClientPackageModel cp) async {
    await _clientPackagesCol.doc().set(cp.toFirestore());
  }

  /// All client packages that are not expired and have sessions remaining.
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

  Future<void> useSession(String clientPackageId) async {
    await _db.runTransaction((tx) async {
      final ref = _clientPackagesCol.doc(clientPackageId);
      final snap = await tx.get(ref);
      final used = (snap.data()?['usedSessions'] ?? 0) as int;
      tx.update(ref, {'usedSessions': used + 1});
    });
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

final allActiveClientPackagesStreamProvider =
    StreamProvider<List<ClientPackageModel>>((ref) {
  return ref.watch(packageRepositoryProvider).watchAllActiveClientPackages();
});
