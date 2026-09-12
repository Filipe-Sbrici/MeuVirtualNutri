/**
 * Servico da tela de Progresso.
 *
 * Monta o cartao de resumo exibido no prototipo:
 *
 *      2.4kg  v                <- diferenca desde a primeira pesagem
 *      Perdidos desde o inicio
 *      Meta: 65kg (3.1kg restantes)
 *      Peso atual: 68.1kg
 *      [==========          ]  <- progresso rumo a meta
 *
 * e a lista "Historico de Peso". Alem disso, concentra os registros
 * diarios do Bem-Estar: agua (hidratacao) e humor (termometro
 * emocional), gravados no mesmo documento diario do paciente.
 */
'use strict';

const progressoRepo = require('../repositories/progresso.repository');
const usuarioRepo = require('../repositories/usuario.repository');
const AppError = require('../utils/AppError');
const { round } = require('../utils/validators');

const LIMITE_HISTORICO = 50;

/** Peso-meta do paciente (campo numerico ou extraido do objetivo). */
function resolverPesoMeta(paciente) {
  if (paciente.pesoMeta !== null && paciente.pesoMeta !== undefined) {
    return Number(paciente.pesoMeta);
  }
  const encontrado = /(\d+(?:[.,]\d+)?)\s*kg/i.exec(paciente.meta || '');
  return encontrado ? Number.parseFloat(encontrado[1].replace(',', '.')) : null;
}

/** Perfil do paciente ou 404. */
async function carregarPaciente(uid) {
  const paciente = await usuarioRepo.buscarPorUid(uid);
  if (!paciente || paciente.tipoUsuario !== 'paciente') {
    throw AppError.notFound('Paciente nao encontrado.');
  }
  return paciente;
}

/** Resumo + historico da tela de Progresso. */
async function obterResumo(uid) {
  const paciente = await carregarPaciente(uid);

  const [historico, serie, registroHoje] = await Promise.all([
    progressoRepo.listarHistoricoPeso(uid, LIMITE_HISTORICO),
    progressoRepo.listarSeriePeso(uid, 3650), // toda a serie
    progressoRepo.buscarPorData(uid, progressoRepo.hojeLocal()),
  ]);
  const ordenada = [...serie]; // crescente por data

  const primeira = ordenada[0] ?? null;
  const ultima = ordenada.length ? ordenada[ordenada.length - 1] : null;

  // Peso atual: prioriza a ultima pesagem; sem pesagens, usa o perfil.
  const pesoAtual = ultima ? Number(ultima.peso) : Number(paciente.pesoAtual);
  const pesoInicial = primeira ? Number(primeira.peso) : pesoAtual;
  const pesoMeta = resolverPesoMeta(paciente);

  // Positivo = perdeu peso | Negativo = ganhou peso.
  const diferenca = round(pesoInicial - pesoAtual, 1);
  const restantes = pesoMeta !== null && pesoAtual !== null
    ? round(Math.abs(pesoAtual - pesoMeta), 1)
    : null;

  let percentualMeta = null;
  if (pesoMeta !== null && pesoAtual !== null) {
    const totalNecessario = Math.abs(pesoInicial - pesoMeta);
    percentualMeta =
      totalNecessario === 0
        ? 100
        : round(
            Math.min(100, Math.max(0, (Math.abs(diferenca) / totalNecessario) * 100)),
            1,
          );
    const indoParaMeta =
      pesoMeta < pesoInicial ? pesoAtual < pesoInicial : pesoAtual > pesoInicial;
    if (!indoParaMeta && diferenca !== 0) percentualMeta = 0;
  }

  return {
    paciente: {
      uid,
      nome: paciente.nome,
      objetivo: paciente.meta,
      tipoDieta: paciente.tipoDieta,
    },
    resumo: {
      pesoAtual: pesoAtual !== null && !Number.isNaN(pesoAtual) ? round(pesoAtual, 1) : null,
      pesoInicial: round(pesoInicial, 1),
      pesoMeta: pesoMeta !== null ? round(pesoMeta, 1) : null,
      diferenca: Math.abs(diferenca),
      sentido: diferenca > 0 ? 'perda' : diferenca < 0 ? 'ganho' : 'estavel',
      rotuloDiferenca:
        diferenca > 0
          ? 'Perdidos desde o inicio'
          : diferenca < 0
            ? 'Ganhos desde o inicio'
            : 'Sem variacao desde o inicio',
      restantesParaMeta: restantes,
      percentualMeta,
      dataPrimeiroRegistro: primeira ? primeira.dataRegistro : null,
      dataUltimoRegistro: ultima ? ultima.dataRegistro : null,
    },
    historico: historico.map((registro) => ({
      idProgresso: registro.idProgresso,
      peso: round(registro.peso, 1),
      dataRegistro: registro.dataRegistro,
      aderenciaPlano: registro.aderenciaPlano !== null ? round(registro.aderenciaPlano, 1) : null,
    })),
    // Registros do dia usados pela aba Bem-Estar (hidratacao e
    // termometro emocional) para reabrir com o estado ja gravado.
    hoje: {
      dataRegistro: progressoRepo.hojeLocal(),
      coposAgua: registroHoje?.coposAgua ?? 0,
      humor: registroHoje?.humor ?? null,
    },
  };
}

