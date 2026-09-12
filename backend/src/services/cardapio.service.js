/**
 * Servico do cardapio/plano alimentar.
 *
 * Atende:
 *  - Paciente: plano semanal com checklist por refeicao (tela 4.5.12),
 *    plano semanal completo (4.5.13) e lista de compras (4.5.18).
 *  - Nutricionista: editor de cardapio com wizard 3 passos (4.5.23),
 *    biblioteca de receitas (4.5.24) e receitas compartilhadas (4.5.25).
 *
 * Ao concluir refeicoes, o consumo calorico do dia e consolidado em
 * progresso.consumoCalorico, alimentando o grafico "Consumo Calorico
 * Semanal" da tela de Evolucao.
 */
'use strict';

const planoRepo = require('../repositories/plano.repository');
const usuarioRepo = require('../repositories/usuario.repository');
const progressoService = require('./progresso.service');
const AppError = require('../utils/AppError');
const { round } = require('../utils/validators');

/** Nome do dia de hoje na chave usada pelo plano. */
function diaDeHoje() {
  const mapa = ['domingo', 'segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado'];
  return mapa[new Date().getDay()];
}

/** Paciente ou 404. */
async function carregarPaciente(uid) {
  const paciente = await usuarioRepo.buscarPorUid(uid);
  if (!paciente || paciente.tipoUsuario !== 'paciente') {
    throw AppError.notFound('Paciente nao encontrado.');
  }
  return paciente;
}

/** Garante que o nutricionista e responsavel pelo paciente. */
async function exigirVinculo(uidNutricionista, uidPaciente) {
  const paciente = await carregarPaciente(uidPaciente);
  if (paciente.idNutricionista !== uidNutricionista) {
    throw AppError.forbidden('Paciente nao esta vinculado a voce.');
  }
  return paciente;
}

/** Formato JSON de uma refeicao. */
function refeicaoParaJson(doc) {
  return {
    id: doc.id,
    dia: doc.dia,
    tipo: doc.tipo,
    rotuloDia: doc.rotuloDia,
    rotuloTipo: doc.rotuloTipo,
    horario: doc.horario ?? null,
    nomeReceita: doc.nomeReceita || '',
    idReceita: doc.idReceita ?? null,
    calorias: round(doc.calorias || 0, 0),
    proteinas: round(doc.proteinas || 0, 1),
    carboidratos: round(doc.carboidratos || 0, 1),
    gorduras: round(doc.gorduras || 0, 1),
    ingredientes: doc.ingredientes || [],
    concluida: Boolean(doc.concluidaEm),
  };
}

/**
 * Plano do dia do paciente logado (aba "Cardapio" da tela central).
 * Devolve refeicoes do dia atual + progresso do checklist.
 */
async function obterCardapioDoDia(uid) {
  await carregarPaciente(uid);
  const plano = await planoRepo.buscarPlanoAtivo(uid);
  if (!plano) {
    return { plano: null, dia: diaDeHoje(), refeicoes: [], resumo: null };
  }

  const refeicoes = (await planoRepo.listarRefeicoes(plano.idPlano))
    .filter((r) => r.dia === diaDeHoje())
    .sort((a, b) => planoRepo.TIPOS_REFEICAO.indexOf(a.tipo) - planoRepo.TIPOS_REFEICAO.indexOf(b.tipo))
    .map(refeicaoParaJson);

  return {
    plano: { idPlano: plano.idPlano, nomePlano: plano.nomePlano, objetivo: plano.objetivo },
    dia: diaDeHoje(),
    refeicoes,
    resumo: resumir(refeicoes),
  };
}

