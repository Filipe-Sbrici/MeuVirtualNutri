/// Modelo de usuario logado (sessao).
///
/// Com o Firebase Authentication, o identificador principal e o UID.
/// Os campos idUsuario/idPaciente/idNutricionista sao mantidos no
/// contrato JSON para compatibilidade com as telas existentes.
library;

class Usuario {
  const Usuario({
    required this.uid,
    required this.nome,
    required this.email,
    required this.tipoUsuario,
    this.emailVerificado = true,
    this.telefone,
    this.crn,
    this.especializacao,
    this.onboardingCompleto = false,
    this.tutorialVisto = false,
    // Assinatura do nutricionista (Mercado Pago + Firestore).
    this.planoAssinatura = 'gratuito',
    this.statusAssinatura = 'inativa',
    this.ehAssinante = false,
    this.limitePacientes = 15,
    this.precoAssinatura = 29.90,
    this.assinaturaValidaAte,
    this.idAssinaturaMp,
    this.metodoPagamentoAssinatura,
    // Campos clinicos do paciente.
    this.idade,
    this.pesoAtual,
    this.pesoMeta,
    this.altura,
    this.genero,
    this.meta,
    this.nivelAtividade,
    this.tipoDieta,
    this.idNutricionista,
    this.alimentosFavoritos = const [],
    this.alimentosRejeitados = const [],
    this.restricoes = const [],
    this.condicoesMedicas = const [],
    this.compartilharListaCompras = true,
    this.compartilharHumor = true,
    this.observacoesSeguranca = '',
  });

  final String uid;

  final String nome;
  final String email;
  final bool emailVerificado;
  final String? telefone;
  final String tipoUsuario;
  final String? crn;
  final String? especializacao;

  final bool onboardingCompleto;
  final bool tutorialVisto;

  // ----- Assinatura (nutricionista) -----
  final String planoAssinatura;
  final String statusAssinatura;
  final bool ehAssinante;
  final int? limitePacientes;
  final double precoAssinatura;
  final String? assinaturaValidaAte;
  final String? idAssinaturaMp;
  final String? metodoPagamentoAssinatura;

  // ----- Campos clinicos (paciente) -----
  final int? idade;
  final double? pesoAtual;
  final double? pesoMeta;
  final double? altura;
  final String? genero;
  final String? meta;
  final String? nivelAtividade;
  final String? tipoDieta;
  final String? idNutricionista;
  final List<String> alimentosFavoritos;
  final List<String> alimentosRejeitados;
  final List<String> restricoes;
  final List<String> condicoesMedicas;
  final bool compartilharListaCompras;
  final bool compartilharHumor;
  final String observacoesSeguranca;

  bool get ehPaciente => tipoUsuario == 'paciente';
  bool get ehNutricionista => tipoUsuario == 'nutricionista';

  /// IMC calculado (ou null sem peso/altura).
  double? get imc {
    if (pesoAtual == null || altura == null || altura! <= 0) return null;
    return pesoAtual! / (altura! * altura!);
  }

