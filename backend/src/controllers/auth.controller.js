/**
 * Controller de autenticacao/perfil.
 *
 * Com o Firebase Authentication, o login e o cadastro de credenciais
 * (e-mail/senha) acontecem DIRETO no SDK do Flutter - nao ha mais
 * endpoint de login com senha na API. O que existe aqui:
 *
 *  POST /api/auth/cadastro/paciente      -> valida corpo e cria o
 *      perfil Firestore apos o Flutter criar a conta no Firebase Auth
 *      (o uid vem do token Bearer).
 *  POST /api/auth/cadastro/nutricionista -> idem, com CRN.
 *  GET  /api/auth/perfil                 -> perfil do token Bearer.
 *
 * Um endpoint de login REST (POST /api/auth/login) e mantido em MODO
 * DEMO apenas: resolve o perfil por e-mail sem senha, para a API poder
 * ser exercitada sem emuladores. Producao o mantem desativado.
 */
'use strict';

const usuarioRepo = require('../repositories/usuario.repository');
const AppError = require('../utils/AppError');
const { parseText } = require('../utils/validators');
const config = require('../config/env');

/**
 * POST /api/auth/cadastro/paciente
 * Headers: Authorization: Bearer <token recem-criado no Firebase Auth>
 */
async function cadastrarPaciente(req, res, next) {
  try {
    const nome = parseText(req.body.nome, 'nome', 100);
    const email = parseText(req.body.email, 'email', 150).toLowerCase();

    const existente = await usuarioRepo.buscarPorEmail(email);
    if (existente) throw AppError.conflict('Este e-mail ja esta cadastrado.');

    const perfil = await usuarioRepo.criarSeNaoExistir(req.usuario.uid, {
      nome,
      email,
      telefone: parseOpcional(req.body.telefone, 20),
      tipoUsuario: 'paciente',
    });

    res.status(201).json({ sucesso: true, dados: perfilParaJson(perfil) });
  } catch (erro) {
    next(erro);
  }
}

/**
 * POST /api/auth/cadastro/nutricionista
 * O CRN e verificado por unicidade dentro da colecao de perfis.
 */
async function cadastrarNutricionista(req, res, next) {
  try {
    const nome = parseText(req.body.nome, 'nome', 100);
    const email = parseText(req.body.email, 'email', 150).toLowerCase();
    const crn = parseText(req.body.crn, 'crn', 20);
    const especializacao = parseOpcional(req.body.especializacao, 100);

    const existente = await usuarioRepo.buscarPorEmail(email);
    if (existente) throw AppError.conflict('Este e-mail ja esta cadastrado.');

    const nutricionistas = await usuarioRepo.listarNutricionistas();
    if (nutricionistas.some((n) => n.crn === crn)) {
      throw AppError.conflict('Este CRN ja esta cadastrado.');
    }

    const perfil = await usuarioRepo.criarSeNaoExistir(req.usuario.uid, {
      nome,
      email,
      telefone: parseOpcional(req.body.telefone, 20),
      tipoUsuario: 'nutricionista',
      crn,
      especializacao,
    });

    res.status(201).json({ sucesso: true, dados: perfilParaJson(perfil) });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/auth/perfil - dados da sessao atual. */
async function obterPerfil(req, res, next) {
  try {
    res.json({ sucesso: true, dados: perfilParaJson(req.usuario) });
  } catch (erro) {
    next(erro);
  }
}

/** Login de demonstracao (sem senha) - apenas FIREBASE_DEMO_MODE. */
async function loginDemo(req, res, next) {
  try {
    if (!config.firebase.modoDemo) {
      throw AppError.notFound('Use o Firebase Authentication para entrar.');
    }
    const email = parseText(req.body.email, 'email', 150).toLowerCase();
    const perfil = await usuarioRepo.buscarPorEmail(email);
    if (!perfil) throw AppError.unauthorized('E-mail nao cadastrado.');

    res.json({ sucesso: true, dados: perfilParaJson(perfil) });
  } catch (erro) {
    next(erro);
  }
}

function perfilParaJson(perfil) {
  return {
    idUsuario: perfil.uid,
    uid: perfil.uid,
    idPaciente: perfil.tipoUsuario === 'paciente' ? perfil.uid : null,
    idNutricionista:
      perfil.tipoUsuario === 'nutricionista'
        ? perfil.uid
        : perfil.idNutricionista || null,
    crn: perfil.crn ?? null,
    nome: perfil.nome,
    email: perfil.email,
    telefone: perfil.telefone,
    tipoUsuario: perfil.tipoUsuario,
    onboardingCompleto: perfil.onboardingCompleto,
    tutorialVisto: perfil.tutorialVisto,
    especializacao: perfil.especializacao ?? null,
    // Dados clinicos: alimentam a tela de Perfil (4.5.19, com IMC e
    // restricoes) e o preenchimento do onboarding retomado.
    idade: perfil.idade ?? null,
    pesoAtual: perfil.pesoAtual ?? null,
    pesoMeta: perfil.pesoMeta ?? null,
    altura: perfil.altura ?? null,
    genero: perfil.genero ?? null,
    meta: perfil.meta ?? null,
    nivelAtividade: perfil.nivelAtividade ?? null,
    tipoDieta: perfil.tipoDieta ?? null,
    alimentosFavoritos: perfil.alimentosFavoritos ?? [],
    alimentosRejeitados: perfil.alimentosRejeitados ?? [],
    restricoes: perfil.restricoes ?? [],
    condicoesMedicas: perfil.condicoesMedicas ?? [],
  };
}

function parseOpcional(valor, maxLength) {
  if (valor === undefined || valor === null) return null;
  return parseText(valor, 'valor', maxLength);
}

module.exports = { cadastrarPaciente, cadastrarNutricionista, obterPerfil, loginDemo };
