/// Cliente HTTP compartilhado pelos servicos.
///
/// Concentra a montagem das URLs, a serializacao JSON, a injecao do
/// token do Firebase Authentication em cada requisicao e o tratamento
/// de erros, para que os servicos e as telas nunca lidem com `http`
/// direto.
library;

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';

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
      : _cliente = cliente ?? http.Client(),
        _provedorToken = provedorToken ?? _tokenPadrao;

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
    final uri = _montarUri(caminho, query);
    final headers = await _headers();
    return _executar(() => _cliente.get(uri, headers: headers));
  }

  /// POST com corpo JSON.
  Future<Map<String, dynamic>> post(
    String caminho, {
    Map<String, dynamic>? corpo,
  }) async {
    final uri = _montarUri(caminho, null);
    final headers = await _headers();
    return _executar(
      () => _cliente.post(
        uri,
        headers: headers,
        body: jsonEncode(corpo ?? const {}),
      ),
    );
  }

  /// PUT com corpo JSON.
  Future<Map<String, dynamic>> put(
    String caminho, {
    Map<String, dynamic>? corpo,
  }) async {
    final uri = _montarUri(caminho, null);
    final headers = await _headers();
    return _executar(
      () => _cliente.put(
        uri,
        headers: headers,
        body: jsonEncode(corpo ?? const {}),
      ),
    );
  }

  /// DELETE.
  Future<Map<String, dynamic>> delete(
    String caminho, {
    Map<String, dynamic>? query,
  }) async {
    final uri = _montarUri(caminho, query);
    final headers = await _headers();
    return _executar(() => _cliente.delete(uri, headers: headers));
  }

  Future<Map<String, String>> _headers() async {
    final token = await _provedorToken();
    return {
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
  ///
  /// A API responde sempre no formato:
  ///   sucesso: { "sucesso": true,  "dados": {...} }
  ///   erro:    { "sucesso": false, "erro": { "mensagem": "..." } }
  Future<Map<String, dynamic>> _executar(
    Future<http.Response> Function() requisicao,
  ) async {
    late final http.Response resposta;

    try {
      resposta = await requisicao().timeout(AppConfig.timeoutRequisicao);
    } on TimeoutException {
      throw ApiException('A API demorou muito para responder. Tente novamente.');
    } on http.ClientException catch (erro) {
      // Servidor fora do ar, host errado ou recusa de conexao.
      // Nao usamos SocketException (dart:io) para que este arquivo
      // compile tambem em Flutter Web.
      throw ApiException(
        'Nao foi possivel conectar a API.\n'
        'Verifique se o servidor Node.js esta rodando em ${AppConfig.baseUrl}.\n'
        '(${erro.message})',
      );
    } catch (erro) {
      throw ApiException('Falha na comunicacao com a API: $erro');
    }

    Map<String, dynamic> json;
    try {
      // utf8.decode preserva acentos vindos do Firestore.
      json = jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
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

    // Algumas rotas devolvem campos extras ao lado de `dados`
    // (ex.: `registro` no POST de peso). Preservamos a resposta inteira
    // e expomos `dados` de forma conveniente.
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
