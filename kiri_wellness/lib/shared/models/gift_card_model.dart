import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Gift Card Status
// ---------------------------------------------------------------------------

enum GiftCardStatus {
  /// Generada – lista para ser vendida al público
  available,

  /// Vendida por el admin – el cliente puede usarla para agendar
  active,

  /// Canjeada – el servicio fue completado (la imagen se elimina del storage)
  redeemed,
}

extension GiftCardStatusX on GiftCardStatus {
  String get label {
    switch (this) {
      case GiftCardStatus.available:
        return 'Disponible';
      case GiftCardStatus.active:
        return 'Activa';
      case GiftCardStatus.redeemed:
        return 'Canjeada';
    }
  }

  static GiftCardStatus fromString(String? s) {
    switch (s) {
      case 'active':
        return GiftCardStatus.active;
      case 'redeemed':
        return GiftCardStatus.redeemed;
      default:
        return GiftCardStatus.available;
    }
  }
}

// ---------------------------------------------------------------------------
// GiftCardModel
// ---------------------------------------------------------------------------

class GiftCardModel {
  final String id;

  /// Código único impreso en la tarjeta, p.e. "KIRI-A1B2C3"
  final String code;

  /// Status del ciclo de vida
  final GiftCardStatus status;

  /// URL en Firebase Storage (null cuando fue canjeada y la imagen eliminada)
  final String? imageUrl;

  /// Nombre del comprador (lo llena el admin al marcar como activa)
  final String? buyerName;

  /// ID de la cita en la que fue canjeada
  final String? appointmentId;

  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? redeemedAt;

  const GiftCardModel({
    required this.id,
    required this.code,
    required this.status,
    this.imageUrl,
    this.buyerName,
    this.appointmentId,
    required this.createdAt,
    this.activatedAt,
    this.redeemedAt,
  });

  factory GiftCardModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GiftCardModel(
      id: doc.id,
      code: d['code'] as String? ?? '',
      status: GiftCardStatusX.fromString(d['status'] as String?),
      imageUrl: d['imageUrl'] as String?,
      buyerName: d['buyerName'] as String?,
      appointmentId: d['appointmentId'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      activatedAt: d['activatedAt'] != null
          ? (d['activatedAt'] as Timestamp).toDate()
          : null,
      redeemedAt: d['redeemedAt'] != null
          ? (d['redeemedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'code': code,
        'status': status.name,
        'imageUrl': imageUrl,
        'buyerName': buyerName,
        'appointmentId': appointmentId,
        'createdAt': Timestamp.fromDate(createdAt),
        'activatedAt':
            activatedAt != null ? Timestamp.fromDate(activatedAt!) : null,
        'redeemedAt':
            redeemedAt != null ? Timestamp.fromDate(redeemedAt!) : null,
      };

  GiftCardModel copyWith({
    String? id,
    String? code,
    GiftCardStatus? status,
    String? imageUrl,
    String? buyerName,
    String? appointmentId,
    DateTime? createdAt,
    DateTime? activatedAt,
    DateTime? redeemedAt,
  }) {
    return GiftCardModel(
      id: id ?? this.id,
      code: code ?? this.code,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      buyerName: buyerName ?? this.buyerName,
      appointmentId: appointmentId ?? this.appointmentId,
      createdAt: createdAt ?? this.createdAt,
      activatedAt: activatedAt ?? this.activatedAt,
      redeemedAt: redeemedAt ?? this.redeemedAt,
    );
  }
}