/** Plano semanal completo (tela 4.5.13). */
async function obterPlanoSemanal(uid) {
  await carregarPaciente(uid);
  const plano = await planoRepo.buscarPlanoAtivo(uid);
  if (!plano) return { plano: null, dias: [] };

  const todas = await planoRepo.listarRefeicoes(plano.idPlano);
  const dias = planoRepo.DIAS_SEMANA.map((dia) => ({
    dia,
    rotulo: planoRepo.ROTULOS_DIA[dia],
    refeicoes: todas
      .filter((r) => r.dia === dia)
      .sort(
        (a, b) =>
          planoRepo.TIPOS_REFEICAO.indexOf(a.tipo) -
          planoRepo.TIPOS_REFEICAO.indexOf(b.tipo),
      )
      .map(refeicaoParaJson),
  }));

  const preenchidas = todas.length;
  return {
    plano: { idPlano: plano.idPlano, nomePlano: plano.nomePlano, objetivo: plano.objetivo },
    dias,
    progressoMontagem: {
      preenchidas,
      total: planoRepo.DIAS_SEMANA.length * planoRepo.TIPOS_REFEICAO.length,
    },
  };
}

/** Resumo do checklist: concluidas/total + calorias. */
function resumir(refeicoes) {
  const concluidas = refeicoes.filter((r) => r.concluida);
  const totalCalorias = refeicoes.reduce((s, r) => s + r.calorias, 0);
  const caloriasConcluidas = concluidas.reduce((s, r) => s + r.calorias, 0);
  return {
    total: refeicoes.length,
    concluidas: concluidas.length,
    percentual: refeicoes.length
      ? round((concluidas.length / refeicoes.length) * 100, 0)
      : 0,
    totalCalorias: round(totalCalorias, 0),
    caloriasConcluidas: round(caloriasConcluidas, 0),
  };
}

/**
 * Marca/desmarca refeicao concluida e consolida o consumo do dia.
 * A aderencia do dia = % de refeicoes concluidas do cardapio.
 */
async function alternarRefeicao({ uid, dia, tipo, concluida }) {
  await carregarPaciente(uid);
  validarDiaTipo(dia, tipo);

  const plano = await planoRepo.buscarPlanoAtivo(uid);
  if (!plano) throw AppError.notFound('Nao ha plano alimentar ativo.');

  // A refeicao precisa existir no plano: sem esta checagem, um dia/tipo
  // sem receita criaria um documento vazio que inflaria a barra das 42
  // refeicoes do editor.
  const refeicoes = await planoRepo.listarRefeicoes(plano.idPlano);
  const alvo = refeicoes.find((r) => r.dia === dia && r.tipo === tipo);
  if (!alvo) {
    throw AppError.notFound('Esta refeicao nao faz parte do seu plano.');
  }

  await planoRepo.alternarConclusao(plano.idPlano, dia, tipo, concluida);

  // Consolida consumo calorico e aderencia do dia no progresso.
  const doDia = (await planoRepo.listarRefeicoes(plano.idPlano))
    .filter((r) => r.dia === diaDeHoje())
    .map(refeicaoParaJson);
  const resumo = resumir(doDia);
  if (resumo.total > 0) {
    await progressoService.consolidarConsumo({
      uid,
      consumoCalorico: resumo.caloriasConcluidas,
      aderenciaPlano: resumo.percentual,
    });
  }

  return { dia, tipo, concluida, resumo };
}

/**
 * Lista de compras gerada dos ingredientes do plano semanal (4.5.18)
 * somada aos itens manuais adicionados pelo paciente.
 */
async function gerarListaDeCompras(uid) {
  const paciente = await carregarPaciente(uid);
  const plano = await planoRepo.buscarPlanoAtivo(uid);

  const porAlimento = new Map();

  if (plano) {
    const refeicoes = await planoRepo.listarRefeicoes(plano.idPlano);
    for (const r of refeicoes) {
      for (const ing of r.ingredientes || []) {
        const chave = `plano_${ing.idAlimento || ing.nome}`;
        const atual = porAlimento.get(chave) || {
          id: chave,
          idAlimento: ing.idAlimento ?? null,
          nome: ing.nome,
          categoria: ing.categoria || 'Outros',
          quantidadeG: 0,
          unidade: ing.unidade || 'g',
          comprado: false,
          manual: false,
        };
        atual.quantidadeG = round(atual.quantidadeG + (ing.quantidadeG || 0), 0);
        porAlimento.set(chave, atual);
      }
    }
  }

  // Itens manuais adicionados pelo paciente
  const itensExtras = paciente.itensListaComprasExtras || [];
  for (const item of itensExtras) {
    porAlimento.set(item.id, {
      id: item.id,
      nome: item.nome,
      categoria: item.categoria || 'Outros',
      quantidadeG: item.quantidade || 1,
      unidade: item.unidade || 'un',
      comprado: item.comprado === true,
      manual: true,
    });
  }

  const itens = [...porAlimento.values()].sort(
    (a, b) => a.categoria.localeCompare(b.categoria) || a.nome.localeCompare(b.nome),
  );
  return { itens };
}

