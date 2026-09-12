/**
 * Rotas de autenticacao e perfil de sessao.
 * Credenciais (e-mail/senha) sao geridas pelo Firebase Authentication
 * no proprio aplicativo; a API apenas materializa o perfil Firestore.
 */
'use strict';

const { Router } = require('express');
const authController = require('../controllers/auth.controller');
const { autenticar, autenticarToken } = require('../middlewares/auth');

const router = Router();

// Materializa o perfil apos o Flutter criar a conta no Firebase Auth.
// Apenas o token e exigido: o perfil ainda nao existe (e criado aqui).
router.post('/cadastro/paciente', autenticarToken, authController.cadastrarPaciente);
router.post('/cadastro/nutricionista', autenticarToken, authController.cadastrarNutricionista);

// Perfil da sessao atual.
router.get('/perfil', autenticar, authController.obterPerfil);

// Apenas em FIREBASE_DEMO_MODE=true (sem Firebase de verdade).
router.post('/login', authController.loginDemo);

module.exports = router;
