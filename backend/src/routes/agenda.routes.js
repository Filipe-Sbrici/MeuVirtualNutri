/**
 * Rotas de consultas (agenda) e receitas do paciente.
 * Agenda: nutricionista abre horarios; paciente confirma (4.5.26).
 * Minhas Receitas: paciente envia receita para aprovacao (4.5.18).
 */
'use strict';

const { Router } = require('express');
const consultaController = require('../controllers/consulta.controller');
const cardapioService = require('../services/cardapio.service');
const { autenticar, exigirNutricionista } = require('../middlewares/auth');

const router = Router();

// Agenda: listagem, historico e acoes.
router.get('/consultas', autenticar, consultaController.listar);
router.get('/consultas/historico', autenticar, consultaController.listarHistorico);
router.post('/consultas', autenticar, exigirNutricionista, consultaController.criar);
router.put('/consultas/:id', autenticar, exigirNutricionista, consultaController.editar);
router.post('/consultas/lote', autenticar, exigirNutricionista, consultaController.criarLote);
router.post('/consultas/:id/solicitar', autenticar, consultaController.solicitar);
router.post('/consultas/:id/aprovar', autenticar, exigirNutricionista, consultaController.aprovar);
router.post('/consultas/:id/recusar', autenticar, exigirNutricionista, consultaController.recusar);
router.post('/consultas/:id/confirmar', autenticar, consultaController.confirmar);
router.post('/consultas/:id/concluir', autenticar, exigirNutricionista, consultaController.concluir);
router.post('/consultas/:id/cancelar', autenticar, consultaController.cancelar);

// Orientacoes destinadas ao paciente logado.
router.get('/orientacoes', autenticar, consultaController.listarOrientacoes);
router.post('/orientacoes/:id/confirmar', autenticar, consultaController.confirmarOrientacao);


// Minhas Receitas do paciente (envio + listagem).
router.get('/minhas-receitas', autenticar, async (req, res, next) => {
  try {
    const receitas = await cardapioService.minhasReceitas(req.usuario.uid);
    res.json({ sucesso: true, dados: { receitas } });
  } catch (erro) {
    next(erro);
  }
});

router.post('/minhas-receitas', autenticar, async (req, res, next) => {
  try {
    const receita = await cardapioService.compartilharReceita({
      uidPaciente: req.usuario.uid,
      dados: req.body,
    });
    res.status(201).json({ sucesso: true, dados: receita });
  } catch (erro) {
    next(erro);
  }
});

// Base de alimentos: catalogo publico (mesmos dados de
// /api/nutricionista/alimentos) que o paciente tambem precisa para
// montar a receita que vai compartilhar com os macros corretos.
router.get('/alimentos', autenticar, async (_req, res, next) => {
  try {
    const alimentos = await cardapioService.listarAlimentos();
    res.json({ sucesso: true, dados: { alimentos } });
  } catch (erro) {
    next(erro);
  }
});

module.exports = router;
