/// Configuracao de ambiente do aplicativo.
library;

import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Porta em que a API Node.js escuta.
  static const int _porta = 3000;

  /// Host informado em tempo de compilacao, para dispositivo fisico:
  ///   flutter run --dart-define=API_HOST=192.168.0.15
  static const String _hostManual =
      String.fromEnvironment('API_HOST', defaultValue: '');

  /// URL base da API, resolvida por plataforma.
  ///
  /// O emulador Android roda numa VM e nao alcanca o "localhost" do PC:
  /// 10.0.2.2 e o alias do host nessa rede virtual. Em dispositivo
  /// fisico, informe o IP da maquina via --dart-define=API_HOST=...
  static String get baseUrl {
    if (_hostManual.isNotEmpty) return 'http://$_hostManual:$_porta/api';
    if (kIsWeb) return 'http://localhost:$_porta/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_porta/api';
    }
    return 'http://localhost:$_porta/api';
  }

  /// Intervalo de atualizacao da tela de Chat.
  ///
  /// O prototipo descreve "mensagens em tempo real". Como a comunicacao
  /// exigida e REST (e nao WebSocket), a tela consulta periodicamente
  /// apenas as mensagens novas, usando o parametro `depoisDe`.
  static const Duration intervaloPollingChat = Duration(seconds: 4);

  /// Tempo maximo de espera das requisicoes HTTP.
  static const Duration timeoutRequisicao = Duration(seconds: 15);
}
