/**
 * Repositorio do chat (colecao `conversas`).
 *
 * No MySQL cada mensagem era uma linha com id_remetente/id_destinatario.
 * No Firestore a conversa entre dois usuarios e um documento cujo ID e
 * a ordem crescente dos UIDs ("uidA__uidB"), garantindo que ambos
 * enxerguem a MESMA conversa. As mensagens ficam na subcolecao
 * `mensagens` com IDs monotonicos gerados pelo servidor (`abc123`),
 * o que permite o cursor `depoisDoId` do polling.
 */
'use strict';

const { db } = require('../config/firebase');

/** ID estavel da conversa entre dois usuarios. */
function idDaConversa(uidA, uidB) {
  const [a, b] = [uidA, uidB].sort();
  return `${a}__${b}`;
}

/** Formato JSON de uma mensagem. */
function paraJson(doc, uidLogado) {
  const d = doc.data();
  return {
    idMensagem: doc.id,
    idRemetente: d.remetente,
    idDestinatario: d.destinatario,
    nomeRemetente: d.nomeRemetente || '',
    mensagem: d.texto,
    // ISO-8601 local sem sufixo de fuso ("2026-08-16T11:54:00").
    dataHora: paraIsoLocal(d.criadoEm?.toDate?.() || new Date()),
    lida: d.lida === true,
    ehMinha: d.remetente === uidLogado,
  };
}

/** Converte Date para "YYYY-MM-DDTHH:mm:ss" no fuso local. */
function paraIsoLocal(data) {
  const p = (n) => String(n).padStart(2, '0');
  return (
    `${data.getFullYear()}-${p(data.getMonth() + 1)}-${p(data.getDate())}` +
    `T${p(data.getHours())}:${p(data.getMinutes())}:${p(data.getSeconds())}`
  );
}

/** Garante a existencia do documento da conversa. */
async function garantirConversa(idConversa, uidA, uidB, nomes) {
  const ref = db().collection('conversas').doc(idConversa);
  if (!(await ref.get()).exists) {
    await ref.set({
      participantes: [uidA, uidB],
      nomes: nomes || {},
      criadoEm: new Date(),
    });
  }
}

/** Conversa completa em ordem cronologica. */
async function listarConversa(idConversa, uidLogado, limite = 500) {
  const snap = await db()
    .collection('conversas')
    .doc(idConversa)
    .collection('mensagens')
    .orderBy('criadoEm', 'asc')
    .limit(limite)
    .get();
  return snap.docs.map((doc) => paraJson(doc, uidLogado));
}

/** Mensagens criadas apos um determinado id (polling). */
async function listarNovas(idConversa, uidLogado, depoisDe) {
  let snap = await db()
    .collection('conversas')
    .doc(idConversa)
    .collection('mensagens')
    .orderBy('criadoEm', 'asc')
    .limit(500)
    .get();

  // Cursor por id: mantem apenas o que vem depois do id informado.
  const docs = [];
  let achou = depoisDe === null;
  for (const doc of snap.docs) {
    if (achou) docs.push(doc);
    else if (doc.id === depoisDe) achou = true;
  }

  // Fallback: id inexistente (conversa truncada) devolve tudo.
  if (!achou && depoisDe) return snap.docs.map((doc) => paraJson(doc, uidLogado));
  return docs.map((doc) => paraJson(doc, uidLogado));
}

/** Insere mensagem e devolve o registro persistido. */
async function inserirMensagem({ idConversa, remetente, destinatario, nomeRemetente, texto }) {
  const docConversa = db().collection('conversas').doc(idConversa);
  const anteriores = (await docConversa.get()).data() || {};
  const naoLidas = (anteriores[`naoLidasDe_${remetente}`] || 0) + 1;

  const ref = await docConversa.collection('mensagens').add({
    remetente,
    destinatario,
    nomeRemetente: nomeRemetente || '',
    texto,
    lida: false,
    criadoEm: new Date(),
  });

  // Resumo da conversa para o indicador de mensagens nao lidas.
  await docConversa.set(
    {
      ultimaMensagem: texto.slice(0, 120),
      ultimaMensagemEm: new Date(),
      [`naoLidasDe_${remetente}`]: naoLidas,
    },
    { merge: true },
  );

  const doc = await ref.get();
  return paraJson(doc, remetente);
}

/** Marca como lidas as mensagens do contato destinadas ao usuario. */
async function marcarComoLidas(idConversa, uidLogado, uidContato) {
  await db()
    .collection('conversas')
    .doc(idConversa)
    .set({ [`naoLidasDe_${uidContato}`]: 0 }, { merge: true });
}

/** Quantidade de mensagens nao lidas destinadas ao usuario. */
async function naoLidasDoUsuario(uid) {
  const snap = await db()
    .collection('conversas')
    .where('participantes', 'array-contains', uid)
    .get();
  let total = 0;
  for (const doc of snap.docs) {
    const dados = doc.data();
    // A chave do "outro" participante guarda as nao lidas DELE para MIM.
    for (const outro of dados.participantes || []) {
      if (outro !== uid) total += dados[`naoLidasDe_${outro}`] || 0;
    }
  }
  return total;
}

module.exports = {
  idDaConversa,
  garantirConversa,
  listarConversa,
  listarNovas,
  inserirMensagem,
  marcarComoLidas,
  naoLidasDoUsuario,
  paraIsoLocal,
};
