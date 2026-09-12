/// Modelos da tela de Chat.
library;

/// Contato exibido no cabecalho ("Dr. Gabriel" / "Nutricionista").
class Contato {
  const Contato({
    required this.idUsuario,
    required this.nome,
    required this.papel,
    this.crn,
    this.especializacao,
  });

  final String idUsuario;
  final String nome;

  /// Rotulo sob o nome no cabecalho.
  final String papel;

  final String? crn;
  final String? especializacao;

  factory Contato.fromJson(Map<String, dynamic> json) => Contato(
        idUsuario: (json['idUsuario'] ?? json['uid'] ?? '') as String,
        nome: (json['nome'] ?? '') as String,
        papel: (json['papel'] ?? '') as String,
        crn: json['crn'] as String?,
        especializacao: json['especializacao'] as String?,
      );
}

/// Uma mensagem do chat.
class Mensagem {
  const Mensagem({
    required this.idMensagem,
    required this.idRemetente,
    required this.idDestinatario,
    required this.nomeRemetente,
    required this.texto,
    required this.dataHora,
    required this.ehMinha,
    this.pendente = false,
  });

  /// Id do documento Firestore (string monotonica).
  final String idMensagem;
  final String idRemetente;
  final String idDestinatario;
  final String nomeRemetente;
  final String texto;
  final DateTime dataHora;

  /// Definido pela API comparando o remetente com o usuario logado.
  /// Controla o lado e o estilo do balao.
  final bool ehMinha;

  /// true enquanto a mensagem existe apenas localmente (envio otimista).
  final bool pendente;

  /// Horario no formato "11:54" exibido dentro do balao.
  String get horaFormatada =>
      '${dataHora.hour.toString().padLeft(2, '0')}:'
      '${dataHora.minute.toString().padLeft(2, '0')}';

  factory Mensagem.fromJson(Map<String, dynamic> json) => Mensagem(
        idMensagem: (json['idMensagem'] ?? '') as String,
        idRemetente: (json['idRemetente'] ?? '') as String,
        idDestinatario: (json['idDestinatario'] ?? '') as String,
        nomeRemetente: (json['nomeRemetente'] ?? '') as String,
        texto: (json['mensagem'] ?? '') as String,
        // A API envia ISO-8601 local sem fuso ("2026-08-16T11:54:00"),
        // portanto o parse resulta na hora exata gravada no banco.
        dataHora: DateTime.tryParse(json['dataHora']?.toString() ?? '') ??
            DateTime.now(),
        ehMinha: json['ehMinha'] == true,
      );
}

/// Resposta completa de GET /api/chat/conversa.
class Conversa {
  const Conversa({required this.contato, required this.mensagens});

  final Contato contato;
  final List<Mensagem> mensagens;

  factory Conversa.fromJson(Map<String, dynamic> json) => Conversa(
        contato: Contato.fromJson(json['contato'] as Map<String, dynamic>),
        mensagens: (json['mensagens'] as List<dynamic>? ?? const [])
            .map((item) => Mensagem.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
