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

const toFloat = (value, fallback) => {
  const parsed = Number.parseFloat(value);
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
    // Forcado a false em ambiente de producao por seguranca.
    modoDemo:
      process.env.NODE_ENV !== 'production' &&
      (process.env.FIREBASE_DEMO_MODE || '') === 'true',

    // Exige que o e-mail do Firebase Auth esteja verificado (email_verified = true)
    // para acessar as rotas autenticadas da API em producao.
    exigirEmailVerificado:
      (process.env.FIREBASE_REQUIRE_EMAIL_VERIFIED || '') === 'true',
  },

  mercadoPago: {
    // Access Token do Mercado Pago (TEST-... em sandbox ou APP_USR-... em producao).
    // Quando vazio, o servico opera em modo de simulacao integrado ao Firestore.
    accessToken: (process.env.MP_ACCESS_TOKEN || '').trim(),
    publicKey: (process.env.MP_PUBLIC_KEY || '').trim(),
    webhookSecret: (process.env.MP_WEBHOOK_SECRET || '').trim(),
    backUrl:
      (process.env.MP_BACK_URL || '').trim() ||
      'https://meuvirtualnutri.app/assinatura-retorno',
    precoMensal: toFloat(process.env.ASSINATURA_PRECO_MENSAL, 29.9),
    limitePacientesGratuito: toInt(process.env.LIMITE_PACIENTES_GRATUITO, 15),
  },
};

module.exports = config;
