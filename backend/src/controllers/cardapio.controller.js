/**
 * Controller do cardapio (paciente) - abas Cardapio/Bem-Estar,
 * plano semanal, checklist e lista de compras.
 */
'use strict';

const cardapioService = require('../services/cardapio.service');
const AppError = require('../utils/AppError');

/** GET /api/cardapio/hoje - refeicoes do dia + checklist. */
async function obterHoje(req, res, next) {
  try {
    const dados = await cardapioService.obterCardapioDoDia(req.usuario.uid);
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/cardapio/semanal - plano completo por dia. */
async function obterSemanal(req, res, next) {
  try {
    const dados = await cardapioService.obterPlanoSemanal(req.usuario.uid);
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/cardapio/hoje/check { dia, tipo, concluida }. */
async function alternarCheck(req, res, next) {
  try {
    const dia = String(req.body.dia || '').trim();
    const tipo = String(req.body.tipo || '').trim();
    if (!dia || !tipo) {
      throw AppError.badRequest('Informe dia e tipo da refeicao.');
    }
    const dados = await cardapioService.alternarRefeicao({
      uid: req.usuario.uid,
      dia,
      tipo,
      concluida: req.body.concluida === true,
    });
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/cardapio/lista-compras - itens agregados do plano + extras. */
async function listaDeCompras(req, res, next) {
  try {
    const dados = await cardapioService.gerarListaDeCompras(req.usuario.uid);
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/cardapio/lista-compras/item - adiciona item manual. */
async function adicionarItemCompras(req, res, next) {
  try {
    const { nome, categoria, quantidade, unidade } = req.body;
    const item = await cardapioService.adicionarItemListaCompras(req.usuario.uid, {
      nome,
      categoria,
      quantidade,
      unidade,
    });
    res.status(201).json({ sucesso: true, dados: { item } });
  } catch (erro) {
    next(erro);
  }
}

/** DELETE /api/cardapio/lista-compras/item/:idItem - remove item manual. */
async function removerItemCompras(req, res, next) {
  try {
    const idItem = String(req.params.idItem || '').trim();
    if (!idItem) throw AppError.badRequest('Informe o idItem.');
    const dados = await cardapioService.removerItemListaCompras(req.usuario.uid, idItem);
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/cardapio/lista-compras/item/:idItem/toggle { comprado } - alterna status de compra. */
async function alternarItemCompras(req, res, next) {
  try {
    const idItem = String(req.params.idItem || '').trim();
    if (!idItem) throw AppError.badRequest('Informe o idItem.');
    const dados = await cardapioService.alternarItemListaCompras(
      req.usuario.uid,
      idItem,
      req.body.comprado,
    );
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

module.exports = {
  obterHoje,
  obterSemanal,
  alternarCheck,
  listaDeCompras,
  adicionarItemCompras,
  removerItemCompras,
  alternarItemCompras,
};

