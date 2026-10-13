/**
 * Rotas do cardapio do paciente.
 */
'use strict';

const { Router } = require('express');
const cardapioController = require('../controllers/cardapio.controller');
const { autenticar, exigirPaciente } = require('../middlewares/auth');

const router = Router();

// Todas as rotas de cardapio sao exclusivas do paciente.
router.use(autenticar, exigirPaciente);

// Aba "Cardapio" (refeicoes de hoje + checklist).
router.get('/hoje', cardapioController.obterHoje);

// Plano alimentar semanal completo.
router.get('/semanal', cardapioController.obterSemanal);

// Checklist: marcar/desmarcar refeicao concluida.
router.post('/hoje/check', cardapioController.alternarCheck);

// Lista de compras gerada do plano e itens manuais.
router.get('/lista-compras', cardapioController.listaDeCompras);
router.post('/lista-compras/item', cardapioController.adicionarItemCompras);
router.delete('/lista-compras/item/:idItem', cardapioController.removerItemCompras);
router.post('/lista-compras/item/:idItem/toggle', cardapioController.alternarItemCompras);

module.exports = router;

