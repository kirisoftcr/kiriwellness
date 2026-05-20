import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/environment.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';

const bool _useEmulators = bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await Firebase.initializeApp(options: Environment.firebaseOptions);

  if (_useEmulators) {
    // Connect to local Firebase emulators
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseFunctions.instanceFor(region: "us-central1").useFunctionsEmulator('localhost', 5001);
  }

  runApp(const ProviderScope(child: KiriWellnessApp()));
}

class KiriWellnessApp extends ConsumerWidget {
  const KiriWellnessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Kiri Wellness',
      debugShowCheckedModeBanner: Environment.isQA,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es'), Locale('en')],
    );
  }
}
