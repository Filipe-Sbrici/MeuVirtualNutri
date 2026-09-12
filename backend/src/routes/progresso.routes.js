/**
 * Rotas da tela de Progresso e dos registros diarios.
 */
'use strict';

const { Router } = require('express');
const progressoController = require('../controllers/progresso.controller');
const { autenticar } = require('../middlewares/auth');

const router = Router();

// Resumo + historico de pesagens do paciente logado.
router.get('/', autenticar, progressoController.obterResumo);

// "+ REGISTRAR PESO"
router.post('/peso', autenticar, progressoController.registrarPeso);

// Botao "x" no Historico de Peso (idProgresso = data YYYY-MM-DD).
router.delete('/peso/:dataRegistro', autenticar, progressoController.removerPesagem);

// Contador de agua do Bem-Estar.
router.post('/agua', autenticar, progressoController.registrarAgua);

// Termometro emocional do Bem-Estar.
router.post('/humor', autenticar, progressoController.registrarHumor);

module.exports = router;
