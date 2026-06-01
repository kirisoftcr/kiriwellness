import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'environment.dart';

class AppFirebase {
  static String get firestoreDatabaseId =>
      Environment.isProd ? 'production' : '(default)';

  static FirebaseFirestore get firestore => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: firestoreDatabaseId,
      );
}
