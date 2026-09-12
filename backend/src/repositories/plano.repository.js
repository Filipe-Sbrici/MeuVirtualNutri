/**
 * Repositorio de planos alimentares, refeicoes, receitas e checklist.
 *
 * Migracao MySQL -> Firestore:
 *   plano_alimentar (linha)      -> planos/{id}
 *   refeicao (linha)             -> planos/{id}/refeicoes/{dia_tipo} (doc por dia+tipo)
 *   refeicao_alimento (juncao)   -> ingredientes (array) dentro da receita
 *   alimento (linha)             -> alimentos/{id}
 *   favoritos / paciente_restricao -> arrays em usuarios/{uid}
 *
 * Novidades exigidas pelo prototipo:
 *   - checklist diário do paciente: refeicoesConcluidas em
 *     planos/{id}/refeicoes/{doc}/concluidaEm por paciente? Nao -
 *     concluidaEm vive no documento de refeicao (um plano por paciente,
 *     ativo por vez, simplificacao valida para o TCC).
 *   - receitas/{id}: biblioteca do nutricionista + receitas enviadas
 *     por pacientes (status pendente/aprovada/recusada).
 */
'use strict';

const { db } = require('../config/firebase');

const TIPOS_REFEICAO = [
  'cafeManha',
  'lancheManha',
  'almoco',
  'lancheTarde',
  'jantar',
  'ceia',
];

const ROTULOS_REFEICAO = {
  cafeManha: 'Café da Manhã',
  lancheManha: 'Lanche da Manhã',
  almoco: 'Almoço',
  lancheTarde: 'Lanche da Tarde',
  jantar: 'Jantar',
  ceia: 'Ceia',
};

const DIAS_SEMANA = ['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo'];

const ROTULOS_DIA = {
  segunda: 'Segunda',
  terca: 'Terça',
  quarta: 'Quarta',
  quinta: 'Quinta',
  sexta: 'Sexta',
  sabado: 'Sábado',
  domingo: 'Domingo',
};

/** Plano ativo (mais recente) do paciente. */
async function buscarPlanoAtivo(uidPaciente) {
  const snap = await db()
    .collection('planos')
    .where('uidPaciente', '==', uidPaciente)
    .orderBy('criadoEm', 'desc')
    .limit(1)
    .get();
  if (snap.empty) return null;
  return { idPlano: snap.docs[0].id, ...snap.docs[0].data() };
}

/** Plano por id. */
async function buscarPlano(idPlano) {
  const doc = await db().collection('planos').doc(idPlano).get();
  return doc.exists ? { idPlano: doc.id, ...doc.data() } : null;
}

/** Cria um novo plano para o paciente (desativa os anteriores). */
async function criarPlano({ uidPaciente, uidNutricionista, nomePlano, objetivo }) {
  const anteriores = await db()
    .collection('planos')
    .where('uidPaciente', '==', uidPaciente)
    .get();
  const lote = db().batch();
  anteriores.forEach((doc) =>
    lote.update(doc.ref, { ativo: false, atualizadoEm: new Date() }),
  );

  const ref = db().collection('planos').doc();
  lote.set(ref, {
    uidPaciente,
    uidNutricionista,
    nomePlano: nomePlano || 'Plano alimentar',
    objetivo: objetivo || '',
    ativo: true,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });
  await lote.commit();
  return { idPlano: ref.id };
}

/** Documento de refeicao: id = "{dia}_{tipo}". */
function refRefeicao(idPlano, dia, tipo) {
  return db().collection('planos').doc(idPlano).collection('refeicoes').doc(`${dia}_${tipo}`);
}

/** Define a receita de uma refeicao do plano. */
async function definirRefeicao(idPlano, dia, tipo, receita) {
  await refRefeicao(idPlano, dia, tipo).set(
    {
      dia,
      tipo,
      rotuloTipo: ROTULOS_REFEICAO[tipo] || tipo,
      rotuloDia: ROTULOS_DIA[dia] || dia,
      horario: receita.horario || null,
      idReceita: receita.idReceita || null,
      nomeReceita: receita.nomeReceita || '',
      calorias: receita.calorias || 0,
      proteinas: receita.proteinas || 0,
      carboidratos: receita.carboidratos || 0,
      gorduras: receita.gorduras || 0,
      ingredientes: receita.ingredientes || [],
      concluidaEm: null,
      atualizadoEm: new Date(),
    },
    { merge: true },
  );
}

/** Remove a receita de uma refeicao do plano. */
async function removerRefeicao(idPlano, dia, tipo) {
  await refRefeicao(idPlano, dia, tipo).delete();
}

/** Renomeia o plano / ajusta objetivo. */
async function atualizarPlano(idPlano, nomePlano, objetivo) {
  await db()
    .collection('planos')
    .doc(idPlano)
    .set(
      {
        ...(nomePlano !== undefined && { nomePlano }),
        ...(objetivo !== undefined && { objetivo }),
        atualizadoEm: new Date(),
      },
      { merge: true },
    );
}

