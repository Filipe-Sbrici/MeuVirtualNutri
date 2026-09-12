/**
 * Rotas da tela de Evolucao.
 */
'use strict';

const { Router } = require('express');
const evolucaoController = require('../controllers/evolucao.controller');
const { autenticar } = require('../middlewares/auth');

const router = Router();

// Graficos do paciente logado (ou de um paciente do nutricionista).
router.get('/:uidPaciente?', autenticar, evolucaoController.obterEvolucao);

module.exports = router;
