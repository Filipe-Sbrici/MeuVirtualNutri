/**
 * Repositorio de usuarios (colecao `usuarios/{uid}`).
 *
 * Modelo Firestore: as tabelas MySQL `usuario`, `paciente` e
 * `nutricionista` viraram UM documento por usuario, cujo ID e o UID do
 * Firebase Authentication. Campos clinicos existem apenas em perfis de
 * paciente; crn/especializacao apenas em nutricionistas.
 *
 * Convencao de nomes dos campos: camelCase, igual ao contrato JSON.
 */
'use strict';

const { db } = require('../config/firebase');

const COLECAO = 'usuarios';

/** Converte o documento Firestore no formato de perfil usado pela API. */
function paraPerfil(uid, dados) {
  return {
    uid,
    nome: dados.nome || '',
    email: dados.email || '',
    telefone: dados.telefone ?? null,
    tipoUsuario: dados.tipoUsuario || 'paciente',
    onboardingCompleto: dados.onboardingCompleto === true,
    tutorialVisto: dados.tutorialVisto === true,
    // Campos de nutricionista
    crn: dados.crn ?? null,
    especializacao: dados.especializacao ?? null,
    // Campos clinicos do paciente
    idade: dados.idade ?? null,
    pesoAtual: dados.pesoAtual ?? null,
    pesoMeta: dados.pesoMeta ?? null,
    altura: dados.altura ?? null,
    genero: dados.genero ?? null,
    meta: dados.meta ?? null,
    nivelAtividade: dados.nivelAtividade ?? null,
    tipoDieta: dados.tipoDieta ?? null,
    idNutricionista: dados.idNutricionista ?? null,
    alimentosFavoritos: dados.alimentosFavoritos || [],
    alimentosRejeitados: dados.alimentosRejeitados || [],
    restricoes: dados.restricoes || [],
    condicoesMedicas: dados.condicoesMedicas || [],
    // Privacidade e preferências adicionais
    compartilharListaCompras: dados.compartilharListaCompras !== false,
    compartilharHumor: dados.compartilharHumor !== false,
    itensListaComprasExtras: dados.itensListaComprasExtras || [],
    observacoesSeguranca: dados.observacoesSeguranca || '',
    notificacoesAtivas: dados.notificacoesAtivas !== false,
    statusVinculo: dados.statusVinculo || (dados.idNutricionista ? 'aprovado' : null),
    solicitacaoNutricionista: dados.solicitacaoNutricionista ?? null,
    notificacoes: dados.notificacoes ?? {
      chat: true,
      consultas: true,
      lembretes: true,
      solicitacoes: true,
    },
    criadoEm: dados.criadoEm?.toDate?.().toISOString() ?? null,
  };
}


/** Perfil completo de um usuario. */
async function buscarPorUid(uid) {
  const doc = await db().collection(COLECAO).doc(uid).get();
  return doc.exists ? paraPerfil(doc.id, doc.data()) : null;
}

/** Perfil resumido publico (cabecalho de chat, listas). */
async function buscarResumo(uid) {
  const doc = await db().collection(COLECAO).doc(uid).get();
  if (!doc.exists) return null;
  const d = doc.data();
  return {
    uid: doc.id,
    nome: d.nome || '',
    email: d.email || '',
    tipoUsuario: d.tipoUsuario || 'paciente',
    crn: d.crn ?? null,
    especializacao: d.especializacao ?? null,
  };
}

/** Cria o perfil se ainda nao existir (chamado no cadastro). */
async function criarSeNaoExistir(uid, dados) {
  const ref = db().collection(COLECAO).doc(uid);
  const doc = await ref.get();
  if (doc.exists) return paraPerfil(doc.id, doc.data());

  await ref.set({
    nome: dados.nome || '',
    email: dados.email ? dados.email.toLowerCase() : '',
    tipoUsuario: dados.tipoUsuario || 'paciente',
    telefone: dados.telefone ?? null,
    crn: dados.crn ?? null,
    especializacao: dados.especializacao ?? null,
    onboardingCompleto: dados.tipoUsuario === 'nutricionista',
    tutorialVisto: false,
    criadoEm: new Date(),
  });
  return buscarPorUid(uid);
}

/** Mescla campos no perfil do usuario. */
async function atualizar(uid, campos) {
  await db().collection(COLECAO).doc(uid).set(campos, { merge: true });
  return buscarPorUid(uid);
}

