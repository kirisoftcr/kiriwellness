import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_repository.dart';
import '../../shared/models/client_model.dart';

class ClientRepository {
  final FirebaseFirestore _db;

  ClientRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('clients');

  // -------------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------------

  Stream<List<ClientModel>> watchAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ClientModel.fromFirestore).toList());
  }

  Future<List<ClientModel>> getAll() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return snap.docs.map(ClientModel.fromFirestore).toList();
  }

  Future<ClientModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? ClientModel.fromFirestore(doc) : null;
  }

  /// Find a client by phone number (used to detect returning clients).
  Future<ClientModel?> findByPhone(String phone) async {
    final snap =
        await _col.where('phone', isEqualTo: phone.trim()).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return ClientModel.fromFirestore(snap.docs.first);
  }

  // -------------------------------------------------------------------------
  // Write
  // -------------------------------------------------------------------------

  /// Creates a new client with an auto-assigned KW-XXXXX code.
  /// Uses a Firestore transaction to guarantee unique sequential codes.
  Future<ClientModel> create({
    required String name,
    required String lastName,
    required String phone,
    String? email,
    String? notes,
  }) async {
    final counterRef = _db.collection('counters').doc('clients');
    final clientRef = _col.doc(); // pre-generate document ID

    late ClientModel newClient;

    await _db.runTransaction((tx) async {
      final counterSnap = await tx.get(counterRef);
      final int lastId = counterSnap.exists
          ? (counterSnap.data()?['lastId'] ?? 0) as int
          : 0;
      final int nextId = lastId + 1;
      final String clientCode =
          'KW-${nextId.toString().padLeft(5, '0')}';

      newClient = ClientModel(
        id: clientRef.id,
        clientCode: clientCode,
        name: name.trim(),
        lastName: lastName.trim(),
        phone: phone.trim(),
        email: email?.trim(),
        notes: notes?.trim(),
        createdAt: DateTime.now(),
      );

      tx.set(clientRef, newClient.toFirestore());
      tx.set(counterRef, {'lastId': nextId}, SetOptions(merge: true));
    });

    return newClient;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _col.doc(id).update(data);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepository(),
);

final clientsStreamProvider = StreamProvider<List<ClientModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(clientRepositoryProvider).watchAll();
});
