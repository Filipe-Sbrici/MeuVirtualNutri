/// Cliente HTTP compartilhado pelos servicos.
///
/// Concentra a montagem das URLs, a serializacao JSON, a injecao do
/// token do Firebase Authentication em cada requisicao e o tratamento
/// de erros, para que os servicos e as telas nunca lidem com `http`
/// direto.
///
/// Em dispositivos fisicos (APK Android) onde o servidor Node.js externo
/// nao estiver acessivel na rede, realiza fallback automatico e transparente
/// para o [LocalApiEngine].
library;

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'local_api_engine.dart';

/// Erro de API com mensagem pronta para exibicao ao usuario.
class ApiException implements Exception {
  ApiException(this.mensagem, {this.status});

  final String mensagem;
  final int? status;

  @override
  String toString() => 'ApiException($status): $mensagem';
}

/// Converte o campo `dados` da resposta usando [construtor].
///
/// Qualquer incompatibilidade de formato vira [ApiException], para que as
/// telas mostrem a mensagem amigavel com "Tentar novamente" em vez de uma
/// tela vermelha de excecao nao tratada.
T lerDados<T>(
  Map<String, dynamic> resposta,
  T Function(Map<String, dynamic>) construtor,
) {
  final dados = resposta['dados'];
  if (dados is! Map<String, dynamic>) {
    throw ApiException('A resposta da API nao trouxe o campo "dados".');
  }
  try {
    return construtor(dados);
  } on ApiException {
    rethrow;
  } catch (erro) {
    throw ApiException('Formato inesperado na resposta da API: $erro');
  }
}

/// Converte o campo `dados` esperando uma lista interna nomeada.
///
/// Como em [lerDados], qualquer incompatibilidade de formato vira
/// [ApiException] para que as telas mostrem a mensagem amigavel em vez
/// de deixar escapar um TypeError nao tratado.
List<T> lerLista<T>(
  Map<String, dynamic> resposta,
  String chave,
  T Function(Map<String, dynamic>) construtor,
) {
  final dados = resposta['dados'];
  if (dados is! Map<String, dynamic>) {
    throw ApiException('A resposta da API nao trouxe o campo "dados".');
  }
  final lista = dados[chave];
  if (lista is! List) return <T>[];
  try {
    return lista
        .map((item) => construtor(item as Map<String, dynamic>))
        .toList();
  } on ApiException {
    rethrow;
  } catch (erro) {
    throw ApiException('Formato inesperado na resposta da API: $erro');
  }
}

/// Funcao que fornece o token de sessao; injetavel nos testes.
typedef ProvedorToken = Future<String?> Function();

class ApiClient {
  ApiClient({http.Client? cliente, ProvedorToken? provedorToken})
      : _usaClientePadrao = cliente == null,
        _cliente = cliente ?? http.Client(),
        _provedorToken = provedorToken ?? _tokenPadrao;

  final bool _usaClientePadrao;
  final http.Client _cliente;
  final ProvedorToken _provedorToken;

  void fechar() => _cliente.close();

