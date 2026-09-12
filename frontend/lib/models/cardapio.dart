/// Modelos do cardapio: refeicoes, plano semanal, receitas, lista de
/// compras, consultas e orientacoes.
library;

/// Uma refeicao do plano (checklist do paciente e editor do nutricionista).
class Refeicao {
  const Refeicao({
    required this.dia,
    required this.tipo,
    required this.rotuloDia,
    required this.rotuloTipo,
    required this.nomeReceita,
    required this.concluida,
    this.horario,
    this.idReceita,
    this.calorias = 0,
    this.proteinas = 0,
    this.carboidratos = 0,
    this.gorduras = 0,
    this.ingredientes = const [],
  });

  final String dia; // segunda..domingo
  final String tipo; // cafeManha..ceia
  final String rotuloDia;
  final String rotuloTipo;
  final String? horario;
  final String? idReceita;
  final String nomeReceita;
  final double calorias;
  final double proteinas;
  final double carboidratos;
  final double gorduras;
  final List<Ingrediente> ingredientes;
  final bool concluida;

  factory Refeicao.fromJson(Map<String, dynamic> json) => Refeicao(
        dia: (json['dia'] ?? '') as String,
        tipo: (json['tipo'] ?? '') as String,
        rotuloDia: (json['rotuloDia'] ?? '') as String,
        rotuloTipo: (json['rotuloTipo'] ?? '') as String,
        horario: json['horario'] as String?,
        idReceita: json['idReceita'] as String?,
        nomeReceita: (json['nomeReceita'] ?? '') as String,
        calorias: (json['calorias'] as num?)?.toDouble() ?? 0,
        proteinas: (json['proteinas'] as num?)?.toDouble() ?? 0,
        carboidratos: (json['carboidratos'] as num?)?.toDouble() ?? 0,
        gorduras: (json['gorduras'] as num?)?.toDouble() ?? 0,
        ingredientes: (json['ingredientes'] as List<dynamic>? ?? const [])
            .map((i) => Ingrediente.fromJson(i as Map<String, dynamic>))
            .toList(),
        concluida: json['concluida'] == true,
      );
}

/// Ingrediente de receita (alimento da base + quantidade).
///
/// Os macros sao os valores POR 100 g do alimento: a API multiplica por
/// `quantidadeG / 100` para calcular os totais da receita. Sem eles a
/// receita seria gravada com 0 kcal.
class Ingrediente {
  const Ingrediente({
    required this.nome,
    required this.quantidadeG,
    this.idAlimento,
    this.categoria,
    this.unidade = 'g',
    this.comprado = false,
    this.calorias = 0,
    this.proteinas = 0,
    this.carboidratos = 0,
    this.gorduras = 0,
  });

  /// Cria o ingrediente a partir de um alimento da base + a quantidade.
  factory Ingrediente.doAlimento(Alimento alimento, double quantidadeG) =>
      Ingrediente(
        idAlimento: alimento.idAlimento,
        nome: alimento.nome,
        categoria: alimento.categoria,
        quantidadeG: quantidadeG,
        calorias: alimento.calorias,
        proteinas: alimento.proteinas,
        carboidratos: alimento.carboidratos,
        gorduras: alimento.gorduras,
      );

  final String? idAlimento;
  final String nome;
  final String? categoria;
  final double quantidadeG;
  final String unidade;
  final bool comprado;

  // Macros por 100 g (como vem da colecao `alimentos`).
  final double calorias;
  final double proteinas;
  final double carboidratos;
  final double gorduras;

  /// Calorias que este ingrediente contribui na quantidade informada.
  double get caloriasNaPorcao => calorias * quantidadeG / 100;

