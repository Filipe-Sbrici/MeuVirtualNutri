/**
 * Controller da tela de Evolucao.
 *
 * GET /api/evolucao              -> paciente logado
 * GET /api/evolucao/:uidPaciente -> outro paciente (uso do nutricionista
 *                                    no perfil clinico; a vinculo e
 *                                    verificado no controller).
 */
'use strict';

const evolucaoService = require('../services/evolucao.service');
const usuarioRepo = require('../repositories/usuario.repository');
const AppError = require('../utils/AppError');
const { parsePeriodo } = require('../utils/validators');

async function obterEvolucao(req, res, next) {
  try {
    const uidAlvo = String(req.params.uidPaciente || req.usuario.uid).trim();

    // O paciente so consulta a si mesmo; o nutricionista, aos seus.
    if (uidAlvo !== req.usuario.uid) {
      if (req.usuario.tipoUsuario !== 'nutricionista') {
        throw AppError.forbidden('Voce so pode consultar sua propria evolucao.');
      }
      const alvo = await usuarioRepo.buscarPorUid(uidAlvo);
      if (!alvo || alvo.idNutricionista !== req.usuario.uid) {
        throw AppError.forbidden('Paciente nao esta vinculado a voce.');
      }
    }

    const { periodo, dias } = parsePeriodo(req.query.periodo, 'mensal');
    const dados = await evolucaoService.obterEvolucao({ uidPaciente: uidAlvo, periodo, dias });

    if (uidAlvo !== req.usuario.uid) {
      const alvo = await usuarioRepo.buscarPorUid(uidAlvo);
      dados.compartilharHumor = alvo?.compartilharHumor !== false;
      dados.compartilharListaCompras = alvo?.compartilharListaCompras !== false;
    } else {
      dados.compartilharHumor = req.usuario.compartilharHumor !== false;
      dados.compartilharListaCompras = req.usuario.compartilharListaCompras !== false;
    }

    res.json({ sucesso: true, dados });
  } catch (erro) {
    next(erro);
  }
}

module.exports = { obterEvolucao };

