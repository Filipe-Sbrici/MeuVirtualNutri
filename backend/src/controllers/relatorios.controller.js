/**
 * Controller de relatorios e analise do nutricionista (tela 4.5.27).
 *
 * Agrega por paciente: evolucao de peso, aderencia media ao cardapio e
 * frequencia de registros nos ultimos 30 dias.
 */
'use strict';

const usuarioRepo = require('../repositories/usuario.repository');
const progressoRepo = require('../repositories/progresso.repository');
const planoRepo = require('../repositories/plano.repository');
const { round } = require('../utils/validators');

/** GET /api/nutricionista/relatorios */
async function obterRelatorios(req, res, next) {
  try {
    const pacientes = await usuarioRepo.listarPacientesDoNutricionista(req.usuario.uid);

    const relatorios = await Promise.all(
      pacientes.map(async (p) => {
        const [serie, medias] = await Promise.all([
          progressoRepo.listarSeriePeso(p.uid, 30),
          progressoRepo.buscarMediasPeriodo(p.uid, 30),
        ]);
        const pesos = serie.map((r) => Number(r.peso));
        const plano = await planoRepo.buscarPlanoAtivo(p.uid);

        return {
          uid: p.uid,
          nome: p.nome,
          objetivo: p.meta,
          nomePlano: plano?.nomePlano ?? null,
          evolucaoPeso: {
            pontos: serie.map((r) => ({ data: r.dataRegistro, peso: round(r.peso, 1) })),
            variacao30d: pesos.length >= 2 ? round(pesos[0] - pesos[pesos.length - 1], 1) : 0,
          },
          aderenciaMedia: medias?.aderenciaMedia !== null && medias?.aderenciaMedia !== undefined
            ? round(medias.aderenciaMedia, 1)
            : null,
          frequenciaRegistros: medias?.totalRegistros ?? 0,
        };
      }),
    );

    res.json({ sucesso: true, dados: { relatorios } });
  } catch (erro) {
    next(erro);
  }
}

module.exports = { obterRelatorios };
