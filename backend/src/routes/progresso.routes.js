/**
 * Rotas da tela de Progresso e dos registros diarios.
 */
'use strict';

const { Router } = require('express');
const progressoController = require('../controllers/progresso.controller');
const { autenticar, exigirPaciente } = require('../middlewares/auth');

const router = Router();

// Todas as rotas de progresso sao exclusivas do paciente.
router.use(autenticar, exigirPaciente);

// Resumo + historico de pesagens do paciente logado.
router.get('/', progressoController.obterResumo);

// "+ REGISTRAR PESO"
router.post('/peso', progressoController.registrarPeso);

// Botao "x" no Historico de Peso (idProgresso = data YYYY-MM-DD).
router.delete('/peso/:dataRegistro', progressoController.removerPesagem);

// Contador de agua do Bem-Estar.
router.post('/agua', progressoController.registrarAgua);

// Termometro emocional do Bem-Estar.
router.post('/humor', progressoController.registrarHumor);

module.exports = router;
