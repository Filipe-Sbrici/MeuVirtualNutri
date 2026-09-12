/// Modelos da tela de Evolucao (tres cartoes com graficos).
library;

/// Um ponto do grafico de linha "Evolucao de Peso".
class PontoPeso {
  const PontoPeso({required this.data, required this.peso});

  final DateTime data;
  final double peso;

  /// Rotulo do eixo X no formato "15/03".
  String get rotulo =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}';

  factory PontoPeso.fromJson(Map<String, dynamic> json) => PontoPeso(
        data: DateTime.parse(json['data'] as String),
        peso: (json['peso'] as num).toDouble(),
      );
}

/// Cartao 1 - serie de peso e limites sugeridos do eixo Y.
class EvolucaoPeso {
  const EvolucaoPeso({
    required this.pontos,
    required this.variacao,
    this.minimo,
    this.maximo,
  });

  final List<PontoPeso> pontos;
  final double variacao;
  final double? minimo;
  final double? maximo;

  bool get vazio => pontos.isEmpty;

  factory EvolucaoPeso.fromJson(Map<String, dynamic> json) => EvolucaoPeso(
        pontos: (json['pontos'] as List<dynamic>? ?? const [])
            .map((item) => PontoPeso.fromJson(item as Map<String, dynamic>))
            .toList(),
        variacao: (json['variacao'] as num?)?.toDouble() ?? 0,
        minimo: (json['minimo'] as num?)?.toDouble(),
        maximo: (json['maximo'] as num?)?.toDouble(),
      );
}

/// Uma barra do grafico "Consumo Calorico Semanal".
class BarraConsumo {
  const BarraConsumo({
    required this.rotulo,
    required this.consumido,
    this.meta,
  });

  /// "Seg", "Ter", ...
  final String rotulo;
  final double consumido;
  final double? meta;

  factory BarraConsumo.fromJson(Map<String, dynamic> json) => BarraConsumo(
        rotulo: json['rotulo'] as String,
        consumido: (json['consumido'] as num?)?.toDouble() ?? 0,
        meta: (json['meta'] as num?)?.toDouble(),
      );
}

/// Cartao 2 - consumo calorico da semana.
class ConsumoSemanal {
  const ConsumoSemanal({
    required this.barras,
    required this.mediaConsumida,
    required this.maximoEixo,
    this.meta,
  });

  final List<BarraConsumo> barras;
  final double mediaConsumida;
  final double maximoEixo;
  final double? meta;

  factory ConsumoSemanal.fromJson(Map<String, dynamic> json) => ConsumoSemanal(
        barras: (json['barras'] as List<dynamic>? ?? const [])
            .map((item) => BarraConsumo.fromJson(item as Map<String, dynamic>))
            .toList(),
        mediaConsumida: (json['mediaConsumida'] as num?)?.toDouble() ?? 0,
        maximoEixo: (json['maximoEixo'] as num?)?.toDouble() ?? 2200,
        meta: (json['meta'] as num?)?.toDouble(),
      );
}

/// Um macronutriente do cartao 3.
class ItemMacro {
  const ItemMacro({
    required this.chave,
    required this.rotulo,
    this.consumido,
    this.meta,
    this.percentual,
  });

  /// 'proteinas' | 'carboidratos' | 'gorduras'
  final String chave;
  final String rotulo;
  final int? consumido;
  final int? meta;
  final double? percentual;

  /// Texto "75g / 80g" exibido a direita do rotulo.
  String get textoValores {
    if (consumido == null || meta == null) return '--';
    return '${consumido}g / ${meta}g';
  }

  factory ItemMacro.fromJson(Map<String, dynamic> json) => ItemMacro(
        chave: json['chave'] as String,
        rotulo: json['rotulo'] as String,
        consumido: (json['consumido'] as num?)?.round(),
        meta: (json['meta'] as num?)?.round(),
        percentual: (json['percentual'] as num?)?.toDouble(),
      );
}

/// Cartao 3 - macronutrientes medios da semana.
class Macronutrientes {
  const Macronutrientes({
    required this.itens,
    this.aderenciaMedia,
    this.origemMeta,
  });

  final List<ItemMacro> itens;
  final double? aderenciaMedia;

  /// 'plano_alimentar' ou 'calculo_mifflin_st_jeor'.
  final String? origemMeta;

  factory Macronutrientes.fromJson(Map<String, dynamic> json) => Macronutrientes(
        itens: (json['itens'] as List<dynamic>? ?? const [])
            .map((item) => ItemMacro.fromJson(item as Map<String, dynamic>))
            .toList(),
        aderenciaMedia: (json['aderenciaMedia'] as num?)?.toDouble(),
        origemMeta: json['origemMeta'] as String?,
      );
}

/// Resposta completa de GET /api/evolucao/:idPaciente.
class Evolucao {
  const Evolucao({
    required this.periodo,
    required this.evolucaoPeso,
    required this.consumoSemanal,
    required this.macronutrientes,
    this.metaCalorica,
    this.nomePlano,
  });

  final String periodo;
  final double? metaCalorica;
  final String? nomePlano;
  final EvolucaoPeso evolucaoPeso;
  final ConsumoSemanal consumoSemanal;
  final Macronutrientes macronutrientes;

  factory Evolucao.fromJson(Map<String, dynamic> json) {
    final plano = json['plano'] as Map<String, dynamic>?;
    return Evolucao(
      periodo: (json['periodo'] ?? 'mensal') as String,
      metaCalorica: (json['metaCalorica'] as num?)?.toDouble(),
      nomePlano: plano?['nomePlano'] as String?,
      evolucaoPeso:
          EvolucaoPeso.fromJson(json['evolucaoPeso'] as Map<String, dynamic>),
      consumoSemanal:
          ConsumoSemanal.fromJson(json['consumoSemanal'] as Map<String, dynamic>),
      macronutrientes: Macronutrientes.fromJson(
        json['macronutrientes'] as Map<String, dynamic>,
      ),
    );
  }
}
