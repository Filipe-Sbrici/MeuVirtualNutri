/**
 * Middleware de autenticacao via Firebase.
 *
 * Todas as rotas (exceto cadastro/login que o Flutter faz direto no
 * Firebase Auth) exigem o cabecalho:
 *
 *     Authorization: Bearer <id-token-do-firebase>
 *
 * O token e verificado com o Admin SDK; o UID resultante identifica o
 * documento `usuarios/{uid}` que fica disponivel em `req.usuario`.
 *
 * Modo demonstracao (FIREBASE_DEMO_MODE=true): sem token, a requisicao
 * e autenticada como o usuario indicado em `x-demo-email` (ou o
 * paciente de demonstracao). Existe apenas para testes da API sem
 * emuladores/credenciais e nunca deve ficar ativo em producao.
 */
'use strict';

const { auth, db } = require('../config/firebase');
const config = require('../config/env');
const AppError = require('../utils/AppError');

/** Extrai o UID a partir do cabecalho Authorization. */
async function resolverUid(req) {
  const cabecalho = req.headers.authorization || '';
  const [esquema, token] = cabecalho.split(' ');

  if (esquema && token && esquema.toLowerCase() === 'bearer') {
    try {
      const decodificado = await auth().verifyIdToken(token);
      return decodificado.uid;
    } catch {
      throw AppError.unauthorized('Sessao invalida ou expirada. Entre novamente.');
    }
  }

  if (config.firebase.modoDemo) return resolverUidDemo(req);

  return null;
}

/** Fallback do modo demonstracao: seleciona o usuario pelo e-mail. */
async function resolverUidDemo(req) {
  const email = String(req.headers['x-demo-email'] || 'ana@mvn.com').toLowerCase();
  const snap = await db()
    .collection('usuarios')
    .where('email', '==', email)
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0].id;
}

/** Carrega o perfil e anexa em req.usuario. */
async function autenticar(req, res, next) {
  try {
    const uid = await resolverUid(req);
    if (!uid) {
      throw AppError.unauthorized(
        'Autenticacao necessaria: envie o token Firebase em "Authorization: Bearer <token>".',
      );
    }

    const doc = await db().collection('usuarios').doc(uid).get();
    if (!doc.exists) {
      throw AppError.unauthorized('Usuario autenticado sem perfil na aplicacao.');
    }

    req.usuario = { uid, ...doc.data() };
    next();
  } catch (erro) {
    next(erro instanceof AppError ? erro : AppError.unauthorized('Nao autenticado.'));
  }
}

/**
 * Verifica apenas o token (sem exigir perfil no Firestore).
 * Usado nas rotas de CADASTRO, que sao justamente as que criam o
 * perfil apos o Flutter criar a conta no Firebase Authentication.
 */
async function autenticarToken(req, res, next) {
  try {
    const cabecalho = req.headers.authorization || '';
    const [esquema, token] = cabecalho.split(' ');

    if (!esquema || !token || esquema.toLowerCase() !== 'bearer') {
      throw AppError.unauthorized(
        'Autenticacao necessaria: envie o token Firebase em "Authorization: Bearer <token>".',
      );
    }

    let decodificado;
    try {
      decodificado = await auth().verifyIdToken(token);
    } catch {
      throw AppError.unauthorized('Sessao invalida ou expirada. Entre novamente.');
    }

    req.usuario = {
      uid: decodificado.uid,
      email: decodificado.email || '',
      nome: decodificado.name || '',
    };
    next();
  } catch (erro) {
    next(erro instanceof AppError ? erro : AppError.unauthorized('Nao autenticado.'));
  }
}

/** Bloqueia a rota para perfis que nao sejam paciente. */
function exigirPaciente(req, _res, next) {
  if (req.usuario?.tipoUsuario !== 'paciente') {
    return next(AppError.forbidden('Acao exclusiva de pacientes.'));
  }
  next();
}

/** Bloqueia a rota para perfis que nao sejam nutricionista. */
function exigirNutricionista(req, _res, next) {
  if (req.usuario?.tipoUsuario !== 'nutricionista') {
    return next(AppError.forbidden('Acao exclusiva de nutricionistas.'));
  }
  next();
}

module.exports = { autenticar, autenticarToken, exigirPaciente, exigirNutricionista };
