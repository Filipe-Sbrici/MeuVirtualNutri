/**
 * Controller da tela de Progresso e dos registros diarios do Bem-Estar.
 */
'use strict';

const progressoService = require('../services/progresso.service');
const AppError = require('../utils/AppError');
const { parseNumber, parseDate } = require('../utils/validators');

/** Data de hoje no formato YYYY-MM-DD usando o fuso local. */
function hojeLocal() {
  const agora = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${agora.getFullYear()}-${p(agora.getMonth() + 1)}-${p(agora.getDate())}`;
}

/**
 * GET /api/progresso
 * Resumo (peso atual, meta, diferenca) + historico do paciente logado.
 */
async function obterResumo(req, res, next) {
  try {
    const dados = await progressoService.obterResumo(req.usuario.uid);
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/**
 * POST /api/progresso/peso
 * Body: { "peso": 68.1, "dataRegistro": "2026-08-16" } (data opcional).
 */
async function registrarPeso(req, res, next) {
  try {
    const peso = parseNumber(req.body.peso, 'peso', { min: 20, max: 400 });
    const dataRegistro = req.body.dataRegistro
      ? parseDate(req.body.dataRegistro, 'dataRegistro')
      : hojeLocal();

    const registro = await progressoService.registrarPeso({
      uid: req.usuario.uid,
      peso,
      dataRegistro,
    });
    const dados = await progressoService.obterResumo(req.usuario.uid);

    res.status(registro.atualizado ? 200 : 201).json({
      sucesso: true,
      registro,
      dados,
    });
  } catch (erro) {
    next(erro);
  }
}

/** DELETE /api/progresso/peso/:dataRegistro (idProgresso = data). */
async function removerPesagem(req, res, next) {
  try {
    const dataRegistro = parseDate(req.params.dataRegistro, 'dataRegistro');
    const registro = await progressoService.removerPesagem({
      uid: req.usuario.uid,
      dataRegistro,
    });
    const dados = await progressoService.obterResumo(req.usuario.uid);
    res.json({ sucesso: true, registro, dados });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/progresso/agua { coposAgua } - contador de hidratacao. */
async function registrarAgua(req, res, next) {
  try {
    const coposAgua = parseNumber(req.body.coposAgua, 'coposAgua', { min: 0, max: 30 });
    const dados = await progressoService.registrarAgua({
      uid: req.usuario.uid,
      coposAgua: Math.round(coposAgua),
    });
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/progresso/humor { humor: 'otimo'|'bom'|'regular'|'ruim' }. */
async function registrarHumor(req, res, next) {
  try {
    const humor = String(req.body.humor || '').trim();
    if (!['otimo', 'bom', 'regular', 'ruim'].includes(humor)) {
      throw AppError.badRequest(
        'O campo "humor" deve ser otimo, bom, regular ou ruim.',
      );
    }
    const dados = await progressoService.registrarHumor({ uid: req.usuario.uid, humor });
    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

module.exports = { obterResumo, registrarPeso, removerPesagem, registrarAgua, registrarHumor };