  Usuario copiarCom(Map<String, dynamic> mudancas) => Usuario(
        uid: uid,
        nome: mudancas['nome'] ?? nome,
        email: mudancas['email'] ?? email,
        emailVerificado:
            mudancas['emailVerificado'] as bool? ?? emailVerificado,
        tipoUsuario: mudancas['tipoUsuario'] ?? tipoUsuario,
        telefone: mudancas['telefone'] ?? telefone,
        crn: mudancas.containsKey('crn') ? mudancas['crn'] as String? : crn,
        especializacao: mudancas.containsKey('especializacao')
            ? mudancas['especializacao'] as String?
            : especializacao,
        onboardingCompleto:
            mudancas['onboardingCompleto'] ?? onboardingCompleto,
        tutorialVisto: mudancas['tutorialVisto'] ?? tutorialVisto,
        planoAssinatura:
            mudancas['planoAssinatura'] as String? ?? planoAssinatura,
        statusAssinatura:
            mudancas['statusAssinatura'] as String? ?? statusAssinatura,
        ehAssinante: mudancas['ehAssinante'] as bool? ?? ehAssinante,
        limitePacientes: mudancas.containsKey('limitePacientes')
            ? mudancas['limitePacientes'] as int?
            : limitePacientes,
        precoAssinatura:
            (mudancas['precoAssinatura'] as num?)?.toDouble() ?? precoAssinatura,
        assinaturaValidaAte: mudancas.containsKey('assinaturaValidaAte')
            ? mudancas['assinaturaValidaAte'] as String?
            : assinaturaValidaAte,
        idAssinaturaMp: mudancas.containsKey('idAssinaturaMp')
            ? mudancas['idAssinaturaMp'] as String?
            : idAssinaturaMp,
        metodoPagamentoAssinatura:
            mudancas.containsKey('metodoPagamentoAssinatura')
                ? mudancas['metodoPagamentoAssinatura'] as String?
                : metodoPagamentoAssinatura,
        idade:
            mudancas.containsKey('idade') ? mudancas['idade'] as int? : idade,
        pesoAtual: mudancas.containsKey('pesoAtual')
            ? mudancas['pesoAtual'] as double?
            : pesoAtual,
        pesoMeta: mudancas.containsKey('pesoMeta')
            ? mudancas['pesoMeta'] as double?
            : pesoMeta,
        altura: mudancas.containsKey('altura')
            ? mudancas['altura'] as double?
            : altura,
        genero: mudancas.containsKey('genero')
            ? mudancas['genero'] as String?
            : genero,
        meta: mudancas.containsKey('meta') ? mudancas['meta'] as String? : meta,
        nivelAtividade: mudancas.containsKey('nivelAtividade')
            ? mudancas['nivelAtividade'] as String?
            : nivelAtividade,
        tipoDieta: mudancas.containsKey('tipoDieta')
            ? mudancas['tipoDieta'] as String?
            : tipoDieta,
        idNutricionista: mudancas.containsKey('idNutricionista')
            ? mudancas['idNutricionista'] as String?
            : idNutricionista,
        alimentosFavoritos: mudancas['alimentosFavoritos'] as List<String>? ??
            alimentosFavoritos,
        alimentosRejeitados: mudancas['alimentosRejeitados'] as List<String>? ??
            alimentosRejeitados,
        restricoes: mudancas['restricoes'] as List<String>? ?? restricoes,
        condicoesMedicas:
            mudancas['condicoesMedicas'] as List<String>? ?? condicoesMedicas,
        compartilharListaCompras:
            mudancas['compartilharListaCompras'] ?? compartilharListaCompras,
        compartilharHumor: mudancas['compartilharHumor'] ?? compartilharHumor,
        observacoesSeguranca:
            mudancas['observacoesSeguranca'] ?? observacoesSeguranca,
      );

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final plano = (json['planoAssinatura'] ?? 'gratuito') as String;
    final status = (json['statusAssinatura'] ?? 'inativa') as String;
    final assinante =
        json['ehAssinante'] == true || (plano == 'pro' && status == 'ativa');

    return Usuario(
      uid: (json['idUsuario'] ?? json['uid'] ?? '') as String,
      nome: (json['nome'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      emailVerificado: json['emailVerificado'] != false,
      telefone: json['telefone'] as String?,
      tipoUsuario: (json['tipoUsuario'] ?? 'paciente') as String,
      crn: json['crn'] as String?,
      especializacao: json['especializacao'] as String?,
      onboardingCompleto: json['onboardingCompleto'] == true,
      tutorialVisto: json['tutorialVisto'] == true,
      planoAssinatura: plano,
      statusAssinatura: status,
      ehAssinante: assinante,
      limitePacientes:
          assinante ? null : ((json['limitePacientes'] as num?)?.toInt() ?? 15),
      precoAssinatura: (json['precoAssinatura'] as num?)?.toDouble() ?? 29.90,
      assinaturaValidaAte: json['assinaturaValidaAte'] as String?,
      idAssinaturaMp: json['idAssinaturaMp'] as String?,
      metodoPagamentoAssinatura: json['metodoPagamentoAssinatura'] as String?,
      idade: (json['idade'] as num?)?.toInt(),
      pesoAtual: (json['pesoAtual'] as num?)?.toDouble(),
      pesoMeta: (json['pesoMeta'] as num?)?.toDouble(),
      altura: (json['altura'] as num?)?.toDouble(),
      genero: json['genero'] as String?,
      meta: json['meta'] as String?,
      nivelAtividade: json['nivelAtividade'] as String?,
      tipoDieta: json['tipoDieta'] as String?,
      idNutricionista: json['idNutricionista'] as String?,
      alimentosFavoritos: _lista(json['alimentosFavoritos']),
      alimentosRejeitados: _lista(json['alimentosRejeitados']),
      restricoes: _lista(json['restricoes']),
      condicoesMedicas: _lista(json['condicoesMedicas']),
      compartilharListaCompras: json['compartilharListaCompras'] != false,
      compartilharHumor: json['compartilharHumor'] != false,
      observacoesSeguranca: (json['observacoesSeguranca'] ?? '') as String,
    );
  }

  static List<String> _lista(dynamic valor) =>
      valor is List ? valor.map((e) => e.toString()).toList() : const [];
}

/// Resumo de nutricionista exibido na etapa 1 do onboarding.
class NutricionistaResumo {
  const NutricionistaResumo({
    required this.uid,
    required this.nome,
    this.crn,
    this.especializacao,
  });

