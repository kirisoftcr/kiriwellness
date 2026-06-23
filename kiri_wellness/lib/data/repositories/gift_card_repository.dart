import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_firebase.dart';
import '../../shared/models/gift_card_model.dart';

// ---------------------------------------------------------------------------
// GiftCardRepository
// ---------------------------------------------------------------------------

class GiftCardRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  GiftCardRepository({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  })  : _db = db ?? AppFirebase.firestore,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('gift_cards');

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<GiftCardModel>> watchAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GiftCardModel.fromFirestore).toList());
  }

  Stream<List<GiftCardModel>> watchByStatus(GiftCardStatus status) {
    return _col
        .where('status', isEqualTo: status.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GiftCardModel.fromFirestore).toList());
  }

  // ── Validation (for booking) ───────────────────────────────────────────────

  /// Returns the gift card if the code is valid and active, null otherwise.
  Future<GiftCardModel?> validateCode(String code) async {
    final snap = await _col
        .where('code', isEqualTo: code.trim().toUpperCase())
        .where('status', isEqualTo: GiftCardStatus.active.name)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return GiftCardModel.fromFirestore(snap.docs.first);
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Creates a single gift card document (without image yet).
  Future<String> create(GiftCardModel card) async {
    final ref = _col.doc();
    await ref.set(card.toFirestore());
    return ref.id;
  }

  /// Saves the Firebase Storage download URL for a card's image.
  Future<void> saveImageUrl(String cardId, String url) async {
    await _col.doc(cardId).update({'imageUrl': url});
  }

  /// Marks a card as [GiftCardStatus.active] and records the buyer name.
  Future<void> markAsActive(String cardId, {required String buyerName}) async {
    await _col.doc(cardId).update({
      'status': GiftCardStatus.active.name,
      'buyerName': buyerName,
      'activatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks a card as [GiftCardStatus.redeemed], links the appointment and
  /// deletes the image from Firebase Storage.
  Future<void> markAsRedeemed(
    String cardId, {
    required String appointmentId,
  }) async {
    // 1. Read current imageUrl to delete from storage
    final snap = await _col.doc(cardId).get();
    final imageUrl = (snap.data()?['imageUrl'] as String?);

    // 2. Update Firestore
    await _col.doc(cardId).update({
      'status': GiftCardStatus.redeemed.name,
      'appointmentId': appointmentId,
      'imageUrl': null,
      'redeemedAt': FieldValue.serverTimestamp(),
    });

    // 3. Delete image from Storage (best-effort)
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final storageRef = _storage.refFromURL(imageUrl);
        await storageRef.delete();
      } catch (_) {
        // Image may already be missing – ignore
      }
    }
  }

  // ── Image Storage ─────────────────────────────────────────────────────────

  /// Uploads PNG [bytes] for the given [cardId] and returns the download URL.
  Future<String> uploadImage(String cardId, List<int> bytes) async {
    final ref = _storage.ref('gift_cards/$cardId.png');
    final task = await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: 'image/png'),
    );
    return await task.ref.getDownloadURL();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final giftCardRepositoryProvider = Provider<GiftCardRepository>(
  (ref) => GiftCardRepository(),
);

final giftCardsStreamProvider = StreamProvider<List<GiftCardModel>>(
  (ref) => ref.watch(giftCardRepositoryProvider).watchAll(),
);

final giftCardsByStatusProvider =
    StreamProvider.family<List<GiftCardModel>, GiftCardStatus>(
  (ref, status) =>
      ref.watch(giftCardRepositoryProvider).watchByStatus(status),
);
