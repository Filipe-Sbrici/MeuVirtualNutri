/// Configuracao de ambiente do aplicativo.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Inicializa as configuracoes persistidas (chamado no startup do app).
  static Future<void> inicializar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final urlSalva = prefs.getString(_chavePrefApiUrl);
      if (urlSalva != null && urlSalva.trim().isNotEmpty) {
        _urlCustomizada = normalizarUrl(urlSalva);
      }
    } catch (_) {
      // Ignora falhas em ambientes onde SharedPreferences nao esta disponivel (ex. testes de unidade).
    }
  }

  /// Define e persiste uma nova URL base da API no dispositivo.
  static Future<void> definirUrlCustomizada(String novaUrl) async {
    final urlNormalizada = normalizarUrl(novaUrl);
    _urlCustomizada = urlNormalizada;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chavePrefApiUrl, urlNormalizada);
    } catch (_) {}
  }

  /// Restaura a URL padrao da plataforma e remove a configuracao customizada.
  static Future<void> limparUrlCustomizada() async {
    _urlCustomizada = null;
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
    if (limpa.isEmpty) return urlPadraoPlataforma;

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

  /// Testa a conectividade com a API (endpoint /health ou /).
  static Future<ResultadoConexao> testarConexao([String? urlAlvo]) async {
    final urlBase = urlAlvo != null ? normalizarUrl(urlAlvo) : baseUrl;
    final uri = Uri.parse('$urlBase/health');
    final stopwatch = Stopwatch()..start();

    try {
      final resposta = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();

      if (resposta.statusCode == 200) {
        try {
          final json = jsonDecode(resposta.body);
          final sucesso = json['sucesso'] == true;
          final banco = json['banco']?.toString() ?? 'ok';
          return ResultadoConexao(
            sucesso: sucesso,
            mensagem: sucesso
                ? 'Conexão estabelecida com sucesso! API e banco online (${stopwatch.elapsedMilliseconds}ms).'
                : 'API respondeu, mas acusou pendência no banco: $banco.',
            tempoMs: stopwatch.elapsedMilliseconds,
          );
        } catch (_) {
          return ResultadoConexao(
            sucesso: true,
            mensagem: 'Conexão estabelecida (HTTP 200 em ${stopwatch.elapsedMilliseconds}ms).',
            tempoMs: stopwatch.elapsedMilliseconds,
          );
        }
      }

      return ResultadoConexao(
        sucesso: false,
        mensagem: 'O servidor respondeu com status HTTP ${resposta.statusCode}.',
        tempoMs: stopwatch.elapsedMilliseconds,
      );
    } on TimeoutException {
      stopwatch.stop();
      return ResultadoConexao(
        sucesso: false,
        mensagem: 'Tempo limite esgotado (5s). O servidor em $urlBase não respondeu.',
        tempoMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ResultadoConexao(
        sucesso: false,
        mensagem: 'Falha ao conectar em $urlBase: $e',
        tempoMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Intervalo de atualizacao da tela de Chat.
  static const Duration intervaloPollingChat = Duration(seconds: 4);

  /// Tempo maximo de espera das requisicoes HTTP normais.
  static const Duration timeoutRequisicao = Duration(seconds: 15);
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