  final String uid;
  final String nome;
  final String? crn;
  final String? especializacao;

  factory NutricionistaResumo.fromJson(Map<String, dynamic> json) =>
      NutricionistaResumo(
        uid: (json['uid'] ?? '') as String,
        nome: (json['nome'] ?? '') as String,
        crn: json['crn'] as String?,
        especializacao: json['especializacao'] as String?,
      );
}

/// Estado detalhado da assinatura do nutricionista (Mercado Pago + Firestore).
class StatusAssinaturaNutricionista {
  const StatusAssinaturaNutricionista({
    required this.planoAssinatura,
    required this.statusAssinatura,
    required this.ehAssinante,
    required this.precoMensal,
    this.limitePacientes = 15,
    this.limitePlanoGratuito = 15,
    this.totalPacientesAtivos = 0,
    this.restantesGratuito = 15,
    this.limiteAtingido = false,
    this.assinaturaValidaAte,
    this.idAssinaturaMp,
    this.checkoutUrl,
    this.metodoPagamento = 'pix',
    this.modoIntegracao = 'mercadopago_sandbox_local',
  });

  final String planoAssinatura;
  final String statusAssinatura;
  final bool ehAssinante;
  final double precoMensal;
  final int? limitePacientes;
  final int limitePlanoGratuito;
  final int totalPacientesAtivos;
  final int? restantesGratuito;
  final bool limiteAtingido;
  final String? assinaturaValidaAte;
  final String? idAssinaturaMp;
  final String? checkoutUrl;
  final String metodoPagamento;
  final String modoIntegracao;

  factory StatusAssinaturaNutricionista.fromJson(Map<String, dynamic> json) {
    final plano = (json['planoAssinatura'] ?? 'gratuito') as String;
    final status = (json['statusAssinatura'] ?? 'inativa') as String;
    final assinante =
        json['ehAssinante'] == true || (plano == 'pro' && status == 'ativa');
    final limiteGratuito =
        (json['limitePlanoGratuito'] as num?)?.toInt() ?? 15;
    final totalAtivos = (json['totalPacientesAtivos'] as num?)?.toInt() ?? 0;

    return StatusAssinaturaNutricionista(
      planoAssinatura: plano,
      statusAssinatura: status,
      ehAssinante: assinante,
      precoMensal: (json['precoMensal'] as num?)?.toDouble() ?? 29.90,
      limitePacientes:
          assinante ? null : ((json['limitePacientes'] as num?)?.toInt() ?? 15),
      limitePlanoGratuito: limiteGratuito,
      totalPacientesAtivos: totalAtivos,
      restantesGratuito: assinante
          ? null
          : ((json['restantesGratuito'] as num?)?.toInt() ??
              (limiteGratuito - totalAtivos).clamp(0, limiteGratuito)),
      limiteAtingido: json['limiteAtingido'] == true ||
          (!assinante && totalAtivos >= limiteGratuito),
      assinaturaValidaAte: json['assinaturaValidaAte'] as String?,
      idAssinaturaMp: json['idAssinaturaMp'] as String?,
      checkoutUrl: json['checkoutUrl'] as String?,
      metodoPagamento: (json['metodoPagamento'] ?? 'pix') as String,
      modoIntegracao:
          (json['modoIntegracao'] ?? 'mercadopago_sandbox_local') as String,
    );
  }
}
