/**
 * Rotas de onboarding e perfil do paciente.
 */
'use strict';

const { Router } = require('express');
const perfilController = require('../controllers/perfil.controller');
const { autenticar } = require('../middlewares/auth');

const router = Router();

// Etapas do onboarding (telas 4.5.5 a 4.5.11 do prototipo).
router.get('/nutricionistas', autenticar, perfilController.listarNutricionistas);
router.post('/nutricionista', autenticar, perfilController.escolherNutricionista);
router.post('/dados-pessoais', autenticar, perfilController.salvarDadosPessoais);
router.post('/estilo-vida', autenticar, perfilController.salvarEstiloVida);
router.post('/perfil-alimentar', autenticar, perfilController.salvarPerfilAlimentar);
router.post('/restricoes', autenticar, perfilController.salvarRestricoes);
router.post('/tutorial', autenticar, perfilController.concluirTutorial);

// Edicao de perfil (tela 4.5.19).
router.put('/perfil', autenticar, perfilController.atualizarPerfil);
router.delete('/perfil', autenticar, perfilController.excluirPerfil);

module.exports = router;
