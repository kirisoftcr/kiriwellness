import 'package:cloud_firestore/cloud_firestore.dart';

enum RaffleStatus { active, finished, cancelled }

class RaffleModel {
  final String id;
  final String title;
  final String description;
  final String prize;
  final double ticketPrice;
  final int totalTickets;
  final int soldTickets;
  final RaffleStatus status;
  final DateTime drawDate;
  final String? winnerId;
  final String? winnerName;
  final String? winnerTicket;
  final String? imageUrl;
  final DateTime createdAt;

  const RaffleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.prize,
    required this.ticketPrice,
    required this.totalTickets,
    required this.soldTickets,
    required this.status,
    required this.drawDate,
    this.winnerId,
    this.winnerName,
    this.winnerTicket,
    this.imageUrl,
    required this.createdAt,
  });

  int get availableTickets => totalTickets - soldTickets;
  double get totalRevenue => soldTickets * ticketPrice;

  factory RaffleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaffleModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      prize: data['prize'] ?? '',
      ticketPrice: (data['ticketPrice'] ?? 0).toDouble(),
      totalTickets: data['totalTickets'] ?? 100,
      soldTickets: data['soldTickets'] ?? 0,
      status: RaffleStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RaffleStatus.active,
      ),
      drawDate: (data['drawDate'] as Timestamp).toDate(),
      winnerId: data['winnerId'],
      winnerName: data['winnerName'],
      winnerTicket: data['winnerTicket'],
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'prize': prize,
    'ticketPrice': ticketPrice,
    'totalTickets': totalTickets,
    'soldTickets': soldTickets,
    'status': status.name,
    'drawDate': Timestamp.fromDate(drawDate),
    'winnerId': winnerId,
    'winnerName': winnerName,
    'winnerTicket': winnerTicket,
    'imageUrl': imageUrl,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class RaffleTicketModel {
  final String id;
  final String raffleId;
  final String clientId;
  final String clientName;
  final String ticketNumber;
  final DateTime purchasedAt;

  const RaffleTicketModel({
    required this.id,
    required this.raffleId,
    required this.clientId,
    required this.clientName,
    required this.ticketNumber,
    required this.purchasedAt,
  });

  factory RaffleTicketModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaffleTicketModel(
      id: doc.id,
      raffleId: data['raffleId'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      ticketNumber: data['ticketNumber'] ?? '',
      purchasedAt: (data['purchasedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'raffleId': raffleId,
    'clientId': clientId,
    'clientName': clientName,
    'ticketNumber': ticketNumber,
    'purchasedAt': Timestamp.fromDate(purchasedAt),
  };
}
