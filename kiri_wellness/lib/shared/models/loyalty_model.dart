import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoyaltyRule  –  una regla individual del programa de regalías
// ─────────────────────────────────────────────────────────────────────────────

class LoyaltyRule {
  /// Identificador único de la regla
  final String id;

  /// Descripción amigable de la regla (p.ej. "6ª cita gratis en Cama Ceragem")
  final String name;

  /// Número de citas completadas que activa la regalía
  final int milestone;

  /// Si true, la regalía se repite cada vez que el cliente alcanza un múltiplo
  /// del milestone (6, 12, 18...). Si false, sólo se otorga una vez.
  final bool isRecurring;

  /// ID del servicio que se otorga gratis
  final String serviceId;

  /// Nombre del servicio (denormalizado para mostrar sin consulta adicional)
  final String serviceName;

  /// Texto personalizado que verá el cliente en su notificación / portal
  final String description;

  /// Días de validez desde que se gana la regalía (0 = sin expiración)
  final int validityDays;

  /// Permite activar/desactivar la regla sin eliminarla
  final bool enabled;

  const LoyaltyRule({
    required this.id,
    required this.name,
    required this.milestone,
    this.isRecurring = true,
    required this.serviceId,
    required this.serviceName,
    required this.description,
    this.validityDays = 30,
    this.enabled = true,
  });

  factory LoyaltyRule.fromMap(Map<String, dynamic> d) => LoyaltyRule(
        id: d['id'] as String,
        name: d['name'] as String? ?? '',
        milestone: (d['milestone'] as num).toInt(),
        isRecurring: d['isRecurring'] as bool? ?? true,
        serviceId: d['serviceId'] as String? ?? '',
        serviceName: d['serviceName'] as String? ?? '',
        description: d['description'] as String? ?? '',
        validityDays: (d['validityDays'] as num?)?.toInt() ?? 30,
        enabled: d['enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'milestone': milestone,
        'isRecurring': isRecurring,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'description': description,
        'validityDays': validityDays,
        'enabled': enabled,
      };

  LoyaltyRule copyWith({
    String? id,
    String? name,
    int? milestone,
    bool? isRecurring,
    String? serviceId,
    String? serviceName,
    String? description,
    int? validityDays,
    bool? enabled,
  }) =>
      LoyaltyRule(
        id: id ?? this.id,
        name: name ?? this.name,
        milestone: milestone ?? this.milestone,
        isRecurring: isRecurring ?? this.isRecurring,
        serviceId: serviceId ?? this.serviceId,
        serviceName: serviceName ?? this.serviceName,
        description: description ?? this.description,
        validityDays: validityDays ?? this.validityDays,
        enabled: enabled ?? this.enabled,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LoyaltyConfig  –  configuración global del programa almacenada en
//                   Firestore: settings/loyalty
// ─────────────────────────────────────────────────────────────────────────────

class LoyaltyConfig {
  /// Activa o desactiva todo el programa de regalías
  final bool enabled;

  /// Lista de reglas configuradas
  final List<LoyaltyRule> rules;

  /// Texto de bienvenida que se muestra al cliente cuando gana una regalía
  final String rewardEmailSubject;

  const LoyaltyConfig({
    this.enabled = false,
    this.rules = const [],
    this.rewardEmailSubject = '🎁 ¡Tienes una regalía en Kiri Wellness!',
  });

  factory LoyaltyConfig.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return LoyaltyConfig(
      enabled: d['enabled'] as bool? ?? false,
      rules: ((d['rules'] as List?) ?? [])
          .map((r) => LoyaltyRule.fromMap(r as Map<String, dynamic>))
          .toList(),
      rewardEmailSubject: d['rewardEmailSubject'] as String? ??
          '🎁 ¡Tienes una regalía en Kiri Wellness!',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'enabled': enabled,
        'rules': rules.map((r) => r.toMap()).toList(),
        'rewardEmailSubject': rewardEmailSubject,
      };

  LoyaltyConfig copyWith({
    bool? enabled,
    List<LoyaltyRule>? rules,
    String? rewardEmailSubject,
  }) =>
      LoyaltyConfig(
        enabled: enabled ?? this.enabled,
        rules: rules ?? this.rules,
        rewardEmailSubject: rewardEmailSubject ?? this.rewardEmailSubject,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ClientReward  –  una regalía ganada por un cliente específico
//                  almacenada en: clients/{clientId}/rewards/{rewardId}
// ─────────────────────────────────────────────────────────────────────────────

enum RewardStatus { pending, redeemed, expired }

extension RewardStatusX on RewardStatus {
  String get label {
    switch (this) {
      case RewardStatus.pending:
        return 'Disponible';
      case RewardStatus.redeemed:
        return 'Canjeada';
      case RewardStatus.expired:
        return 'Expirada';
    }
  }
}

class ClientReward {
  final String id;

  /// ID de la LoyaltyRule que la generó
  final String ruleId;

  /// Número de cita que activó esta regalía
  final int earnedAtMilestone;

  /// Servicio gratuito que se otorga
  final String serviceId;
  final String serviceName;

  /// Descripción visible al cliente
  final String description;

  final DateTime earnedAt;

  /// null si validityDays == 0
  final DateTime? expiresAt;

  final RewardStatus status;
  final DateTime? redeemedAt;

  /// ID de la cita en la que se canjeó
  final String? redeemedAppointmentId;

  const ClientReward({
    required this.id,
    required this.ruleId,
    required this.earnedAtMilestone,
    required this.serviceId,
    required this.serviceName,
    required this.description,
    required this.earnedAt,
    this.expiresAt,
    this.status = RewardStatus.pending,
    this.redeemedAt,
    this.redeemedAppointmentId,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory ClientReward.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClientReward(
      id: doc.id,
      ruleId: d['ruleId'] as String? ?? '',
      earnedAtMilestone: (d['earnedAtMilestone'] as num?)?.toInt() ?? 0,
      serviceId: d['serviceId'] as String? ?? '',
      serviceName: d['serviceName'] as String? ?? '',
      description: d['description'] as String? ?? '',
      earnedAt: (d['earnedAt'] as Timestamp).toDate(),
      expiresAt: d['expiresAt'] != null
          ? (d['expiresAt'] as Timestamp).toDate()
          : null,
      status: RewardStatus.values.firstWhere(
        (s) => s.name == (d['status'] as String? ?? 'pending'),
        orElse: () => RewardStatus.pending,
      ),
      redeemedAt: d['redeemedAt'] != null
          ? (d['redeemedAt'] as Timestamp).toDate()
          : null,
      redeemedAppointmentId: d['redeemedAppointmentId'] as String?,
    );
  }
}
