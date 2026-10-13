/**
 * Rotas de onboarding e perfil do paciente.
 */
'use strict';

const { Router } = require('express');
const perfilController = require('../controllers/perfil.controller');
const { autenticar, exigirPaciente } = require('../middlewares/auth');

const router = Router();

// Etapas do onboarding exclusivas do paciente (telas 4.5.5 a 4.5.11 do prototipo).
router.get('/nutricionistas', autenticar, exigirPaciente, perfilController.listarNutricionistas);
router.post('/nutricionista', autenticar, exigirPaciente, perfilController.escolherNutricionista);
router.post('/dados-pessoais', autenticar, exigirPaciente, perfilController.salvarDadosPessoais);
router.post('/estilo-vida', autenticar, exigirPaciente, perfilController.salvarEstiloVida);
router.post('/perfil-alimentar', autenticar, exigirPaciente, perfilController.salvarPerfilAlimentar);
router.post('/restricoes', autenticar, exigirPaciente, perfilController.salvarRestricoes);
router.post('/tutorial', autenticar, exigirPaciente, perfilController.concluirTutorial);

// Edicao de perfil (tela 4.5.19).
router.get('/foto', autenticar, perfilController.obterFotoPerfil);
router.put('/foto', autenticar, perfilController.salvarFotoPerfil);
router.delete('/foto', autenticar, perfilController.removerFotoPerfil);
router.put('/perfil', autenticar, perfilController.atualizarPerfil);
router.delete('/perfil', autenticar, perfilController.excluirPerfil);

module.exports = router;
