/**
 * Carregamento e validacao das variaveis de ambiente.
 * Centraliza toda a configuracao para que nenhum outro modulo
 * precise ler `process.env` diretamente.
 */
'use strict';

require('dotenv').config();

const toInt = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
};

const config = {
  port: toInt(process.env.PORT, 3000),
  corsOrigin: process.env.CORS_ORIGIN || '*',

  firebase: {
    // ID do projeto Firebase (ex.: meu-virtual-nutri).
    projectId: process.env.FIREBASE_PROJECT_ID || '',

    // Alternativa a GOOGLE_APPLICATION_CREDENTIALS: conteudo JSON da
    // conta de servico em uma unica linha (sem quebras).
    serviceAccount: process.env.FIREBASE_SERVICE_ACCOUNT || '',

    // Modo demonstracao: quando "true", a API cria um token de teste
    // fixo caso nenhum Bearer token chegue na requisicao. Util apenas
    // para provar os endpoints sem emulador/credenciais.
    modoDemo: (process.env.FIREBASE_DEMO_MODE || '') === 'true',
  },
};

module.exports = config;
