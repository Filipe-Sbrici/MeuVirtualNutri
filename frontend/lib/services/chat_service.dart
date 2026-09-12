/// Servico da tela de Chat.
library;

import '../core/api_client.dart';
import '../models/mensagem.dart';

class ChatService {
  ChatService(this._api);

  final ApiClient _api;

  /// Conversa completa entre o usuario logado e o contato.
  Future<Conversa> carregarConversa({required String idContato}) async {
    final resposta = await _api.get('/chat/conversa/$idContato');
    return lerDados(resposta, Conversa.fromJson);
  }

  /// Busca somente as mensagens criadas depois de [ultimoId].
  /// Usado pelo polling para nao rebaixar a lista inteira.
  /// `ultimoId = null` significa "desde o inicio" (conversa vazia).
  Future<List<Mensagem>> buscarNovas({
    required String idContato,
    required String? ultimoId,
  }) async {
    final resposta = await _api.get('/chat/conversa/$idContato', query: {
      if (ultimoId != null && ultimoId.isNotEmpty) 'depoisDe': ultimoId,
    });
    return lerDados(resposta, (dados) {
      final lista = dados['mensagens'];
      if (lista is! List) return const <Mensagem>[];
      return lista
          .map((item) => Mensagem.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  /// Envia uma mensagem e devolve o registro persistido pelo servidor.
  Future<Mensagem> enviar({
    required String idContato,
    required String texto,
  }) async {
    final resposta = await _api.post('/chat/mensagens', corpo: {
      'uidContato': idContato,
      'mensagem': texto,
    });
    return lerDados(resposta, Mensagem.fromJson);
  }

  /// Contato padrao da conversa (nutricionista do paciente logado ou
  /// paciente informado pelo nutricionista).
  Future<Contato> carregarContatoPadrao({String? uidPaciente}) async {
    final resposta = await _api.get(
      '/chat/contato',
      query: {if (uidPaciente != null) 'uidPaciente': uidPaciente},
    );
    return lerDados(resposta, Contato.fromJson);
  }

  /// Total de mensagens nao lidas (banner do Bem-Estar).
  Future<int> contarNaoLidas() async {
    final resposta = await _api.get('/chat/nao-lidas');
    final dados = resposta['dados'];
    return dados is Map && dados['total'] is num
        ? (dados['total'] as num).toInt()
        : 0;
  }
}
