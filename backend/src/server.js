/**
 * Ponto de entrada da API.
 *
 * Escuta em 0.0.0.0 para que o aplicativo Flutter possa acessar o
 * servidor a partir do emulador Android ou de um dispositivo fisico
 * na mesma rede.
 */
'use strict';

const app = require('./app');
const config = require('./config/env');
const firebase = require('./config/firebase');

const servidor = app.listen(config.port, '0.0.0.0', async () => {
  /* eslint-disable no-console */
  console.log('-------------------------------------------------------');
  console.log('  Meu Virtual Nutri - API REST (Firebase/Firestore)');
  console.log(`  Porta ....... ${config.port}`);
  console.log(`  Projeto ..... ${config.firebase.projectId || '(padrao do SDK)'}`);
  console.log(`  Rotas ....... http://localhost:${config.port}/api`);
  console.log('-------------------------------------------------------');

  try {
    await firebase.ping();
    console.log('  Firestore conectado com sucesso.');
  } catch (erro) {
    console.error('  ATENCAO: nao foi possivel conectar ao Firestore.');
    console.error(`  ${erro.code || ''} ${erro.message}`);
    console.error('  Verifique FIREBASE_SERVICE_ACCOUNT / GOOGLE_APPLICATION_CREDENTIALS');
    console.error('  ou defina FIRESTORE_EMULATOR_HOST para usar o emulador.');
  }
  /* eslint-enable no-console */
});

/** Encerramento limpo. */
process.on('SIGINT', () => {
  // eslint-disable-next-line no-console
  console.log('\nRecebido SIGINT, encerrando...');
  servidor.close(() => process.exit(0));
});
process.on('SIGTERM', () => {
  // eslint-disable-next-line no-console
  console.log('\nRecebido SIGTERM, encerrando...');
  servidor.close(() => process.exit(0));
});
