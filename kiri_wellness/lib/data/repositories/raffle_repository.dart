import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_firebase.dart';
import '../../shared/models/raffle_model.dart';

class RaffleRepository {
  final FirebaseFirestore _db;

  RaffleRepository({FirebaseFirestore? db})
      : _db = db ?? AppFirebase.firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('raffles');

  Stream<List<RaffleModel>> watchAll() {
    return _col
        .orderBy('drawDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(RaffleModel.fromFirestore).toList());
  }

  Future<void> create(RaffleModel raffle) async {
    await _col.doc().set(raffle.toFirestore());
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _col.doc(id).update(data);
  }

  // Tickets sub-collection
  CollectionReference<Map<String, dynamic>> _tickets(String raffleId) =>
      _col.doc(raffleId).collection('tickets');

  Stream<List<RaffleTicketModel>> watchTickets(String raffleId) {
    return _tickets(raffleId)
        .snapshots()
        .map((s) => s.docs.map(RaffleTicketModel.fromFirestore).toList());
  }

  Future<void> addTicket(String raffleId, RaffleTicketModel ticket) async {
    await _tickets(raffleId).doc().set(ticket.toFirestore());
  }

  Future<void> pickWinner(String raffleId, String ticketId) async {
    await _col.doc(raffleId).update({
      'winnerId': ticketId,
      'isActive': false,
    });
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final raffleRepositoryProvider = Provider<RaffleRepository>(
  (ref) => RaffleRepository(),
);

final rafflesStreamProvider = StreamProvider<List<RaffleModel>>(
  (ref) => ref.watch(raffleRepositoryProvider).watchAll(),
);
