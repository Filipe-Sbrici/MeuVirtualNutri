/**
 * Calculos nutricionais.
 *
 * O banco fornecido nao possui uma coluna com a "meta calorica" do
 * paciente. Em vez de criar tabelas novas, a meta e DERIVADA dos dados
 * clinicos que ja existem em `paciente` (peso, altura, idade, genero,
 * nivel_atividade, meta), usando equacoes consagradas da literatura:
 *
 *   1. TMB  - Equacao de Mifflin-St Jeor (1990)
 *   2. GET  - TMB x fator de atividade fisica
 *   3. Meta - GET ajustado pelo objetivo (deficit/superavit de 15%)
 *
 * Assim a meta exibida nas telas de Progresso e Evolucao acompanha
 * automaticamente qualquer alteracao no perfil do paciente.
 */
'use strict';

/** Fatores de atividade fisica (PAL) por nivel cadastrado no onboarding. */
const FATORES_ATIVIDADE = {
  sedentario: 1.2,
  leve: 1.375,
  moderado: 1.55,
  ativo: 1.725,
  'muito ativo': 1.9,
};

/** Ajuste calorico conforme o objetivo textual em `paciente.meta`. */
const AJUSTE_OBJETIVO = [
  { padrao: /perda|perder|emagrec/i, fator: 0.85 },
  { padrao: /ganho|ganhar|massa|hipertrof/i, fator: 1.15 },
  { padrao: /manuten|manter/i, fator: 1.0 },
];

/**
 * Distribuicao de macronutrientes sobre a meta calorica.
 * Perfil moderado em carboidratos, adequado a dietas de reducao de peso.
 */
const DISTRIBUICAO_MACROS = {
  proteinas: 0.25, // 25% das calorias -> 4 kcal/g
  carboidratos: 0.45, // 45% das calorias -> 4 kcal/g
  gorduras: 0.3, // 30% das calorias -> 9 kcal/g
};

const KCAL_POR_GRAMA = { proteinas: 4, carboidratos: 4, gorduras: 9 };

/** Taxa Metabolica Basal - Mifflin-St Jeor. */
function calcularTMB({ peso, alturaMetros, idade, genero }) {
  const alturaCm = alturaMetros * 100;
  const base = 10 * peso + 6.25 * alturaCm - 5 * idade;
  const masculino = /^m/i.test(genero || '');
  return masculino ? base + 5 : base - 161;
}

function fatorAtividade(nivelAtividade) {
  const chave = (nivelAtividade || '').toString().trim().toLowerCase();
  return FATORES_ATIVIDADE[chave] ?? FATORES_ATIVIDADE.moderado;
}

function fatorObjetivo(meta) {
  const encontrado = AJUSTE_OBJETIVO.find((item) => item.padrao.test(meta || ''));
  return encontrado ? encontrado.fator : 1.0;
}

/**
 * Meta calorica diaria do paciente.
 * Retorna null quando faltam dados clinicos essenciais.
 */
function calcularMetaCalorica(paciente) {
  const peso = Number(paciente.pesoAtual);
  const altura = Number(paciente.altura);
  const idade = Number(paciente.idade);

  if (!peso || !altura || !idade) return null;

  const tmb = calcularTMB({
    peso,
    alturaMetros: altura,
    idade,
    genero: paciente.genero,
  });
  const get = tmb * fatorAtividade(paciente.nivelAtividade);
  const meta = get * fatorObjetivo(paciente.meta);

  return Math.round(meta);
}

/**
 * Metas de macronutrientes (em gramas) a partir da meta calorica.
 */
function calcularMetaMacros(metaCalorica) {
  if (!metaCalorica) {
    return { proteinas: null, carboidratos: null, gorduras: null };
  }
  return {
    proteinas: Math.round(
      (metaCalorica * DISTRIBUICAO_MACROS.proteinas) / KCAL_POR_GRAMA.proteinas,
    ),
    carboidratos: Math.round(
      (metaCalorica * DISTRIBUICAO_MACROS.carboidratos) /
        KCAL_POR_GRAMA.carboidratos,
    ),
    gorduras: Math.round(
      (metaCalorica * DISTRIBUICAO_MACROS.gorduras) / KCAL_POR_GRAMA.gorduras,
    ),
  };
}

module.exports = {
  calcularMetaCalorica,
  calcularMetaMacros,
  FATORES_ATIVIDADE,
  DISTRIBUICAO_MACROS,
};
