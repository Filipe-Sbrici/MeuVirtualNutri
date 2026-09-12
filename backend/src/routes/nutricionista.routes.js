/**
 * Rotas do nutricionista: pacientes, editor de cardapio, receitas,
 * agenda, orientacoes e relatorios. Todas exigem perfil de
 * nutricionista (exceto consulta de alimentos/agenda de consultas
 * do paciente, que ficam em suas proprias rotas).
 */
'use strict';

const { Router } = require('express');
const nutricionistaController = require('../controllers/nutricionista.controller');
const relatoriosController = require('../controllers/relatorios.controller');
const consultaController = require('../controllers/consulta.controller');
const { autenticar, exigirNutricionista } = require('../middlewares/auth');

const router = Router();

router.use(autenticar, exigirNutricionista);

// Pacientes e Solicitacoes
router.get('/pacientes', nutricionistaController.listarPacientes);
router.post('/pacientes', nutricionistaController.vincularPaciente);
router.get('/pacientes/:uid/lista-compras', nutricionistaController.obterListaComprasPaciente);
router.get('/solicitacoes', nutricionistaController.listarSolicitacoes);
router.post('/solicitacoes/:uid/aceitar', nutricionistaController.aceitarSolicitacao);
router.post('/solicitacoes/:uid/recusar', nutricionistaController.recusarSolicitacao);


// Editor de cardapio (wizard 3 passos)
router.get('/pacientes/:uid/plano', nutricionistaController.obterPlanoParaEdicao);
router.put('/pacientes/:uid/plano', nutricionistaController.atualizarPlano);
router.post('/pacientes/:uid/plano/refeicoes', nutricionistaController.definirRefeicao);
router.delete(
  '/pacientes/:uid/plano/refeicoes',
  nutricionistaController.removerRefeicao,
);

// Biblioteca de receitas
router.get('/receitas', nutricionistaController.listarReceitas);
router.post('/receitas', nutricionistaController.salvarReceita);
router.get('/receitas/pendentes', nutricionistaController.listarReceitasPendentes);
router.post('/receitas/:id/avaliar', nutricionistaController.avaliarReceita);

// Base de alimentos
router.get('/alimentos', nutricionistaController.listarAlimentos);

// Relatorios e analise (4.5.27)
router.get('/relatorios', relatoriosController.obterRelatorios);

// Orientacoes (feedbacks)
router.post('/orientacoes', consultaController.enviarOrientacao);

module.exports = router;
