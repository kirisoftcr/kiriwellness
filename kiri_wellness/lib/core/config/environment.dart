import '../../firebase_options_qa.dart' as qa;
import '../../firebase_options_prod.dart' as prod;
import 'package:firebase_core/firebase_core.dart';

class Environment {
  static const flavor = String.fromEnvironment('FLAVOR');
  static const site = String.fromEnvironment('SITE'); // 'client' | 'admin'

  static FirebaseOptions get firebaseOptions {
    if (isProd) {
      return isAdminSite
          ? prod.DefaultFirebaseOptions.adminWeb
          : prod.DefaultFirebaseOptions.clientWeb;
    }

    return isAdminSite
        ? qa.DefaultFirebaseOptions.adminWeb
        : qa.DefaultFirebaseOptions.clientWeb;
  }

  static bool get isProd => flavor == 'prod';
  static bool get isQA => flavor == 'qa' || flavor.isEmpty;

  /// True when this build is the client-facing site (booking + mis citas only).
  static bool get isClientSite => site == 'client';

  /// True when this build is the admin panel.
  static bool get isAdminSite => site == 'admin' || site.isEmpty;

  /// Base URL for deep links (e.g. in emails).
  static String get clientBaseUrl =>
      isProd ? 'https://kiriwellness.com' : 'https://kiri-wellness-qa.web.app';

  /// Admin panel URL.
  static String get adminBaseUrl =>
      isProd ? 'https://admin.kiriwellness.com' : 'https://kiri-wellness-qa.web.app';
}