/** Nutricionistas disponiveis para o onboarding do paciente. */
async function listarNutricionistas() {
  const snap = await db()
    .collection(COLECAO)
    .where('tipoUsuario', '==', 'nutricionista')
    .get();
  return snap.docs.map((doc) => {
    const d = doc.data();
    return {
      uid: doc.id,
      nome: d.nome || '',
      crn: d.crn ?? null,
      especializacao: d.especializacao ?? null,
    };
  });
}

/** Pacientes vinculados a um nutricionista (ativos/aprovados). */
async function listarPacientesDoNutricionista(uidNutricionista) {
  const snap = await db()
    .collection(COLECAO)
    .where('tipoUsuario', '==', 'paciente')
    .where('idNutricionista', '==', uidNutricionista)
    .get();
  return snap.docs
    .map((doc) => paraPerfil(doc.id, doc.data()))
    .filter((p) => p.statusVinculo !== 'recusado' && p.statusVinculo !== 'pendente');
}

/** Solicitações pendentes de atendimento para o nutricionista. */
async function listarSolicitacoesDoNutricionista(uidNutricionista) {
  const snap = await db()
    .collection(COLECAO)
    .where('tipoUsuario', '==', 'paciente')
    .where('idNutricionista', '==', uidNutricionista)
    .get();
  return snap.docs
    .map((doc) => paraPerfil(doc.id, doc.data()))
    .filter((p) => p.statusVinculo === 'pendente');
}

/** Vincula um paciente a um nutricionista (status aprovado ou pendente). */
async function vincularNutricionista(uidPaciente, uidNutricionista, status = 'aprovado') {
  await db()
    .collection(COLECAO)
    .doc(uidPaciente)
    .set({
      idNutricionista: uidNutricionista,
      statusVinculo: status,
      solicitacaoNutricionista: {
        uidNutricionista,
        status: status === 'aprovado' ? 'aprovada' : 'pendente',
        solicitadoEm: new Date(),
      },
    }, { merge: true });
}

/** Aceita uma solicitacao de atendimento pendente. */
async function aceitarSolicitacao(uidPaciente, uidNutricionista) {
  await db()
    .collection(COLECAO)
    .doc(uidPaciente)
    .set({
      idNutricionista: uidNutricionista,
      statusVinculo: 'aprovado',
      solicitacaoNutricionista: {
        uidNutricionista,
        status: 'aprovada',
        respondidaEm: new Date(),
      },
    }, { merge: true });
}

/** Recusa uma solicitacao de atendimento. */
async function recusarSolicitacao(uidPaciente, uidNutricionista) {
  await db()
    .collection(COLECAO)
    .doc(uidPaciente)
    .set({
      idNutricionista: null,
      statusVinculo: 'recusado',
      solicitacaoNutricionista: {
        uidNutricionista,
        status: 'recusada',
        respondidaEm: new Date(),
      },
    }, { merge: true });
}

/** Nutricionista responsavel pelo paciente (perfil completo). */
async function nutricionistaDoPaciente(uidPaciente) {
  const paciente = await buscarPorUid(uidPaciente);
  if (!paciente?.idNutricionista || paciente.statusVinculo === 'recusado') return null;
  return buscarPorUid(paciente.idNutricionista);
}

/** Pacientes ainda sem nutricionista (para o onboarding escolher). */
async function contarPorEmail(email) {
  const snap = await db()
    .collection(COLECAO)
    .where('email', '==', email.toLowerCase())
    .limit(1)
    .get();
  return snap.size;
}

/** Busca usuario por e-mail (usado no modo demo e criacao de paciente). */
async function buscarPorEmail(email) {
  const snap = await db()
    .collection(COLECAO)
    .where('email', '==', email.toLowerCase())
    .limit(1)
    .get();
  return snap.empty ? null : paraPerfil(snap.docs[0].id, snap.docs[0].data());
}

/** Exclui o documento de perfil (usado na exclusao da conta). */
async function excluir(uid) {
  await db().collection(COLECAO).doc(uid).delete();
}

module.exports = {
  buscarPorUid,
  buscarResumo,
  buscarPorEmail,
  criarSeNaoExistir,
  atualizar,
  listarNutricionistas,
  listarPacientesDoNutricionista,
  listarSolicitacoesDoNutricionista,
  vincularNutricionista,
  aceitarSolicitacao,
  recusarSolicitacao,
  nutricionistaDoPaciente,
  contarPorEmail,
  excluir,
  paraPerfil,
};
