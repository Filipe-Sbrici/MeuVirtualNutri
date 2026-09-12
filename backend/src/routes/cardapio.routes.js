/**
 * Rotas do cardapio do paciente.
 */
'use strict';

const { Router } = require('express');
const cardapioController = require('../controllers/cardapio.controller');
const { autenticar } = require('../middlewares/auth');

const router = Router();

// Aba "Cardapio" (refeicoes de hoje + checklist).
router.get('/hoje', autenticar, cardapioController.obterHoje);

// Plano alimentar semanal completo.
router.get('/semanal', autenticar, cardapioController.obterSemanal);

// Checklist: marcar/desmarcar refeicao concluida.
router.post('/hoje/check', autenticar, cardapioController.alternarCheck);

// Lista de compras gerada do plano e itens manuais.
router.get('/lista-compras', autenticar, cardapioController.listaDeCompras);
router.post('/lista-compras/item', autenticar, cardapioController.adicionarItemCompras);
router.delete('/lista-compras/item/:idItem', autenticar, cardapioController.removerItemCompras);
router.post('/lista-compras/item/:idItem/toggle', autenticar, cardapioController.alternarItemCompras);

module.exports = router;

