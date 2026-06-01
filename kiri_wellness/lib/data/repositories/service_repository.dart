import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_firebase.dart';
import '../../shared/models/service_model.dart';

class ServiceRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  ServiceRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? AppFirebase.firestore,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: "us-central1");

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('services');

  // -------------------------------------------------------------------------
  // Read (direct Firestore — real-time stream)
  // -------------------------------------------------------------------------

  Stream<List<ServiceModel>> watchActive() {
    return _col
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs
            .map(ServiceModel.fromFirestore)
            .where((s) => s.isActive)
            .toList());
  }

  Stream<List<ServiceModel>> watchAll() {
    return _col
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(ServiceModel.fromFirestore).toList());
  }

  Future<List<ServiceModel>> getActive() async {
    final snap = await _col.orderBy('name').get();
    return snap.docs
        .map(ServiceModel.fromFirestore)
        .where((s) => s.isActive)
        .toList();
  }

  // -------------------------------------------------------------------------
  // Write (via Cloud Functions — uses Admin SDK, bypasses rules)
  // -------------------------------------------------------------------------

  Future<void> create(ServiceModel service) async {
    await _functions.httpsCallable('createService').call(service.toFirestore());
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _functions
        .httpsCallable('updateService')
        .call({'id': id, ...data});
  }

  Future<void> setActive(String id, bool active) async {
    await _functions
        .httpsCallable('updateService')
        .call({'id': id, 'isActive': active});
  }

  Future<void> delete(String id) async {
    await _functions.httpsCallable('deleteService').call({'id': id});
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(),
);

final activeServicesStreamProvider = StreamProvider<List<ServiceModel>>(
  (ref) => ref.watch(serviceRepositoryProvider).watchActive(),
);

final allServicesStreamProvider = StreamProvider<List<ServiceModel>>(
  (ref) => ref.watch(serviceRepositoryProvider).watchAll(),
);
