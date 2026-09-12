/**
 * Controller do painel do nutricionista.
 * Rotas protegidas por `exigirNutricionista`.
 */
'use strict';

const cardapioService = require('../services/cardapio.service');
const usuarioRepo = require('../repositories/usuario.repository');
const AppError = require('../utils/AppError');

function exigirUidPaciente(req) {
  const uid = String(req.body.uidPaciente || req.query.uidPaciente || '').trim();
  if (!uid) throw AppError.badRequest('Informe o paciente (uidPaciente).');
  return uid;
}

/** GET /api/nutricionista/pacientes - lista com resumo clinico. */
async function listarPacientes(req, res, next) {
  try {
    const pacientes = await cardapioService.listarPacientes(req.usuario.uid);
    res.json({ sucesso: true, dados: { pacientes } });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/nutricionista/pacientes/:uid/plano - plano para edicao. */
async function obterPlanoParaEdicao(req, res, next) {
  try {
    const dados = await cardapioService.obterPlanoParaEdicao({
      uidNutricionista: req.usuario.uid,
      uidPaciente: String(req.params.uid || '').trim(),
    });
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** PUT /api/nutricionista/pacientes/:uid/plano - nome/objetivo. */
async function atualizarPlano(req, res, next) {
  try {
    const dados = await cardapioService.atualizarPlano({
      uidNutricionista: req.usuario.uid,
      uidPaciente: String(req.params.uid || '').trim(),
      nomePlano: req.body.nomePlano,
      objetivo: req.body.objetivo,
    });
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/nutricionista/pacientes/:uid/plano/refeicoes - wizard p3. */
async function definirRefeicao(req, res, next) {
  try {
    const dados = await cardapioService.definirRefeicao({
      uidNutricionista: req.usuario.uid,
      uidPaciente: String(req.params.uid || '').trim(),
      dia: String(req.body.dia || '').trim(),
      tipo: String(req.body.tipo || '').trim(),
      idReceita: String(req.body.idReceita || '').trim(),
      horario: req.body.horario ? String(req.body.horario) : null,
    });
    res.status(201).json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** DELETE /api/nutricionista/pacientes/:uid/plano/refeicoes?dia=&tipo=. */
async function removerRefeicao(req, res, next) {
  try {
    const dados = await cardapioService.removerRefeicao({
      uidNutricionista: req.usuario.uid,
      uidPaciente: String(req.params.uid || '').trim(),
      dia: String(req.query.dia || '').trim(),
      tipo: String(req.query.tipo || '').trim(),
    });
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/nutricionista/receitas - biblioteca propria. */
async function listarReceitas(req, res, next) {
  try {
    const receitas = await cardapioService.listarReceitas(req.usuario.uid);
    res.json({ sucesso: true, dados: { receitas } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/nutricionista/receitas - cria/atualiza receita. */
async function salvarReceita(req, res, next) {
  try {
    const receita = await cardapioService.salvarReceita({
      uidNutricionista: req.usuario.uid,
      dados: req.body,
    });
    res.status(201).json({ sucesso: true, dados: receita });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/nutricionista/receitas/pendentes - compartilhadas. */
async function listarReceitasPendentes(req, res, next) {
  try {
    const receitas = await cardapioService.listarReceitasPendentes(req.usuario.uid);
    res.json({ sucesso: true, dados: { receitas } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/nutricionista/receitas/:id/avaliar { status, justificativa }. */
async function avaliarReceita(req, res, next) {
  try {
    const dados = await cardapioService.avaliarReceita({
      uidNutricionista: req.usuario.uid,
      idReceita: String(req.params.id || '').trim(),
      status: String(req.body.status || '').trim(),
      justificativa: req.body.justificativa ? String(req.body.justificativa) : '',
    });
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/nutricionista/alimentos - base para montar receitas. */
async function listarAlimentos(_req, res, next) {
  try {
    const alimentos = await cardapioService.listarAlimentos();
    res.json({ sucesso: true, dados: { alimentos } });
  } catch (erro) {
    next(erro);
  }
}

/**
 * POST /api/nutricionista/pacientes { uidPaciente } - vincula paciente
 * existente ao nutricionista (tela 4.5.21). O paciente cria a conta no
 * app e informa seu e-mail, ou o nutricionista busca por e-mail.
 */
async function vincularPaciente(req, res, next) {
  try {
    const uid = String(req.body.uidPaciente || '').trim();
    const email = String(req.body.email || '').trim().toLowerCase();
    if (!uid && !email) {
      throw AppError.badRequest('Informe uidPaciente ou email do paciente.');
    }

    const paciente = uid
      ? await usuarioRepo.buscarPorUid(uid)
      : await usuarioRepo.buscarPorEmail(email);
    if (!paciente || paciente.tipoUsuario !== 'paciente') {
      throw AppError.notFound('Paciente nao encontrado.');
    }
    if (paciente.idNutricionista && paciente.idNutricionista !== req.usuario.uid) {
      throw AppError.conflict('Paciente ja vinculado a outro nutricionista.');
    }

    await usuarioRepo.vincularNutricionista(paciente.uid, req.usuario.uid, 'aprovado');
    res.status(201).json({
      sucesso: true,
      dados: { uidPaciente: paciente.uid, nome: paciente.nome },
    });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/nutricionista/solicitacoes - lista solicitacoes pendentes. */
async function listarSolicitacoes(req, res, next) {
  try {
    const solicitacoes = await usuarioRepo.listarSolicitacoesDoNutricionista(req.usuario.uid);
    res.json({ sucesso: true, dados: { solicitacoes } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/nutricionista/solicitacoes/:uid/aceitar - aceita solicitacao. */
async function aceitarSolicitacao(req, res, next) {
  try {
    const uidPaciente = String(req.params.uid || '').trim();
    if (!uidPaciente) throw AppError.badRequest('Informe o uid do paciente.');
    const paciente = await usuarioRepo.buscarPorUid(uidPaciente);
    if (!paciente || paciente.tipoUsuario !== 'paciente') {
      throw AppError.notFound('Paciente nao encontrado.');
    }
    await usuarioRepo.aceitarSolicitacao(uidPaciente, req.usuario.uid);
    res.json({
      sucesso: true,
      dados: { uidPaciente, mensagem: 'Solicitacao de atendimento aceita com sucesso.' },
    });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/nutricionista/solicitacoes/:uid/recusar - recusa solicitacao. */
async function recusarSolicitacao(req, res, next) {
  try {
    const uidPaciente = String(req.params.uid || '').trim();
    if (!uidPaciente) throw AppError.badRequest('Informe o uid do paciente.');
    await usuarioRepo.recusarSolicitacao(uidPaciente, req.usuario.uid);
    res.json({
      sucesso: true,
      dados: { uidPaciente, mensagem: 'Solicitacao recusada.' },
    });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/nutricionista/pacientes/:uid/lista-compras */
async function obterListaComprasPaciente(req, res, next) {
  try {
    const uidPaciente = String(req.params.uid || '').trim();
    if (!uidPaciente) throw AppError.badRequest('Informe o uid do paciente.');
    const dados = await cardapioService.obterListaComprasPaciente(
      req.usuario.uid,
      uidPaciente,
    );
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

module.exports = {
  listarPacientes,
  vincularPaciente,
  listarSolicitacoes,
  aceitarSolicitacao,
  recusarSolicitacao,
  obterPlanoParaEdicao,
  atualizarPlano,
  definirRefeicao,
  removerRefeicao,
  listarReceitas,
  salvarReceita,
  listarReceitasPendentes,
  avaliarReceita,
  listarAlimentos,
  obterListaComprasPaciente,
};