  /// Token Firebase padrao: usuario autenticado atual (ou null).
  /// Tolerante a ausencia de FirebaseApp (testes injetam cliente falso).
  static Future<String?> _tokenPadrao() async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) return null;
      return await usuario.getIdToken();
    } catch (_) {
      return null;
    }
  }

  /// GET que devolve a resposta completa da API.
  Future<Map<String, dynamic>> get(
    String caminho, {
    Map<String, dynamic>? query,
  }) async {
    if (_usaClientePadrao && AppConfig.modoServidorIntegrado) {
      return LocalApiEngine.instance.processar(
        'GET',
        caminho,
        query: query,
      );
    }
    final uri = _montarUri(caminho, query);
    final headers = await _headers();
    return _executar(
      () => _cliente.get(uri, headers: headers),
      metodo: 'GET',
      caminho: caminho,
      query: query,
    );
  }

  /// POST com corpo JSON.
  Future<Map<String, dynamic>> post(
    String caminho, {
    Map<String, dynamic>? corpo,
  }) async {
    if (_usaClientePadrao && AppConfig.modoServidorIntegrado) {
      return LocalApiEngine.instance.processar(
        'POST',
        caminho,
        corpo: corpo,
      );
    }
    final uri = _montarUri(caminho, null);
    final headers = await _headers();
    return _executar(
      () => _cliente.post(
        uri,
        headers: headers,
        body: jsonEncode(corpo ?? const <String, dynamic>{}),
      ),
      metodo: 'POST',
      caminho: caminho,
      corpo: corpo,
    );
  }

  /// PUT com corpo JSON.
  Future<Map<String, dynamic>> put(
    String caminho, {
    Map<String, dynamic>? corpo,
  }) async {
    if (_usaClientePadrao && AppConfig.modoServidorIntegrado) {
      return LocalApiEngine.instance.processar(
        'PUT',
        caminho,
        corpo: corpo,
      );
    }
    final uri = _montarUri(caminho, null);
    final headers = await _headers();
    return _executar(
      () => _cliente.put(
        uri,
        headers: headers,
        body: jsonEncode(corpo ?? const <String, dynamic>{}),
      ),
      metodo: 'PUT',
      caminho: caminho,
      corpo: corpo,
    );
  }

  /// DELETE.
  Future<Map<String, dynamic>> delete(
    String caminho, {
    Map<String, dynamic>? query,
  }) async {
    if (_usaClientePadrao && AppConfig.modoServidorIntegrado) {
      return LocalApiEngine.instance.processar(
        'DELETE',
        caminho,
        query: query,
      );
    }
    final uri = _montarUri(caminho, query);
    final headers = await _headers();
    return _executar(
      () => _cliente.delete(uri, headers: headers),
      metodo: 'DELETE',
      caminho: caminho,
      query: query,
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = await _provedorToken();
    return <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _montarUri(String caminho, Map<String, dynamic>? query) {
    final base = Uri.parse('${AppConfig.baseUrl}$caminho');
    if (query == null || query.isEmpty) return base;

    // Remove parametros nulos e converte todos os valores para String.
    final parametros = <String, String>{};
    query.forEach((chave, valor) {
      if (valor != null) parametros[chave] = valor.toString();
    });
    return base.replace(queryParameters: parametros);
  }

  /// Executa a requisicao e normaliza o envelope JSON da API.
  Future<Map<String, dynamic>> _executar(
    Future<http.Response> Function() requisicao, {
    required String metodo,
    required String caminho,
    Map<String, dynamic>? query,
    Map<String, dynamic>? corpo,
  }) async {
    late final http.Response resposta;

    try {
      resposta = await requisicao().timeout(AppConfig.timeoutRequisicao);
    } on TimeoutException {
      if (_usaClientePadrao) {
        AppConfig.ativarModoIntegrado(true);
        return LocalApiEngine.instance.processar(
          metodo,
          caminho,
          query: query,
          corpo: corpo,
        );
      }
      throw ApiException(
        'A API demorou muito para responder (${AppConfig.baseUrl}).\n'
        'Verifique se o servidor Node.js está em execução e acessível pelo seu dispositivo, ou configure o endereço da API.',
      );
    } on http.ClientException catch (erro) {
      if (_usaClientePadrao) {
        AppConfig.ativarModoIntegrado(true);
        return LocalApiEngine.instance.processar(
          metodo,
          caminho,
          query: query,
          corpo: corpo,
        );
      }
      throw ApiException(
        'Não foi possível conectar à API em ${AppConfig.baseUrl}.\n'
        'Verifique se o servidor Node.js está em execução e acessível neste endereço.\n'
        '(${erro.message})',
      );
    } catch (erro) {
      if (_usaClientePadrao) {
        AppConfig.ativarModoIntegrado(true);
        return LocalApiEngine.instance.processar(
          metodo,
          caminho,
          query: query,
          corpo: corpo,
        );
      }
      throw ApiException(
        'Falha na comunicação com a API (${AppConfig.baseUrl}): $erro',
      );
    }

    final Map<String, dynamic> json;
    try {
      // utf8.decode preserva acentos vindos do Firestore.
      json =
          jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Resposta invalida da API (HTTP ${resposta.statusCode}).',
        status: resposta.statusCode,
      );
    }

    final sucesso = json['sucesso'] == true;
    if (!sucesso || resposta.statusCode >= 400) {
      final erro = json['erro'];
      final mensagem = erro is Map && erro['mensagem'] != null
          ? erro['mensagem'].toString()
          : 'Erro HTTP ${resposta.statusCode}.';
      throw ApiException(mensagem, status: resposta.statusCode);
    }

    return json;
  }
}

/// Traduz codigos de erro do Firebase Auth para mensagens amigaveis.
String mensagemDeErroFirebase(Object erro) {
  if (erro is FirebaseAuthException) {
    switch (erro.code) {
      case 'invalid-email':
      case 'invalid-credential':
        return 'E-mail ou senha invalidos.';
      case 'user-not-found':
        return 'Nao encontramos uma conta com este e-mail.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'email-already-in-use':
        return 'Este e-mail ja esta cadastrado.';
      case 'weak-password':
        return 'A senha deve ter no minimo 6 caracteres.';
      case 'network-request-failed':
        return 'Sem conexao com o Firebase. Verifique a internet.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns instantes e tente de novo.';
      default:
        if (kDebugMode) {
          return 'Firebase: ${erro.code}';
        }
        return 'Nao foi possivel concluir a operacao. Tente novamente.';
    }
  }
  return 'Erro inesperado. Tente novamente.';
}
