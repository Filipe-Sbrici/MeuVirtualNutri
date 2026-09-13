/**
 * Configuracao da aplicacao Express.
 * Separado de server.js para permitir testes sem abrir a porta.
 */
'use strict';

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const config = require('./config/env');
const routes = require('./routes');
const { notFoundHandler, errorHandler } = require('./middlewares/errorHandler');

const app = express();

// CORS: aceita lista separada por virgula ou "*".
cons origem =
  config.corsOrigin === '*'
    ? '*'
    : config.corsOrigin.split(',').map((item) => item.trim());
app.use(cors({ origin: origem }));

// Corpo das requisicoes em JSON.
app.use(express.json({ limit: '1mb' }));

// Log de requisicoes no console.
app.use(morgan('dev'));

// Rotas da API.
app.use('/api', routes);

// Raiz: aponta para a documentacao das rotas.
app.get('/', (req, res) => {
  res.json({
    sucesso: true,
    mensagem: 'API do Meu Virtual Nutri. Consulte GET /api para as rotas.',
  });
});

// 404 e tratamento de erros (sempre por ultimo).
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
