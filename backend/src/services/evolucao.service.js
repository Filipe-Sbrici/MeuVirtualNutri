/**
 * Servico da tela de Evolucao.
 *
 * Monta os tres cartoes do prototipo:
 *
 *   1. "Evolucao de Peso"            -> grafico de linha (serie de pesagens)
 *   2. "Consumo Calorico Semanal"    -> grafico de barras Consumido x Meta
 *   3. "Macronutrientes (Media Semanal)" -> barras de proteina/carbo/gordura
 *
 * O consumo diario agora vem do checklist do cardapio (refeicoes
 * concluidas consolidadas em progresso.consumoCalorico); os macros
 * seguem ponderados pela aderencia media do periodo.
 */
'use strict';

const progressoRepo = require('../repositories/progresso.repository');
const usuarioRepo = require('../repositories/usuario.repository');
const planoRepo = require('../repositories/plano.repository');
const AppError = require('../utils/AppError');
const { round } = require('../utils/validators');
const { calcularMetaCalorica, calcularMetaMacros } = require('../utils/nutricao');

/** Dias da semana na ordem exibida no grafico do prototipo. */
const DIAS_SEMANA = [
  { rotulo: 'Seg', jsDay: 1 },
  { rotulo: 'Ter', jsDay: 2 },
  { rotulo: 'Qua', jsDay: 3 },
  { rotulo: 'Qui', jsDay: 4 },
  { rotulo: 'Sex', jsDay: 5 },
  { rotulo: 'Sab', jsDay: 6 },
  { rotulo: 'Dom', jsDay: 0 },
];

const DIAS_SEMANA_FIXO = 7; // cartoes 2 e 3 sao explicitamente semanais

/** Media diaria de macros prescrita no plano ativo (ou null). */
async function obterPrescricaoDiaria(uidPaciente) {
  const plano = await planoRepo.buscarPlanoAtivo(uidPaciente);
  if (!plano) return null;

  const totais = await planoRepo.mediaDiariaDoPlano(plano.idPlano);
  if (!totais || totais.diasCadastrados === 0) return null;

  const dias = totais.diasCadastrados;
  return {
    idPlano: plano.idPlano,
    nomePlano: plano.nomePlano,
    calorias: totais.calorias / dias,
    proteinas: totais.proteinas / dias,
    carboidratos: totais.carboidratos / dias,
    gorduras: totais.gorduras / dias,
  };
}

/** Cartao 1: serie temporal de peso. */
async function montarEvolucaoPeso(uid, dias) {
  const serie = await progressoRepo.listarSeriePeso(uid, dias);
  const pesos = serie.map((r) => Number(r.peso));

  return {
    pontos: serie.map((r) => ({ data: r.dataRegistro, peso: round(r.peso, 1) })),
    minimo: pesos.length ? round(Math.min(...pesos) - 0.5, 1) : null,
    maximo: pesos.length ? round(Math.max(...pesos) + 0.5, 1) : null,
    variacao: pesos.length >= 2 ? round(pesos[0] - pesos[pesos.length - 1], 1) : 0,
  };
}

/** Cartao 2: consumo calorico por dia da semana (Consumido x Meta). */
async function montarConsumoSemanal(uid, metaCalorica) {
  const registros = await progressoRepo.listarConsumoDiario(uid, DIAS_SEMANA_FIXO);

  // Indexa pelo dia da semana (getDay(): 0=Dom..6=Sab).
  const porDia = new Map();
  for (const r of registros) {
    const d = new Date(`${r.dataRegistro}T12:00:00`);
    porDia.set(d.getDay(), r);
  }

  const barras = DIAS_SEMANA.map((dia) => {
    const r = porDia.get(dia.jsDay);
    return {
      rotulo: dia.rotulo,
      consumido: r ? round(r.consumoCalorico, 0) : 0,
      meta: metaCalorica,
      data: r ? r.dataRegistro : null,
    };
  });

  const valores = barras.map((b) => b.consumido).filter((v) => v > 0);
  const mediaConsumida = valores.length
    ? round(valores.reduce((s, v) => s + v, 0) / valores.length, 0)
    : 0;

  return {
    barras,
    mediaConsumida,
    meta: metaCalorica,
    maximoEixo:
      Math.ceil(Math.max(metaCalorica || 0, ...barras.map((b) => b.consumido)) / 100) * 100,
  };
}

/** Cartao 3: macronutrientes medios da semana (consumido x meta). */
async function montarMacronutrientes(uid, prescricao, metaCalorica) {
  const medias = await progressoRepo.buscarMediasPeriodo(uid, DIAS_SEMANA_FIXO);
  const aderenciaMedia = medias?.aderenciaMedia ?? null;

  const metas = prescricao
    ? {
        proteinas: Math.round(prescricao.proteinas),
        carboidratos: Math.round(prescricao.carboidratos),
        gorduras: Math.round(prescricao.gorduras),
      }
    : calcularMetaMacros(metaCalorica);

  const fator = aderenciaMedia !== null ? aderenciaMedia / 100 : 1;
  const consumido = {
    proteinas: metas.proteinas !== null ? Math.round(metas.proteinas * fator) : null,
    carboidratos:
      metas.carboidratos !== null ? Math.round(metas.carboidratos * fator) : null,
    gorduras: metas.gorduras !== null ? Math.round(metas.gorduras * fator) : null,
  };

  const montarItem = (chave, rotulo) => {
    const meta = metas[chave];
    const atual = consumido[chave];
    return {
      chave,
      rotulo,
      consumido: atual,
      meta,
      unidade: 'g',
      percentual: meta ? round(Math.min(100, (atual / meta) * 100), 1) : null,
    };
  };

  return {
    aderenciaMedia: aderenciaMedia !== null ? round(aderenciaMedia, 1) : null,
    origemMeta: prescricao ? 'plano_alimentar' : 'calculo_mifflin_st_jeor',
    itens: [
      montarItem('proteinas', 'Proteina'),
      montarItem('carboidratos', 'Carboidrato'),
      montarItem('gorduras', 'Gordura'),
    ],
  };
}

/** Payload completo da tela de Evolucao do paciente informado. */
async function obterEvolucao({ uidPaciente, periodo, dias }) {
  const paciente = await usuarioRepo.buscarPorUid(uidPaciente);
  if (!paciente || paciente.tipoUsuario !== 'paciente') {
    throw AppError.notFound('Paciente nao encontrado.');
  }

  const prescricao = await obterPrescricaoDiaria(uidPaciente);
  const metaCalculada = calcularMetaCalorica(paciente);
  const metaCalorica = prescricao ? Math.round(prescricao.calorias) : metaCalculada;

  const [evolucaoPeso, consumoSemanal, macronutrientes] = await Promise.all([
    montarEvolucaoPeso(uidPaciente, dias),
    montarConsumoSemanal(uidPaciente, metaCalorica),
    montarMacronutrientes(uidPaciente, prescricao, metaCalorica),
  ]);

  return {
    paciente: { uid: uidPaciente, nome: paciente.nome, objetivo: paciente.meta },
    periodo,
    metaCalorica,
    plano: prescricao
      ? { idPlano: prescricao.idPlano, nomePlano: prescricao.nomePlano }
      : null,
    evolucaoPeso,
    consumoSemanal,
    macronutrientes,
  };
}

module.exports = { obterEvolucao };
