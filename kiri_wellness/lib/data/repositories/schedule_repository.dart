import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/schedule_model.dart';

class ScheduleRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  ScheduleRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: "us-central1");

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('schedules');

  // ---------------------------------------------------------------------------
  // Read — real-time stream ordered by day then start time
  // ---------------------------------------------------------------------------

  Stream<List<ScheduleModel>> watchAll() {
    return _col
        .orderBy('dayOfWeek')
        .orderBy('startTime')
        .snapshots()
        .map((s) => s.docs.map(ScheduleModel.fromFirestore).toList());
  }

  // ---------------------------------------------------------------------------
  // Write — via Cloud Functions
  // ---------------------------------------------------------------------------

  Future<void> create(ScheduleModel schedule) async {
    await _functions
        .httpsCallable('createSchedule')
        .call(schedule.toFirestore());
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _functions
        .httpsCallable('updateSchedule')
        .call({'id': id, ...data});
  }

  Future<void> delete(String id) async {
    await _functions.httpsCallable('deleteSchedule').call({'id': id});
  }

  Future<void> setActive(String id, bool active) async {
    await update(id, {'isActive': active});
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (_) => ScheduleRepository(),
);

final schedulesStreamProvider = StreamProvider<List<ScheduleModel>>((ref) {
  return ref.watch(scheduleRepositoryProvider).watchAll();
});
