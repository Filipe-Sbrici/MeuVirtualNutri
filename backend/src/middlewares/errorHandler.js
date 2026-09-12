/**
 * Middleware de tratamento de erros.
 * Garante que a API responda SEMPRE em JSON, inclusive em falhas.
 */
'use strict';

const AppError = require('../utils/AppError');

/** Rota inexistente -> 404 em JSON. */
function notFoundHandler(req, res) {
  res.status(404).json({
    sucesso: false,
    erro: {
      mensagem: `Rota nao encontrada: ${req.method} ${req.originalUrl}`,
    },
  });
}

/** Handler final de erros (assinatura de 4 argumentos exigida pelo Express). */
function errorHandler(erro, req, res, _next) {
  // Erros previstos da aplicacao.
  if (erro instanceof AppError) {
    return res.status(erro.status).json({
      sucesso: false,
      erro: { mensagem: erro.message, detalhes: erro.details },
    });
  }

  // Erros de configuracao do Firebase (sem projectId/credencial) antes
  // de qualquer codigo: mensagem pratica para quem esta subindo a API.
  const mensagem = String(erro.message || '');
  if (
    /unable to detect a project id/i.test(mensagem) ||
    /could not load the default credentials/i.test(mensagem)
  ) {
    return res.status(503).json({
      sucesso: false,
      erro: {
        mensagem:
          'Firebase nao configurado: defina FIREBASE_PROJECT_ID e a ' +
          'credencial (GOOGLE_APPLICATION_CREDENTIALS ou FIREBASE_SERVICE_ACCOUNT) ' +
          'no .env, ou use FIRESTORE_EMULATOR_HOST para o emulador.',
      },
    });
  }

  // Erros conhecidos do Firebase, traduzidos para mensagens uteis.
  const mapaFirebase = {
    'auth/invalid-id-token':
      'Sessao invalida. Entre novamente para gerar um novo token.',
    'app/invalid-credential':
      'Credencial do Firebase invalida. Verifique a conta de servico (FIREBASE_SERVICE_ACCOUNT ou GOOGLE_APPLICATION_CREDENTIALS).',
    'permission-denied':
      'Acesso negado pelo Firestore. Verifique as regras de seguranca e a conta de servico.',
    unavailable:
      'Servico Firebase indisponivel. Tente novamente em instantes.',
    'firestore/failed-precondition':
      'Consulta bloqueada pelo Firestore. Verifique os indices compostos exigidos.',
  };

  const mensagemFirebase = mapaFirebase[erro.code];
  if (mensagemFirebase) {
    // eslint-disable-next-line no-console
    console.error('[Firebase]', erro.code, erro.message);
    return res
      .status(503)
      .json({ sucesso: false, erro: { mensagem: mensagemFirebase, codigo: erro.code } });
  }

  // eslint-disable-next-line no-console
  console.error('[Erro nao tratado]', erro);
  return res.status(500).json({
    sucesso: false,
    erro: { mensagem: 'Erro interno no servidor.' },
  });
}

module.exports = { notFoundHandler, errorHandler };