/** Todas as refeicoes do plano. */
async function listarRefeicoes(idPlano) {
  const snap = await db()
    .collection('planos')
    .doc(idPlano)
    .collection('refeicoes')
    .get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

/** Marca/desmarca refeicao concluida (checklist do paciente). */
async function alternarConclusao(idPlano, dia, tipo, concluida) {
  await refRefeicao(idPlano, dia, tipo).set(
    { concluidaEm: concluida ? new Date() : null },
    { merge: true },
  );
}

/** Resumo diario de macronutrientes prescritos no plano. */
async function mediaDiariaDoPlano(idPlano) {
  const refeicoes = await listarRefeicoes(idPlano);
  if (!refeicoes.length) return null;
  const total = refeicoes.reduce(
    (acc, r) => ({
      calorias: acc.calorias + (r.calorias || 0),
      proteinas: acc.proteinas + (r.proteinas || 0),
      carboidratos: acc.carboidratos + (r.carboidratos || 0),
      gorduras: acc.gorduras + (r.gorduras || 0),
    }),
    { calorias: 0, proteinas: 0, carboidratos: 0, gorduras: 0 },
  );
  const dias = new Set(refeicoes.map((r) => r.dia)).size || 1;
  return { diasCadastrados: dias, ...total };
}

// =====================================================================
//  RECEITAS
// =====================================================================

/** Lista receitas do nutricionista (aprovadas ou pendentes do paciente). */
async function listarReceitas(uidNutricionista) {
  const snap = await db()
    .collection('receitas')
    .where('uidNutricionista', '==', uidNutricionista)
    .orderBy('criadoEm', 'desc')
    .get();
  return snap.docs.map((doc) => ({ idReceita: doc.id, ...doc.data() }));
}

/** Receitas enviadas por pacientes com status pendente. */
async function listarReceitasPendentes() {
  const snap = await db()
    .collection('receitas')
    .where('status', '==', 'pendente')
    .get();
  return snap.docs.map((doc) => ({ idReceita: doc.id, ...doc.data() }));
}

/** Receitas criadas/enviadas por um paciente (Minhas Receitas). */
async function listarReceitasDoPaciente(uidPaciente) {
  const snap = await db()
    .collection('receitas')
    .where('uidPacienteAutor', '==', uidPaciente)
    .orderBy('criadoEm', 'desc')
    .get();
  return snap.docs.map((doc) => ({ idReceita: doc.id, ...doc.data() }));
}

/** Receita por id (null quando nao existe). */
async function buscarReceita(idReceita) {
  const doc = await db().collection('receitas').doc(idReceita).get();
  return doc.exists ? { idReceita: doc.id, ...doc.data() } : null;
}

/** Cria ou atualiza receita. `ingredientes`: [{idAlimento, nome, quantidadeG}]. */
async function salvarReceita({ idReceita, uidNutricionista, nome, modoPreparo, ingredientes, status = 'aprovada', uidPacienteAutor = null }) {
  const totais = (ingredientes || []).reduce(
    (acc, ing) => {
      // Macros por 100 g x quantidade em gramas / 100.
      const fator = (ing.quantidadeG || 0) / 100;
      acc.calorias += (ing.calorias || 0) * fator;
      acc.proteinas += (ing.proteinas || 0) * fator;
      acc.carboidratos += (ing.carboidratos || 0) * fator;
      acc.gorduras += (ing.gorduras || 0) * fator;
      return acc;
    },
    { calorias: 0, proteinas: 0, carboidratos: 0, gorduras: 0 },
  );
  const round1 = (v) => Math.round(v * 10) / 10;

  const dados = {
    uidNutricionista,
    ...(uidPacienteAutor && { uidPacienteAutor }),
    nome,
    modoPreparo: modoPreparo || '',
    ingredientes: ingredientes || [],
    calorias: round1(totais.calorias),
    proteinas: round1(totais.proteinas),
    carboidratos: round1(totais.carboidratos),
    gorduras: round1(totais.gorduras),
    status,
    atualizadoEm: new Date(),
  };

  const ref = idReceita
    ? db().collection('receitas').doc(idReceita)
    : db().collection('receitas').doc();

  // `criadoEm` ordena a biblioteca: e definido na criacao e preservado
  // nas edicoes, para a receita nao "pular" para o topo da lista.
  const existente = idReceita ? await ref.get() : null;
  if (!existente?.exists) dados.criadoEm = new Date();

  await ref.set(dados, { merge: true });
  return { idReceita: ref.id, ...dados };
}

/** Aprova ou recusa uma receita enviada por paciente. */
async function avaliarReceita(idReceita, status, justificativa = '') {
  await db()
    .collection('receitas')
    .doc(idReceita)
    .set({ status, ...(justificativa && { justificativa }), avaliadoEm: new Date() }, { merge: true });
}

// =====================================================================
//  ALIMENTOS (base publica usada nas receitas e lista de compras)
// =====================================================================

/** Lista todos os alimentos da base. */
async function listarAlimentos() {
  const snap = await db().collection('alimentos').orderBy('nome', 'asc').get();
  return snap.docs.map((doc) => ({ idAlimento: doc.id, ...doc.data() }));
}

module.exports = {
  TIPOS_REFEICAO,
  ROTULOS_REFEICAO,
  DIAS_SEMANA,
  ROTULOS_DIA,
  buscarPlanoAtivo,
  buscarPlano,
  criarPlano,
  definirRefeicao,
  removerRefeicao,
  listarRefeicoes,
  atualizarPlano,
  alternarConclusao,
  mediaDiariaDoPlano,
  listarReceitas,
  listarReceitasPendentes,
  listarReceitasDoPaciente,
  buscarReceita,
  salvarReceita,
  avaliarReceita,
  listarAlimentos,
};
