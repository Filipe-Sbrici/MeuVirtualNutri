/**
 * Rotas de assinatura do nutricionista (Mercado Pago).
 *
 * - Webhook publico: POST /api/assinatura/webhook
 * - Rotas autenticadas (nutricionista):
 *   - GET  /api/assinatura/status
 *   - POST /api/assinatura/assinar
 *   - POST /api/assinatura/sincronizar
 *   - POST /api/assinatura/cancelar
 */
'use strict';

const { Router } = require('express');
const controller = require('../controllers/assinatura.controller');
const { autenticar, exigirNutricionista } = require('../middlewares/auth');

const router = Router();

// Webhook chamado diretamente pelos servidores do Mercado Pago
router.post('/webhook', controller.webhookMercadoPago);

// Demais rotas exigem autenticacao Firebase de um nutricionista
router.use(autenticar, exigirNutricionista);

router.get('/status', controller.obterStatus);
router.post('/assinar', controller.assinar);
router.post('/sincronizar', controller.sincronizar);
router.post('/cancelar', controller.cancelar);

module.exports = router;

