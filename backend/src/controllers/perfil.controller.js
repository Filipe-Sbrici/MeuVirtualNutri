/**
 * Controller do perfil do paciente e do onboarding.
 *
 * Onboarding do prototipo (telas 4.5.5 a 4.5.10):
 *   1. Escolher nutricionista
 *   2. Dados pessoais (nome, idade, sexo, peso, altura)
 *   3. Nivel de atividade + objetivo
 *   4. Perfil alimentar (tipo de dieta, favoritos, rejeitados)
 *   5. Restricoes e condicoes medicas
 *   6. Tutorial interativo
 *
 * Cada etapa grava campos no mesmo documento usuarios/{uid}, o que
 * permite retomar o onboarding de onde parou.
 */
'use strict';

const usuarioRepo = require('../repositories/usuario.repository');
const AppError = require('../utils/AppError');
const { parseNumber } = require('../utils/validators');

/** GET /api/onboarding/nutricionistas - lista para a etapa 1. */
async function listarNutricionistas(req, res, next) {
  try {
    const lista = await usuarioRepo.listarNutricionistas();
    res.json({ sucesso: true, dados: { nutricionistas: lista } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/onboarding/nutricionista - etapa 1: vinculo. */
async function escolherNutricionista(req, res, next) {
  try {
    const uidNutricionista = String(req.body.uidNutricionista || '').trim();
    if (!uidNutricionista) {
      throw AppError.badRequest('Informe o nutricionista escolhido.');
    }
    const nutri = await usuarioRepo.buscarPorUid(uidNutricionista);
    if (!nutri || nutri.tipoUsuario !== 'nutricionista') {
      throw AppError.notFound('Nutricionista nao encontrado.');
    }

    await usuarioRepo.vincularNutricionista(req.usuario.uid, uidNutricionista);
    res.json({ sucesso: true, dados: { idNutricionista: uidNutricionista } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/onboarding/dados-pessoais - etapa 2. */
async function salvarDadosPessoais(req, res, next) {
  try {
    const idade = parseNumber(req.body.idade, 'idade', { min: 10, max: 120 });
    const pesoAtual = parseNumber(req.body.pesoAtual, 'pesoAtual', { min: 20, max: 400 });
    const altura = parseNumber(req.body.altura, 'altura', { min: 0.9, max: 2.5 });
    const genero = String(req.body.genero || '').trim();
    const meta = String(req.body.meta || '').trim();
    const pesoMeta = req.body.pesoMeta != null
      ? parseNumber(req.body.pesoMeta, 'pesoMeta', { min: 20, max: 400 })
      : null;

    if (!genero) throw AppError.badRequest('Informe o genero.');

    const perfil = await usuarioRepo.atualizar(req.usuario.uid, {
      idade: Math.round(idade),
      pesoAtual: arredondar(pesoAtual),
      altura: arredondar(altura, 2),
      genero,
      ...(meta && { meta }),
      ...(pesoMeta !== null && { pesoMeta: arredondar(pesoMeta) }),
    });
    res.json({ sucesso: true, dados: { perfil } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/onboarding/estilo-vida - etapa 3 (atividade + objetivo). */
async function salvarEstiloVida(req, res, next) {
  try {
    const nivelAtividade = String(req.body.nivelAtividade || '').trim();
    const meta = String(req.body.meta || '').trim();

    if (!nivelAtividade) throw AppError.badRequest('Informe o nivel de atividade.');
    if (!meta) throw AppError.badRequest('Informe o objetivo nutricional.');

    const perfil = await usuarioRepo.atualizar(req.usuario.uid, {
      nivelAtividade,
      meta,
    });
    res.json({ sucesso: true, dados: { perfil } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/onboarding/perfil-alimentar - etapa 4 (dieta + listas). */
async function salvarPerfilAlimentar(req, res, next) {
  try {
    const tipoDieta = String(req.body.tipoDieta || '').trim();
    if (!tipoDieta) throw AppError.badRequest('Informe o tipo de dieta.');

    const perfil = await usuarioRepo.atualizar(req.usuario.uid, {
      tipoDieta,
      alimentosFavoritos: listaDeStrings(req.body.alimentosFavoritos, 50),
      alimentosRejeitados: listaDeStrings(req.body.alimentosRejeitados, 50),
    });
    res.json({ sucesso: true, dados: { perfil } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/onboarding/restricoes - etapa 5. */
async function salvarRestricoes(req, res, next) {
  try {
    const perfil = await usuarioRepo.atualizar(req.usuario.uid, {
      restricoes: listaDeStrings(req.body.restricoes, 50),
      condicoesMedicas: listaDeStrings(req.body.condicoesMedicas, 50),
      onboardingCompleto: true,
    });
    res.json({ sucesso: true, dados: { perfil } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/onboarding/tutorial - etapa 6: marca tutorial visto. */
async function concluirTutorial(req, res, next) {
  try {
    await usuarioRepo.atualizar(req.usuario.uid, { tutorialVisto: true });
    res.json({ sucesso: true, dados: { tutorialVisto: true } });
  } catch (erro) {
    next(erro);
  }
}

/** PUT /api/perfil - edicao livre dos dados cadastrais/clinicos. */
async function atualizarPerfil(req, res, next) {
  try {
    const campos = {};
    const b = req.body;

    if (b.nome !== undefined) campos.nome = String(b.nome).trim().slice(0, 100);
    if (b.telefone !== undefined) campos.telefone = String(b.telefone).trim().slice(0, 20) || null;
    if (b.especializacao !== undefined) campos.especializacao = String(b.especializacao).trim().slice(0, 100) || null;
    if (b.idade !== undefined) campos.idade = Math.round(parseNumber(b.idade, 'idade', { min: 10, max: 120 }));
    if (b.pesoAtual !== undefined) campos.pesoAtual = arredondar(parseNumber(b.pesoAtual, 'pesoAtual', { min: 20, max: 400 }));
    if (b.pesoMeta !== undefined) campos.pesoMeta = b.pesoMeta === null ? null : arredondar(parseNumber(b.pesoMeta, 'pesoMeta', { min: 20, max: 400 }));
    if (b.altura !== undefined) campos.altura = arredondar(parseNumber(b.altura, 'altura', { min: 0.9, max: 2.5 }), 2);
    if (b.genero !== undefined) campos.genero = String(b.genero).trim();
    if (b.meta !== undefined) campos.meta = String(b.meta).trim().slice(0, 150) || null;
    if (b.nivelAtividade !== undefined) campos.nivelAtividade = String(b.nivelAtividade).trim();
    if (b.tipoDieta !== undefined) campos.tipoDieta = String(b.tipoDieta).trim();
    if (b.compartilharListaCompras !== undefined) campos.compartilharListaCompras = b.compartilharListaCompras === true;
    if (b.compartilharHumor !== undefined) campos.compartilharHumor = b.compartilharHumor === true;
    if (b.observacoesSeguranca !== undefined) campos.observacoesSeguranca = String(b.observacoesSeguranca).trim().slice(0, 500);
    if (b.alimentosFavoritos !== undefined) campos.alimentosFavoritos = listaDeStrings(b.alimentosFavoritos, 50);
    if (b.alimentosRejeitados !== undefined) campos.alimentosRejeitados = listaDeStrings(b.alimentosRejeitados, 50);
    if (b.restricoes !== undefined) campos.restricoes = listaDeStrings(b.restricoes, 50);
    if (b.condicoesMedicas !== undefined) campos.condicoesMedicas = listaDeStrings(b.condicoesMedicas, 50);

    if (Object.keys(campos).length === 0) {
      throw AppError.badRequest('Nenhum campo para atualizar.');
    }


    const perfil = await usuarioRepo.atualizar(req.usuario.uid, campos);
    res.json({ sucesso: true, dados: { perfil } });
  } catch (erro) {
    next(erro);
  }
}

/** DELETE /api/perfil - exclusao da conta (perfil; auth e apagado pelo Flutter). */
async function excluirPerfil(req, res, next) {
  try {
    await usuarioRepo.excluir(req.usuario.uid);
    res.json({ sucesso: true, dados: { excluido: true } });
  } catch (erro) {
    next(erro);
  }
}

function arredondar(valor, casas = 1) {
  const fator = 10 ** casas;
  return Math.round(valor * fator) / fator;
}

function listaDeStrings(valor, limite) {
  if (!Array.isArray(valor)) return [];
  return valor
    .filter((item) => typeof item === 'string')
    .map((item) => item.trim().slice(0, 60))
    .filter(Boolean)
    .slice(0, limite);
}

module.exports = {
  listarNutricionistas,
  escolherNutricionista,
  salvarDadosPessoais,
  salvarEstiloVida,
  salvarPerfilAlimentar,
  salvarRestricoes,
  concluirTutorial,
  atualizarPerfil,
  excluirPerfil,
};
