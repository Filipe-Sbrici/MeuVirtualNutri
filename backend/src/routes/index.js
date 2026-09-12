/**
 * Agregador de rotas da API.
 * Todas as rotas ficam sob o prefixo /api.
 */
'use strict';

const { Router } = require('express');
const firebase = require('../config/firebase');

const authRoutes = require('./auth.routes');
const perfilRoutes = require('./perfil.routes');
const chatRoutes = require('./chat.routes');
const progressoRoutes = require('./progresso.routes');
const evolucaoRoutes = require('./evolucao.routes');
const cardapioRoutes = require('./cardapio.routes');
const nutricionistaRoutes = require('./nutricionista.routes');
const agendaRoutes = require('./agenda.routes');

const router = Router();

/** Verificacao de saude da API e da conexao com o Firestore. */
router.get('/health', async (req, res, next) => {
  try {
    await firebase.ping();
    res.json({ sucesso: true, api: 'ok', banco: 'firestore ok' });
  } catch (erro) {
    next(erro);
  }
});

/** Indice das rotas disponiveis (util durante o desenvolvimento). */
router.get('/', (req, res) => {
  res.json({
    sucesso: true,
    api: 'Meu Virtual Nutri - API REST (Firebase/Firestore)',
    versao: '2.0.0',
    autenticacao: 'Authorization: Bearer <firebase-id-token>',
    rotas: {
      health: 'GET /api/health',
      // Autenticacao/perfil
      perfilSessao: 'GET /api/auth/perfil',
      cadastroPaciente: 'POST /api/auth/cadastro/paciente',
      cadastroNutricionista: 'POST /api/auth/cadastro/nutricionista',
      // Onboarding
      nutricionistas: 'GET /api/onboarding/nutricionistas',
      onboardingDados: 'POST /api/onboarding/dados-pessoais|estilo-vida|perfil-alimentar|restricoes|tutorial',
      // Chat
      chatConversa: 'GET /api/chat/conversa/:uidContato?depoisDoId=',
      chatEnviar: 'POST /api/chat/mensagens',
      chatContato: 'GET /api/chat/contato',
      chatNaoLidas: 'GET /api/chat/nao-lidas',
      // Progresso
      progresso: 'GET /api/progresso',
      progressoRegistrar: 'POST /api/progresso/peso',
      progressoRemover: 'DELETE /api/progresso/peso/:dataRegistro',
      agua: 'POST /api/progresso/agua',
      humor: 'POST /api/progresso/humor',
      // Evolucao
      evolucao: 'GET /api/evolucao/:uidPaciente?periodo=semanal|mensal',
      // Cardapio
      cardapioHoje: 'GET /api/cardapio/hoje',
      cardapioSemanal: 'GET /api/cardapio/semanal',
      cardapioCheck: 'POST /api/cardapio/hoje/check',
      listaCompras: 'GET /api/cardapio/lista-compras',
      // Nutricionista
      pacientes: 'GET|POST /api/nutricionista/pacientes',
      planoEdicao: 'GET|PUT /api/nutricionista/pacientes/:uid/plano',
      planoRefeicoes: 'POST|DELETE /api/nutricionista/pacientes/:uid/plano/refeicoes',
      receitas: 'GET|POST /api/nutricionista/receitas',
      receitasPendentes: 'GET /api/nutricionista/receitas/pendentes',
      avaliarReceita: 'POST /api/nutricionista/receitas/:id/avaliar',
      alimentos: 'GET /api/nutricionista/alimentos',
      relatorios: 'GET /api/nutricionista/relatorios',
      orientacoes: 'POST /api/nutricionista/orientacoes',
      // Agenda / paciente
      consultas: 'GET|POST /api/consultas',
      consultaConfirmar: 'POST /api/consultas/:id/confirmar|concluir|cancelar',
      minhasReceitas: 'GET|POST /api/minhas-receitas',
      minhasOrientacoes: 'GET /api/orientacoes',
      alimentos: 'GET /api/alimentos',
    },
  });
});

router.use('/auth', authRoutes);
router.use('/onboarding', perfilRoutes);
router.use('/perfil', perfilRoutes);
router.use('/chat', chatRoutes);
router.use('/progresso', progressoRoutes);
router.use('/evolucao', evolucaoRoutes);
router.use('/cardapio', cardapioRoutes);
router.use('/nutricionista', nutricionistaRoutes);
router.use('/', agendaRoutes);

module.exports = router;
