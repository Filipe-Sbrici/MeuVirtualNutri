/// Inicializacao do Firebase no app.
///
/// Ordem de resolucao da configuracao:
///  1. `lib/firebase_options.dart` gerado pela CLI FlutterFire
///     (`flutterfire configure`) — caso padrao do projeto.
///  2. Valores via `--dart-define` (FIREBASE_API_KEY etc.) — util para
///     rodar sem os arquivos gerados (ex.: web/desktop de teste).
///  3. Configuracao nativa do Android/iOS (google-services.json /
///     GoogleService-Info.plist injetados pelo plugin do Gradle).
///
/// Com `AUTH_EMULATOR_HOST=localhost:9099`, o Authentication passa a
/// falar com o emulador local.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseConfig {
  FirebaseConfig._();

  /// Valores opcionais passados via --dart-define.
  static const String apiKey =
      String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  static const String projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static const String appId =
      String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');

  /// Host do emulador de Authentication
  /// (--dart-define=AUTH_EMULATOR_HOST=localhost:9099).
  static const String authEmulatorHost =
      String.fromEnvironment('AUTH_EMULATOR_HOST', defaultValue: '');

  /// true quando ha configuracao suficiente via dart-define.
  static bool get disponivelViaDefines =>
      apiKey.isNotEmpty && appId.isNotEmpty;

  /// Inicializa o Firebase conforme a resolucao documentada acima.
  static Future<FirebaseApp> inicializar() async {
    FirebaseOptions? opcoes;
    try {
      // 1. Arquivo gerado pela CLI FlutterFire.
      opcoes = DefaultFirebaseOptions.currentPlatform;
    } catch (_) {
      // 2. dart-define (plataformas fora do CLI, ex. linux).
      opcoes = disponivelViaDefines
          ? const FirebaseOptions(
              apiKey: apiKey,
              projectId: projectId,
              messagingSenderId: messagingSenderId,
              appId: appId,
            )
          : null;
    }

    // 3. null -> Android/iOS usam a configuracao nativa injetada.
    final app = await Firebase.initializeApp(options: opcoes);

    if (authEmulatorHost.isNotEmpty) {
      final partes = authEmulatorHost.split(':');
      await FirebaseAuth.instanceFor(app: app).useAuthEmulator(
            partes.first,
            int.tryParse(partes.last) ?? 9099,
          );
    }
    return app;
  }
}
