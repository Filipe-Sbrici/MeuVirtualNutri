/**
 * Repositorio de orientacoes/feedbacks - colecao `orientacoes`.
 *
 * Nao existia no banco MySQL original; atende a tela 4.5.15 ("Meu
 * nutricionista" -> aba Orientacoes) do prototipo: feedbacks enviados
 * pelo nutricionista classificados em positivo | neutro | melhoria.
 */
'use strict';

const { db } = require('../config/firebase');

const CATEGORIAS = ['positivo', 'neutro', 'melhoria'];

/** Lista orientacoes destinadas a um paciente. */
async function listarDoPaciente(uidPaciente) {
  const snap = await db()
    .collection('orientacoes')
    .where('uidPaciente', '==', uidPaciente)
    .orderBy('criadoEm', 'desc')
    .get();
  return snap.docs.map((doc) => ({ idOrientacao: doc.id, ...doc.data() }));
}

/** Envia uma orientacao. */
async function criar({ uidNutricionista, uidPaciente, categoria, texto }) {
  const ref = await db().collection('orientacoes').add({
    uidNutricionista,
    uidPaciente,
    categoria: CATEGORIAS.includes(categoria) ? categoria : 'neutro',
    texto,
    lida: false,
    confirmada: false,
    criadoEm: new Date(),
  });
  return { idOrientacao: ref.id };
}

/** Marca uma orientacao como confirmada pelo paciente. */
async function confirmar(idOrientacao, uidPaciente) {
  const ref = db().collection('orientacoes').doc(idOrientacao);
  const doc = await ref.get();
  if (!doc.exists) return false;
  if (doc.data().uidPaciente !== uidPaciente) return false;

  await ref.set(
    {
      lida: true,
      confirmada: true,
      confirmadaEm: new Date(),
    },
    { merge: true },
  );
  return true;
}

module.exports = { CATEGORIAS, listarDoPaciente, criar, confirmar };

