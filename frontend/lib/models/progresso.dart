/// Modelos da tela de Progresso.
library;

/// Cartao de resumo: peso atual, meta e diferenca desde o inicio.
class ResumoProgresso {
  const ResumoProgresso({
    required this.pesoAtual,
    required this.pesoInicial,
    required this.diferenca,
    required this.sentido,
    required this.rotuloDiferenca,
    this.pesoMeta,
    this.restantesParaMeta,
    this.percentualMeta,
  });

  final double pesoAtual;
  final double pesoInicial;

  /// Valor absoluto da variacao desde a primeira pesagem.
  final double diferenca;

  /// 'perda' | 'ganho' | 'estavel' — define a seta exibida.
  final String sentido;

  /// Texto sob o numero grande ("Perdidos desde o inicio").
  final String rotuloDiferenca;

  final double? pesoMeta;
  final double? restantesParaMeta;

  /// 0..100 — preenchimento da barra de progresso.
  final double? percentualMeta;

  bool get ehPerda => sentido == 'perda';
  bool get ehGanho => sentido == 'ganho';

  factory ResumoProgresso.fromJson(Map<String, dynamic> json) => ResumoProgresso(
        pesoAtual: (json['pesoAtual'] as num).toDouble(),
        pesoInicial: (json['pesoInicial'] as num).toDouble(),
        diferenca: (json['diferenca'] as num).toDouble(),
        sentido: json['sentido'] as String,
        rotuloDiferenca: json['rotuloDiferenca'] as String,
        pesoMeta: (json['pesoMeta'] as num?)?.toDouble(),
        restantesParaMeta: (json['restantesParaMeta'] as num?)?.toDouble(),
        percentualMeta: (json['percentualMeta'] as num?)?.toDouble(),
      );
}

/// Um item da lista "Historico de Peso".
class RegistroPeso {
  const RegistroPeso({
    required this.idProgresso,
    required this.peso,
    required this.dataRegistro,
    this.aderenciaPlano,
  });

  /// Id do documento = data "YYYY-MM-DD" no Firestore.
  final String idProgresso;
  final double peso;
  final DateTime dataRegistro;
  final double? aderenciaPlano;

  /// Data no formato "15/03" exibido sob o peso.
  String get dataFormatada =>
      '${dataRegistro.day.toString().padLeft(2, '0')}/'
      '${dataRegistro.month.toString().padLeft(2, '0')}';

  factory RegistroPeso.fromJson(Map<String, dynamic> json) => RegistroPeso(
        idProgresso: (json['idProgresso'] ?? '') as String,
        peso: (json['peso'] as num).toDouble(),
        dataRegistro: DateTime.parse(json['dataRegistro'] as String),
        aderenciaPlano: (json['aderenciaPlano'] as num?)?.toDouble(),
      );
}

/// Registros do dia usados pela aba Bem-Estar (hidratacao e humor).
class RegistroDeHoje {
  const RegistroDeHoje({this.coposAgua = 0, this.humor});

  final int coposAgua;

  /// 'otimo' | 'bom' | 'regular' | 'ruim' (null quando nao registrado).
  final String? humor;

  factory RegistroDeHoje.fromJson(Map<String, dynamic> json) => RegistroDeHoje(
        coposAgua: (json['coposAgua'] as num?)?.toInt() ?? 0,
        humor: json['humor'] as String?,
      );
}

/// Resposta completa de GET /api/progresso/:idPaciente.
class Progresso {
  const Progresso({
    required this.nomePaciente,
    required this.resumo,
    required this.historico,
    this.objetivo,
    this.hoje = const RegistroDeHoje(),
  });

  final String nomePaciente;
  final String? objetivo;
  final ResumoProgresso resumo;
  final List<RegistroPeso> historico;
  final RegistroDeHoje hoje;

  factory Progresso.fromJson(Map<String, dynamic> json) {
    final paciente = json['paciente'] as Map<String, dynamic>? ?? const {};
    final hoje = json['hoje'] as Map<String, dynamic>?;
    return Progresso(
      nomePaciente: (paciente['nome'] ?? '') as String,
      objetivo: paciente['objetivo'] as String?,
      resumo: ResumoProgresso.fromJson(json['resumo'] as Map<String, dynamic>),
      historico: (json['historico'] as List<dynamic>? ?? const [])
          .map((item) => RegistroPeso.fromJson(item as Map<String, dynamic>))
          .toList(),
      hoje: hoje == null
          ? const RegistroDeHoje()
          : RegistroDeHoje.fromJson(hoje),
    );
  }
}
