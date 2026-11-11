/// Configuracao de ambiente do aplicativo.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'local_api_engine.dart';

class AppConfig {
  AppConfig._();

  /// Chave de persistencia para a URL customizada nas preferencias locais.
  static const String _chavePrefApiUrl = 'mvn_custom_api_url';

  /// Porta padrao em que a API Node.js escuta.
  static const int _porta = 3000;

  /// Host informado em tempo de compilacao:
  ///   flutter run --dart-define=API_HOST=192.168.0.15
  static const String _hostManual =
      String.fromEnvironment('API_HOST', defaultValue: '');

  /// URL completa informada em tempo de compilacao:
  ///   flutter run --dart-define=API_URL=https://minha-api.onrender.com/api
  static const String _urlManual =
      String.fromEnvironment('API_URL', defaultValue: '');

  /// URL definida em tempo de execucao (persistida no dispositivo).
  static String? _urlCustomizada;

  /// Quando true, o aplicativo utiliza o motor integrado ([LocalApiEngine])
  /// caso o servidor Node.js externo nao esteja acessivel (ex.: APK instalado
  /// direto no celular fora da rede do computador).
  static bool _modoServidorIntegrado = false;

  static bool get modoServidorIntegrado => _modoServidorIntegrado;

  static void ativarModoIntegrado([bool ativo = true]) {
    _modoServidorIntegrado = ativo;
  }