/**
 * Registra uma nova pesagem (botao "+ REGISTRAR PESO").
 * Um documento por dia: nova pesagem no mesmo dia ATUALIZA o registro.
 * O pesoAtual do perfil tambem e sincronizado.
 */
async function registrarPeso({ uid, peso, dataRegistro }) {
  const paciente = await carregarPaciente(uid);

  // "Atualizado" = ja existia pesagem nessa data antes do salvamento.
  const existente = await progressoRepo.buscarPorData(uid, dataRegistro);

  const registro = await progressoRepo.salvarPeso(uid, dataRegistro, peso);

  // Mantem o perfil coerente com a pesagem mais recente.
  await usuarioRepo.atualizar(uid, { pesoAtual: round(peso, 1) });

  return {
    idProgresso: registro.idProgresso,
    atualizado: Boolean(existente),
    peso: round(peso, 1),
    dataRegistro,
    nome: paciente.nome,
  };
}

/** Remove uma pesagem do historico (botao "x"). idProgresso = data. */
async function removerPesagem({ uid, dataRegistro }) {
  await carregarPaciente(uid);

  const resultado = await progressoRepo.removerPesagem(uid, dataRegistro);
  if (!resultado.removido && !resultado.pesoLimpo) {
    throw AppError.notFound('Registro de progresso nao encontrado.');
  }

  // Recalcula o pesoAtual do perfil com a pesagem restante mais recente.
  const serie = await progressoRepo.listarSeriePeso(uid, 3650);
  const ultima = serie.length ? serie[serie.length - 1] : null;
  if (ultima) {
    await usuarioRepo.atualizar(uid, { pesoAtual: round(Number(ultima.peso), 1) });
  }

  return { idProgresso: dataRegistro, ...resultado };
}

/** Registra copos de agua (contador do Bem-Estar). */
async function registrarAgua({ uid, coposAgua }) {
  await carregarPaciente(uid);
  return progressoRepo.salvarAgua(uid, coposAgua);
}

/** Registra o humor do dia (termometro emocional). */
async function registrarHumor({ uid, humor }) {
  await carregarPaciente(uid);
  return progressoRepo.salvarHumor(uid, humor);
}

/**
 * Consolida o consumo calorico/aderencia do dia a partir do cardapio
 * (chamado quando o paciente conclui refeicoes no checklist).
 */
async function consolidarConsumo({ uid, consumoCalorico, aderenciaPlano }) {
  return progressoRepo.salvarConsumo(uid, progressoRepo.hojeLocal(), {
    consumoCalorico,
    aderenciaPlano,
  });
}

module.exports = {
  obterResumo,
  registrarPeso,
  removerPesagem,
  registrarAgua,
  registrarHumor,
  consolidarConsumo,
  resolverPesoMeta,
};
