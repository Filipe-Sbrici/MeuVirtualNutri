/**
 * Inicializacao do Firebase Admin SDK.
 *
 * Todo o acesso ao Firestore acontece pelo Admin SDK, a partir da API
 * Node.js. As regras de seguranca do Firestore ficam fechadas para
 * clientes: o aplicativo Flutter fala com o Firebase apenas atraves
 * (a) do Firebase Authentication (SDK cliente) e (b) desta API REST.
 *
 * Duas formas de credencial, nesta ordem:
 *
 *  1. GOOGLE_APPLICATION_CREDENTIALS apontando para o arquivo JSON da
 *     conta de servico (producao e desenvolvimento local).
 *  2. FIREBASE_SERVICE_ACCOUNT (conteudo JSON em uma unica linha,
 *     comum em PaaS como Render/Railway). Se presente, e escrito em
 *     arquivo temporario e usado como credencial.
 *
 * Emuladores: quando FIRESTORE_EMULATOR_HOST e
 * FIREBASE_AUTH_EMULATOR_HOST estao definidos no .env, o Admin SDK
 * passa a falar com os emuladores locais - sem projeto real nem
 * credenciais.
 */
'use strict';

const path = require('path');
const fs = require('fs');
const config = require('./env');

function montarCredencial() {
  const admin = require('firebase-admin');

  // 1. Conteudo JSON embutido em variavel de ambiente.
  if (config.firebase.serviceAccount) {
    const conteudo = typeof config.firebase.serviceAccount === 'string'
      ? JSON.parse(config.firebase.serviceAccount)
      : config.firebase.serviceAccount;
    return admin.credential.cert(conteudo);
  }

  // 2. Arquivo serviceAccount.json na raiz do backend ou do projeto.
  const caminhosLocais = [
    path.resolve(__dirname, '../../serviceAccount.json'),
    path.resolve(__dirname, '../../../serviceAccount.json'),
  ];
  for (const caminho of caminhosLocais) {
    if (fs.existsSync(caminho)) {
      return admin.credential.cert(require(caminho));
    }
  }

  // 3. GOOGLE_APPLICATION_CREDENTIALS (caminho do arquivo) e tratado
  //    diretamente pela biblioteca.
  return undefined;
}

let app;

/** Instancia unica do Admin SDK (lazy). */
function firebaseApp() {
  if (!app) {
    const admin = require('firebase-admin');
    const credencial = montarCredencial();
    app = admin.initializeApp({
      ...(credencial ? { credential: credencial } : {}),
      projectId: config.firebase.projectId || undefined,
    });
  }
  return app;
}

/** Firestore (Admin SDK). */
function db() {
  return firebaseApp().firestore();
}

/** Firebase Authentication (Admin SDK). */
function auth() {
  return firebaseApp().auth();
}

/** Verifica se o Firestore responde (usado pelo /api/health). */
async function ping() {
  await db().collection('usuarios').limit(1).get();
  return true;
}

module.exports = { firebaseApp, db, auth, ping };