  /// Inicializa as configuracoes persistidas (chamado no startup do app)
  /// e verifica rapidamente se ha um servidor Node.js externo ativo.
  static Future<void> inicializar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final urlSalva = prefs.getString(_chavePrefApiUrl);
      if (urlSalva != null && urlSalva.trim().isNotEmpty) {
        if (urlSalva.trim() == 'integrado') {
          _modoServidorIntegrado = true;
          _urlCustomizada = null;
          return;
        }
        _urlCustomizada = normalizarUrl(urlSalva);
      }
    } catch (_) {
      // Ignora falhas em ambientes onde SharedPreferences nao esta disponivel.
    }

    // Sonda rapida (1.5s): testa a URL configurada/padrao e o IP local da rede Wi-Fi.
    // Se nenhum servidor Node.js externo responder (ex.: celular fora da rede ou PC desligado),
    // ativa imediatamente o servidor integrado para resposta instantanea.
    final disponivelPadrao = await _sondarServidorExterno(
      baseUrl,
      timeout: const Duration(milliseconds: 1200),
    );
    if (disponivelPadrao) {
      _modoServidorIntegrado = false;
      return;
    }

    if (!temUrlCustomizada) {
      const urlPcRedeLocal = 'http://192.168.15.165:$_porta/api';
      final disponivelRede = await _sondarServidorExterno(
        urlPcRedeLocal,
        timeout: const Duration(milliseconds: 1200),
      );
      if (disponivelRede) {
        _urlCustomizada = urlPcRedeLocal;
        _modoServidorIntegrado = false;
        return;
      }
    }

    _modoServidorIntegrado = true;
  }

  static Future<bool> _sondarServidorExterno(
    String urlBase, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final uri = Uri.parse('$urlBase/health');
      final resposta = await http
          .get(uri, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(timeout);
      return resposta.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Define e persiste uma nova URL base da API no dispositivo.
  static Future<void> definirUrlCustomizada(String novaUrl) async {
    if (novaUrl.trim().toLowerCase() == 'integrado') {
      _modoServidorIntegrado = true;
      _urlCustomizada = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_chavePrefApiUrl, 'integrado');
      } catch (_) {}
      return;
    }

    final urlNormalizada = normalizarUrl(novaUrl);
    _urlCustomizada = urlNormalizada;
    _modoServidorIntegrado = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chavePrefApiUrl, urlNormalizada);
    } catch (_) {}
  }

  /// Restaura a URL padrao da plataforma e remove a configuracao customizada.
  static Future<void> limparUrlCustomizada() async {
    _urlCustomizada = null;
    _modoServidorIntegrado = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chavePrefApiUrl);
    } catch (_) {}
  }

  /// Indica se ha uma URL customizada ativa pelo usuario.
  static bool get temUrlCustomizada =>
      _urlCustomizada != null && _urlCustomizada!.trim().isNotEmpty;

  /// URL customizada atual (se houver).
  static String? get urlCustomizada => _urlCustomizada;

  /// Host manual fornecido via --dart-define.
  static String get hostManual => _hostManual;

  /// URL manual fornecida via --dart-define.
  static String get urlManual => _urlManual;

  /// URL padrao da plataforma (sem considerar customizacoes de usuario).
  static String get urlPadraoPlataforma {
    if (_urlManual.isNotEmpty) return normalizarUrl(_urlManual);
    if (_hostManual.isNotEmpty) {
      return normalizarUrl('http://$_hostManual:$_porta/api');
    }
    if (kIsWeb) return 'http://localhost:$_porta/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_porta/api';
    }
    return 'http://localhost:$_porta/api';
  }

  /// URL base ativa da API, resolvida por prioridade:
  /// 1. URL customizada definida pelo usuario no aplicativo (persistida)
  /// 2. URL completa informada em compilacao (--dart-define=API_URL=...)
  /// 3. Host informado em compilacao (--dart-define=API_HOST=...)
  /// 4. Padrao da plataforma (10.0.2.2 no Android Emulator, localhost no Web/Desktop)
  static String get baseUrl {
    if (_urlCustomizada != null && _urlCustomizada!.trim().isNotEmpty) {
      return normalizarUrl(_urlCustomizada!);
    }
    return urlPadraoPlataforma;
  }

  /// Normaliza entradas de URL ou IP para o formato padrao 'http(s)://host:porta/api'.
  static String normalizarUrl(String entrada) {
    var limpa = entrada.trim();
    if (limpa.isEmpty || limpa.toLowerCase() == 'integrado') {
      return urlPadraoPlataforma;
    }

    // Se nao tiver protocolo, define 'http://' como padrao
    if (!limpa.startsWith('http://') && !limpa.startsWith('https://')) {
      limpa = 'http://$limpa';
    }

    // Remove barras no final
    while (limpa.endsWith('/')) {
      limpa = limpa.substring(0, limpa.length - 1);
    }

    // Se a URL nao contiver porta e for IP puro ou localhost via HTTP, anexa a porta padrao :3000
    try {
      final uri = Uri.parse(limpa);
      final host = uri.host;
      final ehIpOuLocalhost = host == 'localhost' ||
          RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);

      if (ehIpOuLocalhost && !uri.hasPort && uri.scheme == 'http') {
        final caminhoSemApi = uri.path.replaceAll(RegExp(r'/api/?$'), '');
        final caminhoFinal = caminhoSemApi.isNotEmpty ? caminhoSemApi : '';
        limpa = '${uri.scheme}://$host:$_porta$caminhoFinal';
      }
    } catch (_) {}

    // Garante que o caminho termine com '/api'
    if (!limpa.endsWith('/api')) {
      limpa = '$limpa/api';
    }

    return limpa;
  }

  /// Procura automaticamente um servidor Node.js na rede local Wi-Fi.
  static Future<String?> descobrirServidorNaRede() async {
    const candidatos = <String>[
      '192.168.15.165',
      '10.0.2.2',
      'localhost',
      '192.168.15.2',
      '192.168.15.10',
      '192.168.0.10',
      '192.168.0.15',
      '192.168.0.22',
      '192.168.0.100',
      '192.168.1.2',
      '192.168.1.10',
      '192.168.1.15',
      '192.168.1.100',
    ];

    final resultados = await Future.wait(
      candidatos.map((host) async {
        final url = normalizarUrl(host);
        final ok = await _sondarServidorExterno(
          url,
          timeout: const Duration(milliseconds: 900),
        );
        return ok ? url : null;
      }),
    );

    for (final r in resultados) {
      if (r != null) return r;
    }
    return null;
  }

  /// Testa a conectividade com a API (endpoint /health ou motor integrado).
  static Future<ResultadoConexao> testarConexao([String? urlAlvo]) async {
    final entradaLimpa = (urlAlvo ?? '').trim();
    final stopwatch = Stopwatch()..start();

    if (entradaLimpa.toLowerCase() == 'integrado') {
      _modoServidorIntegrado = true;
      await LocalApiEngine.instance.processar('GET', '/health');
      stopwatch.stop();
      return ResultadoConexao(
        sucesso: true,
        mensagem:
            'Servidor Integrado do APK ativo (${stopwatch.elapsedMilliseconds}ms). O aplicativo funciona diretamente no celular com Firebase Auth sem precisar de computador!',
        tempoMs: stopwatch.elapsedMilliseconds,
      );
    }

    final urlBase =
        entradaLimpa.isNotEmpty ? normalizarUrl(entradaLimpa) : baseUrl;
    final uri = Uri.parse('$urlBase/health');

    try {
      final resposta = await http
          .get(uri, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 3));
      stopwatch.stop();

      if (resposta.statusCode == 200) {
        _modoServidorIntegrado = false;
        try {
          final json = jsonDecode(resposta.body);
          final sucesso = json['sucesso'] == true;
          final banco = json['banco']?.toString() ?? 'ok';
          return ResultadoConexao(
            sucesso: sucesso,
            mensagem: sucesso
                ? 'Conexão estabelecida com o servidor Node.js ($urlBase em ${stopwatch.elapsedMilliseconds}ms).'
                : 'API respondeu, mas acusou pendência no banco: $banco.',
            tempoMs: stopwatch.elapsedMilliseconds,
          );
        } catch (_) {
          return ResultadoConexao(
            sucesso: true,
            mensagem:
                'Conexão estabelecida com $urlBase (HTTP 200 em ${stopwatch.elapsedMilliseconds}ms).',
            tempoMs: stopwatch.elapsedMilliseconds,
          );
        }
      }
    } catch (_) {}

    // Se o servidor externo nao respondeu, ativa o motor integrado para que o APK nunca falhe no celular
    _modoServidorIntegrado = true;
    await LocalApiEngine.instance.processar('GET', '/health');
    stopwatch.stop();
    return ResultadoConexao(
      sucesso: true,
      mensagem:
          'Servidor Node.js externo ($urlBase) não detectado na rede. O Modo Integrado do APK foi ativado automaticamente (${stopwatch.elapsedMilliseconds}ms) — todas as funções estão prontas para uso no celular!',
      tempoMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Intervalo de atualizacao da tela de Chat.
  static const Duration intervaloPollingChat = Duration(seconds: 4);

  /// Tempo maximo de espera das requisicoes HTTP normais.
  static const Duration timeoutRequisicao = Duration(seconds: 6);
}

/// Resultado detalhado do teste de conexao com a API.
class ResultadoConexao {
  const ResultadoConexao({
    required this.sucesso,
    required this.mensagem,
    required this.tempoMs,
  });

  final bool sucesso;
  final String mensagem;
  final int tempoMs;
}
