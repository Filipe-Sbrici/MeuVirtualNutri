/**
 * Repositorio de progresso (`usuarios/{uid}/progresso/{YYYY-MM-DD}`).
 *
 * A tabela MySQL `progresso` virou subcolecao do paciente com um
 * documento por dia. Isso reproduz a regra de negocio que ja existia
 * ("uma pesagem por dia; nova pesagem no mesmo dia ATUALIZA") usando a
 * propria chave do documento, sem corrida de INSERT duplicado.
 *
 * Campos: peso (nullable), consumoCalorico (nullable), aderenciaPlano
 * (nullable), coposAgua, humor, refeicoesConcluidas.
 */
'use strict';

const { db } = require('../config/firebase');

/** Data local "YYYY-MM-DD". */
function hojeLocal() {
  const agora = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${agora.getFullYear()}-${p(agora.getMonth() + 1)}-${p(agora.getDate())}`;
}

/** Converte "YYYY-MM-DD" + dias para a data local deslocada. */
function dataMenosDias(dias) {
  const data = new Date();
  data.setDate(data.getDate() - dias);
  const p = (n) => String(n).padStart(2, '0');
  return `${data.getFullYear()}-${p(data.getMonth() + 1)}-${p(data.getDate())}`;
}

function paraJson(idDoc, dados) {
  return {
    dataRegistro: idDoc,
    peso: dados.peso ?? null,
    consumoCalorico: dados.consumoCalorico ?? null,
    aderenciaPlano: dados.aderenciaPlano ?? null,
    coposAgua: dados.coposAgua ?? 0,
    humor: dados.humor ?? null,
  };
}

/** Historico de pesagens (peso != null), mais recente primeiro. */
async function listarHistoricoPeso(uid, limite = 50) {
  const snap = await db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .orderBy('dataRegistro', 'desc')
    .limit(limite)
    .get();
  return snap.docs
    .map((doc) => ({ id: doc.id, ...paraJson(doc.id, doc.data()) }))
    .filter((r) => r.peso !== null)
    .map((r) => ({ idProgresso: r.id, ...r }));
}

/** Serie de pesagens em ordem crescente dentro de um intervalo. */
async function listarSeriePeso(uid, dias) {
  const snap = await db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .where('dataRegistro', '>=', dataMenosDias(dias))
    .orderBy('dataRegistro', 'asc')
    .get();
  return snap.docs
    .map((doc) => paraJson(doc.id, doc.data()))
    .filter((r) => r.peso !== null);
}

/** Registro de um dia especifico. */
async function buscarPorData(uid, dataRegistro) {
  const doc = await db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .doc(dataRegistro)
    .get();
  return doc.exists ? { id: doc.id, ...paraJson(doc.id, doc.data()) } : null;
}

/**
 * Registra/atualiza a pesagem do dia (upsert por chave de data).
 * Preserva consumoCalorico/aderenciaPlano existentes no mesmo documento.
 */
async function salvarPeso(uid, dataRegistro, peso) {
  const ref = db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .doc(dataRegistro);

  await ref.set(
    {
      dataRegistro,
      peso,
      atualizadoEm: new Date(),
    },
    { merge: true },
  );

  return { idProgresso: dataRegistro, dataRegistro, peso };
}

/**
 * Registra o consumo calorico/aderencia do dia (fonte: refeicoes
 * concluidas do cardapio). Upsert por data, preserva o peso.
 */
async function salvarConsumo(uid, dataRegistro, { consumoCalorico, aderenciaPlano }) {
  await db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .doc(dataRegistro)
    .set(
      {
        dataRegistro,
        ...(consumoCalorico !== undefined && { consumoCalorico }),
        ...(aderenciaPlano !== undefined && { aderenciaPlano }),
        atualizadoEm: new Date(),
      },
      { merge: true },
    );
}

/** Registra hidratacao (copos de agua) do dia. */
async function salvarAgua(uid, coposAgua) {
  const dataRegistro = hojeLocal();
  await db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .doc(dataRegistro)
    .set({ dataRegistro, coposAgua, atualizadoEm: new Date() }, { merge: true });
  return { dataRegistro, coposAgua };
}

/** Registra o humor do dia ("termometro emocional"). */
async function salvarHumor(uid, humor) {
  const dataRegistro = hojeLocal();
  await db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .doc(dataRegistro)
    .set({ dataRegistro, humor, atualizadoEm: new Date() }, { merge: true });
  return { dataRegistro, humor };
}

/**
 * Remove a pesagem do dia. Se o documento tambem guarda
 * consumo/aderencia/agua, apenas limpa o campo peso.
 */
async function removerPesagem(uid, dataRegistro) {
  const doc = await db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .doc(dataRegistro)
    .get();
  if (!doc.exists) return { removido: false, pesoLimpo: false };

  const dados = doc.data();
  const temOutrosDados =
    dados.consumoCalorico != null ||
    dados.aderenciaPlano != null ||
    dados.coposAgua > 0 ||
    dados.humor != null;

  if (temOutrosDados) {
    await doc.ref.update({ peso: null });
    return { removido: false, pesoLimpo: true };
  }
  await doc.ref.delete();
  return { removido: true, pesoLimpo: false };
}

/** Medias agregadas do periodo (para a tela de Evolucao). */
async function buscarMediasPeriodo(uid, dias) {
  const snap = await db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .where('dataRegistro', '>=', dataMenosDias(dias))
    .get();

  const registros = snap.docs.map((doc) => paraJson(doc.id, doc.data()));
  const comConsumo = registros.filter((r) => r.consumoCalorico !== null);
  const comAderencia = registros.filter((r) => r.aderenciaPlano !== null);

  const media = (lista, campo) =>
    lista.length
      ? lista.reduce((soma, r) => soma + Number(r[campo]), 0) / lista.length
      : null;

  return {
    consumoMedio: media(comConsumo, 'consumoCalorico'),
    aderenciaMedia: media(comAderencia, 'aderenciaPlano'),
    totalRegistros: registros.length,
  };
}

/** Consumo por dia no intervalo (grafico semanal). */
async function listarConsumoDiario(uid, dias) {
  const snap = await db()
    .collection('usuarios')
    .doc(uid)
    .collection('progresso')
    .where('dataRegistro', '>=', dataMenosDias(dias))
    .orderBy('dataRegistro', 'asc')
    .get();
  return snap.docs
    .map((doc) => paraJson(doc.id, doc.data()))
    .filter((r) => r.consumoCalorico !== null);
}

module.exports = {
  hojeLocal,
  listarHistoricoPeso,
  listarSeriePeso,
  buscarPorData,
  salvarPeso,
  salvarConsumo,
  salvarAgua,
  salvarHumor,
  removerPesagem,
  buscarMediasPeriodo,
  listarConsumoDiario,
};
