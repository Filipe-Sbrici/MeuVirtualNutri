/**
 * Controller de assinatura do nutricionista (Mercado Pago + Firestore).
 */
'use strict';

const assinaturaService = require('../services/assinatura.service');
const usuarioRepo = require('../repositories/usuario.repository');
const { perfilParaJson } = require('./auth.controller');

/** GET /api/assinatura/status */
async function obterStatus(req, res, next) {
  try {
    const assinatura = await assinaturaService.obterStatusAssinatura(req.usuario.uid);
    res.json({ sucesso: true, dados: { assinatura } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/assinatura/assinar { metodoPagamento, confirmarImediatamente } */
async function assinar(req, res, next) {
  try {
    const metodoPagamento = String(req.body.metodoPagamento || 'pix').trim().toLowerCase();
    const confirmarImediatamente = req.body.confirmarImediatamente === true;

    const assinatura = await assinaturaService.iniciarAssinatura({
      uidNutricionista: req.usuario.uid,
      metodoPagamento,
      confirmarImediatamente,
    });
    const perfilAtualizado = await usuarioRepo.buscarPorUid(req.usuario.uid);

    res.status(201).json({
      sucesso: true,
      dados: {
        assinatura,
        perfil: perfilAtualizado ? perfilParaJson(perfilAtualizado) : null,
      },
    });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/assinatura/sincronizar - confirma/sincroniza pagamento no Mercado Pago */
async function sincronizar(req, res, next) {
  try {
    const assinatura = await assinaturaService.confirmarOuSincronizarAssinatura(req.usuario.uid);
    const perfilAtualizado = await usuarioRepo.buscarPorUid(req.usuario.uid);

    res.json({
      sucesso: true,
      dados: {
        assinatura,
        perfil: perfilAtualizado ? perfilParaJson(perfilAtualizado) : null,
      },
    });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/assinatura/cancelar */
async function cancelar(req, res, next) {
  try {
    const assinatura = await assinaturaService.cancelarAssinatura(req.usuario.uid);
    const perfilAtualizado = await usuarioRepo.buscarPorUid(req.usuario.uid);

    res.json({
      sucesso: true,
      dados: {
        assinatura,
        perfil: perfilAtualizado ? perfilParaJson(perfilAtualizado) : null,
      },
    });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/assinatura/webhook - notificacao automatica do Mercado Pago */
async function webhookMercadoPago(req, res, next) {
  try {
    const resultado = await assinaturaService.processarWebhookMercadoPago(req.body, req.query);
    res.status(200).json({ sucesso: true, dados: resultado });
  } catch (erro) {
    next(erro);
  }
}

module.exports = {
  obterStatus,
  assinar,
  sincronizar,
  cancelar,
  webhookMercadoPago,
};

