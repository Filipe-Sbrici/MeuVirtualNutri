/**
 * Rotas da tela de Chat.
 */
'use strict';

const { Router } = require('express');
const chatController = require('../controllers/chat.controller');
const { autenticar } = require('../middlewares/auth');

const router = Router();

// Conversa entre o usuario logado e o contato (com polling opcional).
router.get('/conversa/:uidContato', autenticar, chatController.listarConversa);

// Envio de nova mensagem.
router.post('/mensagens', autenticar, chatController.enviarMensagem);

// Contato padrao da conversa (nutricionista do paciente logado).
router.get('/contato', autenticar, chatController.obterContatoPadrao);

// Indicador de mensagens nao lidas (banner do Bem-Estar).
router.get('/nao-lidas', autenticar, chatController.contarNaoLidas);

module.exports = router;