  factory Ingrediente.fromJson(Map<String, dynamic> json) => Ingrediente(
        idAlimento: json['idAlimento'] as String?,
        nome: (json['nome'] ?? '') as String,
        categoria: json['categoria'] as String?,
        quantidadeG: (json['quantidadeG'] as num?)?.toDouble() ?? 0,
        unidade: (json['unidade'] ?? 'g') as String,
        comprado: json['comprado'] == true,
        calorias: (json['calorias'] as num?)?.toDouble() ?? 0,
        proteinas: (json['proteinas'] as num?)?.toDouble() ?? 0,
        carboidratos: (json['carboidratos'] as num?)?.toDouble() ?? 0,
        gorduras: (json['gorduras'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'idAlimento': idAlimento,
        'nome': nome,
        'categoria': categoria,
        'quantidadeG': quantidadeG,
        'unidade': unidade,
        'calorias': calorias,
        'proteinas': proteinas,
        'carboidratos': carboidratos,
        'gorduras': gorduras,
      };
}

/// Resumo do checklist do dia.
class ResumoChecklist {
  const ResumoChecklist({
    required this.total,
    required this.concluidas,
    required this.percentual,
    required this.totalCalorias,
    required this.caloriasConcluidas,
  });

  final int total;
  final int concluidas;
  final double percentual;
  final double totalCalorias;
  final double caloriasConcluidas;

  factory ResumoChecklist.fromJson(Map<String, dynamic> json) =>
      ResumoChecklist(
        total: (json['total'] as num?)?.toInt() ?? 0,
        concluidas: (json['concluidas'] as num?)?.toInt() ?? 0,
        percentual: (json['percentual'] as num?)?.toDouble() ?? 0,
        totalCalorias: (json['totalCalorias'] as num?)?.toDouble() ?? 0,
        caloriasConcluidas:
            (json['caloriasConcluidas'] as num?)?.toDouble() ?? 0,
      );
}

/// Cardapio do dia (aba "Cardapio" da tela central do paciente).
class CardapioDoDia {
  const CardapioDoDia({
    required this.dia,
    required this.refeicoes,
    this.plano,
    this.resumo,
  });

  final String dia;
  final List<Refeicao> refeicoes;
  final ResumoChecklist? resumo;

  /// Metadados do plano (idPlano, nomePlano, objetivo) ou null.
  final Map<String, dynamic>? plano;

  String? get nomePlano => plano?['nomePlano'] as String?;

  factory CardapioDoDia.fromJson(Map<String, dynamic> json) => CardapioDoDia(
        dia: (json['dia'] ?? '') as String,
        plano: json['plano'] as Map<String, dynamic>?,
        refeicoes: (json['refeicoes'] as List<dynamic>? ?? const [])
            .map((r) => Refeicao.fromJson(r as Map<String, dynamic>))
            .toList(),
        resumo: json['resumo'] == null
            ? null
            : ResumoChecklist.fromJson(json['resumo'] as Map<String, dynamic>),
      );
}

/// Plano semanal completo (tela 4.5.13).
class PlanoSemanal {
  const PlanoSemanal({
    required this.dias,
    this.nomePlano,
    this.preenchidas = 0,
    this.total = 42,
  });

  final String? nomePlano;
  final List<DiaPlano> dias;
  final int preenchidas;
  final int total;

  factory PlanoSemanal.fromJson(Map<String, dynamic> json) {
    final progresso = json['progressoMontagem'] as Map<String, dynamic>?;
    return PlanoSemanal(
      nomePlano: (json['plano'] as Map<String, dynamic>?)?['nomePlano']
          as String?,
      dias: (json['dias'] as List<dynamic>? ?? const [])
          .map((d) => DiaPlano.fromJson(d as Map<String, dynamic>))
          .toList(),
      preenchidas: (progresso?['preenchidas'] as num?)?.toInt() ?? 0,
      total: (progresso?['total'] as num?)?.toInt() ?? 42,
    );
  }
}

/// Um dia do plano semanal.
class DiaPlano {
  const DiaPlano({required this.dia, required this.rotulo, required this.refeicoes});

  final String dia;
  final String rotulo;
  final List<Refeicao> refeicoes;

  factory DiaPlano.fromJson(Map<String, dynamic> json) => DiaPlano(
        dia: (json['dia'] ?? '') as String,
        rotulo: (json['rotulo'] ?? '') as String,
        refeicoes: (json['refeicoes'] as List<dynamic>? ?? const [])
            .map((r) => Refeicao.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

/// Uma receita da biblioteca do nutricionista.
class Receita {
  const Receita({
    required this.idReceita,
    required this.nome,
    required this.ingredientes,
    this.modoPreparo = '',
    this.calorias = 0,
    this.proteinas = 0,
    this.carboidratos = 0,
    this.gorduras = 0,
    this.status = 'aprovada',
    this.justificativa,
  });

  final String idReceita;
  final String nome;
  final String modoPreparo;
  final List<Ingrediente> ingredientes;
  final double calorias;
  final double proteinas;
  final double carboidratos;
  final double gorduras;

  /// aprovada | pendente | recusada
  final String status;
  final String? justificativa;

  factory Receita.fromJson(Map<String, dynamic> json) => Receita(
        idReceita: (json['idReceita'] ?? '') as String,
        nome: (json['nome'] ?? '') as String,
        modoPreparo: (json['modoPreparo'] ?? '') as String,
        ingredientes: (json['ingredientes'] as List<dynamic>? ?? const [])
            .map((i) => Ingrediente.fromJson(i as Map<String, dynamic>))
            .toList(),
        calorias: (json['calorias'] as num?)?.toDouble() ?? 0,
        proteinas: (json['proteinas'] as num?)?.toDouble() ?? 0,
        carboidratos: (json['carboidratos'] as num?)?.toDouble() ?? 0,
        gorduras: (json['gorduras'] as num?)?.toDouble() ?? 0,
        status: (json['status'] ?? 'aprovada') as String,
        justificativa: json['justificativa'] as String?,
      );
}

/// Alimento da base (para montar receitas).
class Alimento {
  const Alimento({
    required this.idAlimento,
    required this.nome,
    required this.categoria,
    required this.calorias,
    required this.proteinas,
    required this.carboidratos,
    required this.gorduras,
  });

  final String idAlimento;
  final String nome;
  final String categoria;
  final double calorias;
  final double proteinas;
  final double carboidratos;
  final double gorduras;

  factory Alimento.fromJson(Map<String, dynamic> json) => Alimento(
        idAlimento: (json['idAlimento'] ?? '') as String,
        nome: (json['nome'] ?? '') as String,
        categoria: (json['categoria'] ?? 'Outros') as String,
        calorias: (json['calorias'] as num?)?.toDouble() ?? 0,
        proteinas: (json['proteinas'] as num?)?.toDouble() ?? 0,
        carboidratos: (json['carboidratos'] as num?)?.toDouble() ?? 0,
        gorduras: (json['gorduras'] as num?)?.toDouble() ?? 0,
      );
}

/// Item agregado da lista de compras (gerado ou manual).
class ItemCompra {
  const ItemCompra({
    this.id,
    required this.nome,
    required this.categoria,
    required this.quantidadeG,
    this.idAlimento,
    this.unidade = 'g',
    this.comprado = false,
    this.manual = false,
  });

  final String? id;
  final String? idAlimento;
  final String nome;
  final String categoria;
  final double quantidadeG;
  final String unidade;
  final bool comprado;
  final bool manual;

  factory ItemCompra.fromJson(Map<String, dynamic> json) => ItemCompra(
        id: json['id'] as String?,
        idAlimento: json['idAlimento'] as String?,
        nome: (json['nome'] ?? '') as String,
        categoria: (json['categoria'] ?? 'Outros') as String,
        quantidadeG: (json['quantidadeG'] as num?)?.toDouble() ??
            (json['quantidade'] as num?)?.toDouble() ??
            0,
        unidade: (json['unidade'] ?? 'g') as String,
        comprado: json['comprado'] == true,
        manual: json['manual'] == true,
      );
}

/// Uma consulta da agenda.
class Consulta {
  const Consulta({
    required this.idConsulta,
    required this.dataHora,
    required this.status,
    this.uidNutricionista,
    this.nomeNutricionista,
    this.uidPaciente,
    this.nomePaciente,
    this.observacoes = '',
  });

  final String idConsulta;
  final DateTime dataHora;

  /// disponivel | pendente | confirmada | concluida | cancelada
  final String status;
  final String? uidNutricionista;
  final String? nomeNutricionista;
  final String? uidPaciente;
  final String? nomePaciente;
  final String observacoes;

  bool get ehDisponivel => status == 'disponivel';
  bool get ehPendente => status == 'pendente';
  bool get ehConfirmada => status == 'confirmada';
  bool get ehConcluida => status == 'concluida';
  bool get ehCancelada => status == 'cancelada';

  String get diaSemanaExtenso {
    const dias = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    // weekday vai de 1 (Monday) a 7 (Sunday)
    final idx = (dataHora.weekday - 1).clamp(0, 6);
    return dias[idx];
  }

  String get horaFormatada {
    final h = dataHora.hour.toString().padLeft(2, '0');
    final m = dataHora.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get dataFormatada {
    final d = dataHora.day.toString().padLeft(2, '0');
    final m = dataHora.month.toString().padLeft(2, '0');
    return '$d/$m/${dataHora.year}';
  }

  String get dataCompletaExtenso =>
      '$diaSemanaExtenso, $dataFormatada às $horaFormatada';

  String get descricaoCompleta =>
      '$diaSemanaExtenso, $dataFormatada às $horaFormatada';

  factory Consulta.fromJson(Map<String, dynamic> json) => Consulta(
        idConsulta: (json['idConsulta'] ?? '') as String,
        dataHora:
            DateTime.tryParse(json['dataHora']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
        status: (json['status'] ?? 'disponivel') as String,
        uidNutricionista: json['uidNutricionista'] as String?,
        nomeNutricionista: json['nomeNutricionista'] as String?,
        uidPaciente: json['uidPaciente'] as String?,
        nomePaciente: json['nomePaciente'] as String?,
        observacoes: (json['observacoes'] ?? '') as String,
      );
}

/// Uma orientacao/feedback do nutricionista.
class Orientacao {
  const Orientacao({
    required this.idOrientacao,
    required this.categoria,
    required this.texto,
    required this.criadoEm,
    this.lida = false,
    this.confirmada = false,
    this.confirmadaEm,
  });

  final String idOrientacao;

  /// positivo | neutro | melhoria
  final String categoria;
  final String texto;
  final bool lida;
  final bool confirmada;
  final DateTime? confirmadaEm;
  final DateTime criadoEm;

  factory Orientacao.fromJson(Map<String, dynamic> json) => Orientacao(
        idOrientacao: (json['idOrientacao'] ?? '') as String,
        categoria: (json['categoria'] ?? 'neutro') as String,
        texto: (json['texto'] ?? '') as String,
        lida: json['lida'] == true,
        confirmada: json['confirmada'] == true,
        confirmadaEm: DateTime.tryParse(json['confirmadaEm']?.toString() ?? '')
            ?.toLocal(),
        criadoEm:
            DateTime.tryParse(json['criadoEm']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
      );
}

/// Resumo clinico de um paciente (painel do nutricionista).
class PacienteResumo {
  const PacienteResumo({
    required this.uid,
    required this.nome,
    required this.email,
    this.idade,
    this.pesoAtual,
    this.pesoMeta,
    this.altura,
    this.genero,
    this.objetivo,
    this.tipoDieta,
    this.alimentosFavoritos = const [],
    this.alimentosRejeitados = const [],
    this.restricoes = const [],
    this.condicoesMedicas = const [],
    this.compartilharListaCompras = true,
    this.compartilharHumor = true,
    this.observacoesSeguranca = '',
    this.temPlanoAtivo = false,
    this.nomePlano,
  });

  final String uid;
  final String nome;
  final String email;
  final int? idade;
  final double? pesoAtual;
  final double? pesoMeta;
  final double? altura;
  final String? genero;
  final String? objetivo;
  final String? tipoDieta;
  final List<String> alimentosFavoritos;
  final List<String> alimentosRejeitados;
  final List<String> restricoes;
  final List<String> condicoesMedicas;
  final bool compartilharListaCompras;
  final bool compartilharHumor;
  final String observacoesSeguranca;
  final bool temPlanoAtivo;
  final String? nomePlano;

  factory PacienteResumo.fromJson(Map<String, dynamic> json) =>
      PacienteResumo(
        uid: (json['uid'] ?? '') as String,
        nome: (json['nome'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        idade: (json['idade'] as num?)?.toInt(),
        pesoAtual: (json['pesoAtual'] as num?)?.toDouble(),
        pesoMeta: (json['pesoMeta'] as num?)?.toDouble(),
        altura: (json['altura'] as num?)?.toDouble(),
        genero: json['genero'] as String?,
        objetivo: (json['objetivo'] ?? json['meta']) as String?,
        tipoDieta: json['tipoDieta'] as String?,
        alimentosFavoritos: (json['alimentosFavoritos'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        alimentosRejeitados: (json['alimentosRejeitados'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        restricoes: (json['restricoes'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        condicoesMedicas: (json['condicoesMedicas'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        compartilharListaCompras: json['compartilharListaCompras'] != false,
        compartilharHumor: json['compartilharHumor'] != false,
        observacoesSeguranca: (json['observacoesSeguranca'] ?? '') as String,
        temPlanoAtivo: json['temPlanoAtivo'] == true,
        nomePlano: json['nomePlano'] as String?,
      );
}


/// Item do relatorio analitico do nutricionista.
class RelatorioPaciente {
  const RelatorioPaciente({
    required this.uid,
    required this.nome,
    required this.evolucaoPeso,
    this.objetivo,
    this.nomePlano,
    this.aderenciaMedia,
    this.frequenciaRegistros = 0,
    this.variacao30d = 0,
  });

  final String uid;
  final String nome;
  final String? objetivo;
  final String? nomePlano;
  final List<PontoPesoRelatorio> evolucaoPeso;
  final double? aderenciaMedia;
  final int frequenciaRegistros;

  /// Variacao de peso nos ultimos 30 dias (positivo = perdeu peso).
  final double variacao30d;

  /// Peso mais recente do periodo (null sem pesagens).
  double? get pesoAtual =>
      evolucaoPeso.isEmpty ? null : evolucaoPeso.last.peso;

  factory RelatorioPaciente.fromJson(Map<String, dynamic> json) {
    final evolucao = json['evolucaoPeso'] as Map<String, dynamic>?;
    return RelatorioPaciente(
      uid: (json['uid'] ?? '') as String,
      nome: (json['nome'] ?? '') as String,
      objetivo: json['objetivo'] as String?,
      nomePlano: json['nomePlano'] as String?,
      evolucaoPeso: ((evolucao?['pontos'] as List<dynamic>?) ?? const [])
          .map((p) => PontoPesoRelatorio.fromJson(p as Map<String, dynamic>))
          .toList(),
      variacao30d: (evolucao?['variacao30d'] as num?)?.toDouble() ?? 0,
      aderenciaMedia: (json['aderenciaMedia'] as num?)?.toDouble(),
      frequenciaRegistros:
          (json['frequenciaRegistros'] as num?)?.toInt() ?? 0,
    );
  }
}

class PontoPesoRelatorio {
  const PontoPesoRelatorio({required this.data, required this.peso});

  final String data;
  final double peso;

  factory PontoPesoRelatorio.fromJson(Map<String, dynamic> json) =>
      PontoPesoRelatorio(
        data: (json['data'] ?? '') as String,
        peso: (json['peso'] as num?)?.toDouble() ?? 0,
      );
}
