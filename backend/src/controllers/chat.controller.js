/**
 * Controller da tela de Chat.
 * Responsavel apenas por traduzir HTTP <-> servico.
 */
'use strict';

const chatService = require('../services/chat.service');
const { parseText } = require('../utils/validators');
const AppError = require('../utils/AppError');

/**
 * GET /api/chat/conversa/:uidContato?depoisDe=<idMensagem>
 * Cabecalho do contato e mensagens. `depoisDe` ausente devolve tudo.
 */
async function listarConversa(req, res, next) {
  try {
    const uidContato = String(req.params.uidContato || '').trim();
    if (!uidContato) throw AppError.badRequest('Informe o contato da conversa.');

    const dados = await chatService.obterConversa({
      usuario: req.usuario,
      uidContato,
      depoisDe: req.query.depoisDe ? String(req.query.depoisDe) : null,
    });
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/chat/mensagens { uidContato, mensagem } */
async function enviarMensagem(req, res, next) {
  try {
    const criada = await chatService.enviarMensagem({
      usuario: req.usuario,
      uidContato: req.body.uidContato,
      texto: parseText(req.body.mensagem, 'mensagem', chatService.TAMANHO_MAX_MENSAGEM),
    });
    res.status(201).json({ sucesso: true, dados: criada });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/chat/contato[?uidPaciente=...] */
async function obterContatoPadrao(req, res, next) {
  try {
    const dados = await chatService.obterContatoPadrao({
      usuario: req.usuario,
      uidPaciente: String(req.query.uidPaciente || '').trim(),
    });
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/chat/nao-lidas */
async function contarNaoLidas(req, res, next) {
  try {
    const total = await chatService.contarNaoLidas(req.usuario.uid);
    res.json({ sucesso: true, dados: { total } });
  } catch (erro) {
    next(erro);
  }
}

module.exports = { listarConversa, enviarMensagem, obterContatoPadrao, contarNaoLidas };
