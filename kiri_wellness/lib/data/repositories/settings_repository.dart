import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/settings_model.dart';

class SettingsRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  SettingsRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: "us-central1");

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('settings').doc('global');

  Stream<AppSettings> watchSettings() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists) return const AppSettings();
      return AppSettings.fromFirestore(snap);
    });
  }

  Future<AppSettings> getSettings() async {
    final snap = await _doc.get();
    if (!snap.exists) return const AppSettings();
    return AppSettings.fromFirestore(snap);
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _functions
        .httpsCallable('updateSettings')
        .call(settings.toFirestore());
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (_) => SettingsRepository(),
);

final settingsStreamProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
});
