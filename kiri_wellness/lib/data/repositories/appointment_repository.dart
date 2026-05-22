import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_repository.dart';
import '../../shared/models/appointment_model.dart';

class AppointmentRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  AppointmentRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: "us-central1");

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('appointments');

  // ---------------------------------------------------------------------------
  // Read — real-time streams
  // ---------------------------------------------------------------------------

  Stream<List<AppointmentModel>> watchAll() {
    return _col
        .orderBy('date', descending: true)
        .orderBy('time', descending: false)
        .snapshots()
        .map((s) => s.docs.map(AppointmentModel.fromFirestore).toList());
  }

  Stream<List<AppointmentModel>> watchByDate(String date) {
    return _col
        .where('date', isEqualTo: date)
        .orderBy('time')
        .snapshots()
        .map((s) => s.docs.map(AppointmentModel.fromFirestore).toList());
  }

  Stream<List<AppointmentModel>> watchUpcoming() {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _col
        .where('date', isGreaterThanOrEqualTo: todayStr)
        .orderBy('date')
        .orderBy('time')
        .snapshots()
        .map((s) => s.docs
            .map(AppointmentModel.fromFirestore)
            .where((a) =>
                a.status == AppointmentStatus.requested ||
                a.status == AppointmentStatus.confirmed)
            .toList());
  }

  Future<List<AppointmentModel>> getByDate(String date) async {
    final snap = await _col.where('date', isEqualTo: date).orderBy('time').get();
    return snap.docs.map(AppointmentModel.fromFirestore).toList();
  }

  // ---------------------------------------------------------------------------
  // Write — via Cloud Functions (admin)
  // ---------------------------------------------------------------------------

  Future<void> updateStatus(String id, AppointmentStatus status) async {
    await _functions.httpsCallable('updateAppointmentStatus').call({
      'appointmentId': id,
      'status': status.name,
    });
  }

  Future<Map<String, dynamic>> createBooking({
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required String serviceId,
    required String serviceName,
    required int serviceDurationMin,
    required double servicePrice,
    required String date,
    required String time,
    String? notes,
    bool confirmDirectly = false,
  }) async {
    final result = await _functions.httpsCallable('createBooking').call({
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'serviceDurationMin': serviceDurationMin,
      'servicePrice': servicePrice,
      'date': date,
      'time': time,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (confirmDirectly) 'confirmDirectly': true,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  // ---------------------------------------------------------------------------
  // Available slots (public callable)
  // ---------------------------------------------------------------------------

  Future<List<String>> getAvailableSlots({
    required String date,
    required String serviceId,
  }) async {
    final result = await _functions.httpsCallable('getAvailableSlots').call({
      'date': date,
      'serviceId': serviceId,
    });
    final data = result.data as Map<String, dynamic>;
    return List<String>.from(data['slots'] as List? ?? []);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (_) => AppointmentRepository(),
);

final allAppointmentsStreamProvider =
    StreamProvider<List<AppointmentModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(appointmentRepositoryProvider).watchAll();
});

final upcomingAppointmentsStreamProvider =
    StreamProvider<List<AppointmentModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(appointmentRepositoryProvider).watchUpcoming();
});

final appointmentsByDateProvider =
    StreamProvider.family<List<AppointmentModel>, String>((ref, date) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(appointmentRepositoryProvider).watchByDate(date);
});