/** Adiciona item manual à lista de compras do paciente. */
async function adicionarItemListaCompras(uid, { nome, categoria = 'Outros', quantidade = 1, unidade = 'un' }) {
  if (!nome || !String(nome).trim()) throw AppError.badRequest('Nome do item é obrigatório.');
  const paciente = await carregarPaciente(uid);
  const itens = paciente.itensListaComprasExtras || [];

  const novoItem = {
    id: `item_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    nome: String(nome).trim(),
    categoria: String(categoria || 'Outros').trim(),
    quantidade: Number(quantidade) || 1,
    unidade: String(unidade || 'un').trim(),
    comprado: false,
    criadoEm: new Date().toISOString(),
  };

  itens.push(novoItem);
  await usuarioRepo.atualizar(uid, { itensListaComprasExtras: itens });
  return novoItem;
}

/** Remove item manual da lista de compras. */
async function removerItemListaCompras(uid, idItem) {
  const paciente = await carregarPaciente(uid);
  const itens = (paciente.itensListaComprasExtras || []).filter((i) => i.id !== idItem);
  await usuarioRepo.atualizar(uid, { itensListaComprasExtras: itens });
  return { removido: true, idItem };
}

/** Alterna status comprado de um item manual da lista de compras. */
async function alternarItemListaCompras(uid, idItem, comprado) {
  const paciente = await carregarPaciente(uid);
  const itens = (paciente.itensListaComprasExtras || []).map((i) => {
    if (i.id === idItem) return { ...i, comprado: Boolean(comprado) };
    return i;
  });
  await usuarioRepo.atualizar(uid, { itensListaComprasExtras: itens });
  return { idItem, comprado: Boolean(comprado) };
}

/** Nutricionista consulta a lista de compras do paciente (respeitando privacidade). */
async function obterListaComprasPaciente(uidNutricionista, uidPaciente) {
  const paciente = await exigirVinculo(uidNutricionista, uidPaciente);

  if (paciente.compartilharListaCompras === false) {
    return {
      permitido: false,
      mensagem: 'O paciente optou por manter a lista de compras privada.',
      itens: [],
    };
  }

  const { itens } = await gerarListaDeCompras(uidPaciente);
  return {
    permitido: true,
    itens,
  };
}


// =====================================================================
//  NUTRICIONISTA
// =====================================================================

/** Lista de pacientes com resumo clinico (perfil clinico 4.5.22). */
async function listarPacientes(uidNutricionista) {
  const pacientes = await usuarioRepo.listarPacientesDoNutricionista(uidNutricionista);
  return Promise.all(
    pacientes.map(async (p) => {
      const plano = await planoRepo.buscarPlanoAtivo(p.uid);
      return {
        uid: p.uid,
        nome: p.nome,
        email: p.email,
        idade: p.idade,
        pesoAtual: p.pesoAtual,
        pesoMeta: p.pesoMeta,
        altura: p.altura,
        genero: p.genero,
        objetivo: p.meta,
        tipoDieta: p.tipoDieta,
        restricoes: p.restricoes,
        condicoesMedicas: p.condicoesMedicas,
        alimentosFavoritos: p.alimentosFavoritos,
        alimentosRejeitados: p.alimentosRejeitados,
        onboardingCompleto: p.onboardingCompleto,
        temPlanoAtivo: Boolean(plano),
        nomePlano: plano?.nomePlano ?? null,
      };
    }),
  );
}

/** Plano semanal de um paciente pelo nutricionista (editor). */
async function obterPlanoParaEdicao({ uidNutricionista, uidPaciente }) {
  await exigirVinculo(uidNutricionista, uidPaciente);

  let plano = await planoRepo.buscarPlanoAtivo(uidPaciente);
  if (!plano) {
    // O editor sempre trabalha sobre um plano; cria o primeiro se preciso.
    const criado = await planoRepo.criarPlano({
      uidPaciente,
      uidNutricionista,
      nomePlano: 'Plano alimentar',
      objetivo: '',
    });
    plano = await planoRepo.buscarPlano(criado.idPlano);
  }

  const todas = await planoRepo.listarRefeicoes(plano.idPlano);
  return {
    plano: {
      idPlano: plano.idPlano,
      nomePlano: plano.nomePlano,
      objetivo: plano.objetivo,
    },
    paciente: { uid: uidPaciente },
    refeicoes: todas.map(refeicaoParaJson),
    tiposRefeicao: planoRepo.ROTULOS_REFEICAO,
    diasSemana: planoRepo.ROTULOS_DIA,
    progressoMontagem: {
      preenchidas: todas.length,
      total: planoRepo.DIAS_SEMANA.length * planoRepo.TIPOS_REFEICAO.length,
    },
  };
}

/** Wizard passo 3: define a receita numa refeicao do plano. */
async function definirRefeicao({ uidNutricionista, uidPaciente, dia, tipo, idReceita, horario }) {
  await exigirVinculo(uidNutricionista, uidPaciente);
  validarDiaTipo(dia, tipo);

  // Busca a receita na biblioteca do proprio nutricionista.
  const receitas = await planoRepo.listarReceitas(uidNutricionista);
  const receita = receitas.find((r) => r.idReceita === idReceita);
  if (!receita) throw AppError.notFound('Receita nao encontrada na sua biblioteca.');

  let plano = await planoRepo.buscarPlanoAtivo(uidPaciente);
  if (!plano) {
    const criado = await planoRepo.criarPlano({
      uidPaciente,
      uidNutricionista,
      nomePlano: 'Plano alimentar',
    });
    plano = await planoRepo.buscarPlano(criado.idPlano);
  }

  await planoRepo.definirRefeicao(plano.idPlano, dia, tipo, {
    idReceita: receita.idReceita,
    nomeReceita: receita.nome,
    calorias: receita.calorias,
    proteinas: receita.proteinas,
    carboidratos: receita.carboidratos,
    gorduras: receita.gorduras,
    ingredientes: receita.ingredientes,
    horario,
  });

  return { dia, tipo, nomeReceita: receita.nome };
}

/** Remove uma refeicao do plano (editor). */
async function removerRefeicao({ uidNutricionista, uidPaciente, dia, tipo }) {
  await exigirVinculo(uidNutricionista, uidPaciente);
  validarDiaTipo(dia, tipo);

  const plano = await planoRepo.buscarPlanoAtivo(uidPaciente);
  if (!plano) throw AppError.notFound('Nao ha plano alimentar ativo.');
  await planoRepo.removerRefeicao(plano.idPlano, dia, tipo);
  return { dia, tipo, removida: true };
}

function validarDiaTipo(dia, tipo) {
  if (!planoRepo.DIAS_SEMANA.includes(dia)) {
    throw AppError.badRequest('Dia da semana invalido.');
  }
  if (!planoRepo.TIPOS_REFEICAO.includes(tipo)) {
    throw AppError.badRequest('Tipo de refeicao invalido.');
  }
}

/** Renomeia o plano / ajusta objetivo. */
async function atualizarPlano({ uidNutricionista, uidPaciente, nomePlano, objetivo }) {
  await exigirVinculo(uidNutricionista, uidPaciente);
  const plano = await planoRepo.buscarPlanoAtivo(uidPaciente);
  if (!plano) throw AppError.notFound('Nao ha plano alimentar ativo.');
  await planoRepo.atualizarPlano(plano.idPlano, nomePlano, objetivo);
  return { idPlano: plano.idPlano };
}

// =====================================================================
//  RECEITAS
// =====================================================================

/** Biblioteca de receitas do nutricionista. */
async function listarReceitas(uidNutricionista) {
  return planoRepo.listarReceitas(uidNutricionista);
}

/** Base de alimentos para montar receitas. */
async function listarAlimentos() {
  return planoRepo.listarAlimentos();
}

/** Cria/atualiza receita com macros calculados dos ingredientes. */
async function salvarReceita({ uidNutricionista, dados }) {
  const nome = String(dados.nome || '').trim();
  if (!nome) throw AppError.badRequest('Informe o nome da receita.');
  if (!Array.isArray(dados.ingredientes) || dados.ingredientes.length === 0) {
    throw AppError.badRequest('A receita precisa de pelo menos um ingrediente.');
  }

  const idReceita = dados.idReceita ? String(dados.idReceita).trim() : null;
  if (idReceita) {
    // Edicao: a receita precisa existir e ser da biblioteca deste
    // nutricionista (senao um id arbitrario sobrescreveria a de outro).
    const atual = await planoRepo.buscarReceita(idReceita);
    if (!atual) throw AppError.notFound('Receita nao encontrada.');
    if (atual.uidNutricionista !== uidNutricionista) {
      throw AppError.forbidden('Esta receita nao esta na sua biblioteca.');
    }
  }

  return planoRepo.salvarReceita({
    idReceita,
    uidNutricionista,
    nome,
    modoPreparo: dados.modoPreparo,
    ingredientes: dados.ingredientes,
  });
}

/** Receitas enviadas por pacientes aguardando avaliacao. */
async function listarReceitasPendentes(uidNutricionista) {
  const pendentes = await planoRepo.listarReceitasPendentes();
  // Cada receita pendente pertence ao nutricionista vinculado ao autor:
  // um profissional nunca avalia (nem enxerga) receitas de outro.
  return pendentes.filter((r) => r.uidNutricionista === uidNutricionista);
}

/** Paciente compartilha uma receita para aprovacao (tela Minhas Receitas). */
async function compartilharReceita({ uidPaciente, dados }) {
  const paciente = await carregarPaciente(uidPaciente);
  if (!paciente.idNutricionista) {
    throw AppError.badRequest('Escolha um nutricionista antes de compartilhar receitas.');
  }
  const nome = String(dados.nome || '').trim();
  if (!nome) throw AppError.badRequest('Informe o nome da receita.');

  return planoRepo.salvarReceita({
    uidNutricionista: paciente.idNutricionista,
    uidPacienteAutor: uidPaciente,
    nome,
    modoPreparo: dados.modoPreparo,
    ingredientes: dados.ingredientes || [],
    status: 'pendente',
  });
}

/** Aprova/recusa receita compartilhada. */
async function avaliarReceita({ uidNutricionista, idReceita, status, justificativa }) {
  if (!['aprovada', 'recusada'].includes(status)) {
    throw AppError.badRequest('Status deve ser aprovada ou recusada.');
  }
  const receita = await planoRepo.buscarReceita(idReceita);
  if (!receita) throw AppError.notFound('Receita nao encontrada.');
  if (receita.uidNutricionista !== uidNutricionista) {
    throw AppError.forbidden('Esta receita nao foi enviada a voce.');
  }
  await planoRepo.avaliarReceita(idReceita, status, justificativa);
  return { idReceita, status };
}

/** Receitas do paciente: aprovadas por ele + as que ele enviou. */
async function minhasReceitas(uidPaciente) {
  const snap = await planoRepo.listarReceitasDoPaciente(uidPaciente);
  return snap;
}

module.exports = {
  obterCardapioDoDia,
  obterPlanoSemanal,
  alternarRefeicao,
  gerarListaDeCompras,
  adicionarItemListaCompras,
  removerItemListaCompras,
  alternarItemListaCompras,
  obterListaComprasPaciente,
  listarPacientes,
  obterPlanoParaEdicao,
  definirRefeicao,
  removerRefeicao,
  atualizarPlano,
  listarReceitas,
  listarAlimentos,
  salvarReceita,
  listarReceitasPendentes,
  compartilharReceita,
  avaliarReceita,
  minhasReceitas,
};

