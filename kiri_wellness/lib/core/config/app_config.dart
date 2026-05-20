enum AppEnvironment { dev, prod }

class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final String firestorePrefix;

  const AppConfig({
    required this.environment,
    required this.appName,
    required this.firestorePrefix,
  });

  static AppConfig? _instance;

  static AppConfig get instance {
    assert(_instance != null, 'AppConfig must be initialized before use');
    return _instance!;
  }

  static void initialize(AppConfig config) {
    _instance = config;
  }

  bool get isDev => environment == AppEnvironment.dev;
  bool get isProd => environment == AppEnvironment.prod;
}
