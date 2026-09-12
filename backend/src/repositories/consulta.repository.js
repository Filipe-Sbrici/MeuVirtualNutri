/**
 * Repositorio de consultas (agenda) - colecao `consultas`.
 * Substitui a tabela MySQL `consulta` com datas em Timestamp.
 *
 * Regra de visibilidade (tela 4.5.26 do prototipo):
 *  - Nutricionista ve TODAS as suas consultas (livres, confirmadas,
 *    concluidas, canceladas).
 *  - Paciente ve as proprias consultas + os horarios LIVRES dos
 *    nutricionistas (para poder agendar na tela 4.5.26).
 */
'use strict';

const { db } = require('../config/firebase');

/**
 * Consultas em que o usuario participa ou horarios disponiveis.
 */
async function listarDoUsuario(uid, { uidNutricionistaLivres = null } = {}) {
  const consultasLivres = uidNutricionistaLivres
    ? db()
        .collection('consultas')
        .where('status', '==', 'disponivel')
        .where('uidNutricionista', '==', uidNutricionistaLivres)
        .get()
    : Promise.resolve({ docs: [] });

  const [proprias, livres] = await Promise.all([
    db()
      .collection('consultas')
      .where('participantes', 'array-contains', uid)
      .orderBy('dataHora', 'asc')
      .get(),
    consultasLivres,
  ]);

  const vistos = new Set();
  const consultas = [];
  for (const snap of [proprias, livres]) {
    for (const doc of snap.docs) {
      if (vistos.has(doc.id)) continue;
      vistos.add(doc.id);
      consultas.push({ idConsulta: doc.id, ...doc.data() });
    }
  }

  consultas.sort((a, b) => (a.dataHora?.toDate?.() ?? 0) - (b.dataHora?.toDate?.() ?? 0));
  return consultas;
}

/** Histórico: apenas consultas concluídas em que o usuário participou. */
async function listarHistorico(uid) {
  const snap = await db()
    .collection('consultas')
    .where('participantes', 'array-contains', uid)
    .where('status', '==', 'concluida')
    .get();

  const lista = snap.docs.map((d) => ({ idConsulta: d.id, ...d.data() }));
  lista.sort((a, b) => (b.dataHora?.toDate?.() ?? 0) - (a.dataHora?.toDate?.() ?? 0));
  return lista;
}

/** Consulta por id (null quando nao existe). */
async function buscarPorId(idConsulta) {
  const doc = await db().collection('consultas').doc(idConsulta).get();
  return doc.exists ? { idConsulta: doc.id, ...doc.data() } : null;
}

/** Cria uma consulta (horario ofertado pelo nutricionista). */
async function criar({ uidNutricionista, uidPaciente = null, dataHora, observacoes = '' }) {
  const ref = await db().collection('consultas').add({
    uidNutricionista,
    uidPaciente,
    participantes: [uidNutricionista, ...(uidPaciente ? [uidPaciente] : [])],
    dataHora,
    status: uidPaciente ? 'confirmada' : 'disponivel',
    observacoes,
    criadoEm: new Date(),
  });
  return { idConsulta: ref.id };
}

/** Atualiza dados da consulta (dataHora, observações). */
async function atualizar(idConsulta, { dataHora, observacoes }) {
  const dados = { atualizadoEm: new Date() };
  if (dataHora) dados.dataHora = dataHora;
  if (observacoes !== undefined) dados.observacoes = observacoes;
  await db().collection('consultas').doc(idConsulta).set(dados, { merge: true });
}

/** Atualiza status/confirmacao (confirmada | concluida | cancelada | disponivel | pendente). */
async function atualizarStatus(idConsulta, status, dadosExtras = {}) {
  await db()
    .collection('consultas')
    .doc(idConsulta)
    .set(
      {
        status,
        ...dadosExtras,
        atualizadoEm: new Date(),
      },
      { merge: true },
    );
}

/** Paciente solicita agendamento em horário disponível -> passa para pendente. */
async function solicitar(idConsulta, uidPaciente) {
  const ref = db().collection('consultas').doc(idConsulta);
  const atual = (await ref.get()).data() || {};
  const participantes = [...new Set([...(atual.participantes || []), uidPaciente])];

  await ref.set(
    {
      status: 'pendente',
      uidPaciente,
      participantes,
      solicitadoEm: new Date(),
      atualizadoEm: new Date(),
    },
    { merge: true },
  );
}

/** Nutricionista aprova pedido pendente -> passa para confirmada. */
async function aprovar(idConsulta) {
  await db().collection('consultas').doc(idConsulta).set(
    {
      status: 'confirmada',
      aprovadoEm: new Date(),
      atualizadoEm: new Date(),
    },
    { merge: true },
  );
}

/** Nutricionista recusa pedido pendente -> volta para disponivel e desvincula paciente. */
async function recusar(idConsulta) {
  const ref = db().collection('consultas').doc(idConsulta);
  const doc = await ref.get();
  const atual = doc.data() || {};
  const participantes = (atual.participantes || []).filter((p) => p !== atual.uidPaciente);

  await ref.set(
    {
      status: 'disponivel',
      uidPaciente: null,
      participantes,
      recusadoEm: new Date(),
      atualizadoEm: new Date(),
    },
    { merge: true },
  );
}

/** Vincula o paciente ao horario no momento da confirmacao direta. */
async function confirmar(idConsulta, uidPaciente) {
  const ref = db().collection('consultas').doc(idConsulta);
  const atual = (await ref.get()).data() || {};
  const participantes = [...new Set([...(atual.participantes || []), uidPaciente])];

  await ref.set(
    {
      status: 'confirmada',
      uidPaciente,
      participantes,
      atualizadoEm: new Date(),
    },
    { merge: true },
  );
}

module.exports = {
  listarDoUsuario,
  listarHistorico,
  buscarPorId,
  criar,
  atualizar,
  atualizarStatus,
  solicitar,
  aprovar,
  recusar,
  confirmar,
};

