/**
 * Controller da agenda de consultas e das orientacoes/feedbacks.
 *
 * Consultas (4.5.26): nutricionista abre horarios; paciente solicita; nutricionista aprova/recusa.
 * Orientacoes (4.5.15 aba Orientacoes): feedbacks classificados em
 * positivo | neutro | melhoria + confirmação pelo paciente.
 */
'use strict';

const consultaRepo = require('../repositories/consulta.repository');
const orientacaoRepo = require('../repositories/orientacao.repository');
const usuarioRepo = require('../repositories/usuario.repository');
const AppError = require('../utils/AppError');
const { parseText } = require('../utils/validators');

/** GET /api/consultas - agenda do usuario logado. */
async function listar(req, res, next) {
  try {
    const uidNutricionistaLivres =
      req.usuario.tipoUsuario === 'paciente'
        ? req.usuario.idNutricionista || null
        : null;

    const consultas = await consultaRepo.listarDoUsuario(req.usuario.uid, {
      uidNutricionistaLivres,
    });

    const formatadas = await Promise.all(consultas.map(formatar));
    res.json({
      sucesso: true,
      dados: {
        consultas: formatadas,
      },
    });
  } catch (erro) {
    next(erro);
  }
}

/** GET /api/consultas/historico - histórico de consultas concluídas/comparecidas. */
async function listarHistorico(req, res, next) {
  try {
    const consultas = await consultaRepo.listarHistorico(req.usuario.uid);
    const formatadas = await Promise.all(consultas.map(formatar));
    res.json({
      sucesso: true,
      dados: {
        consultas: formatadas,
      },
    });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/consultas { dataHora, observacoes } - nutricionista abre horario. */
async function criar(req, res, next) {
  try {
    const dataHora = new Date(req.body.dataHora || '');
    if (Number.isNaN(dataHora.getTime())) {
      throw AppError.badRequest('Informe dataHora valida (ISO-8601).');
    }
    if (dataHora.getTime() <= Date.now()) {
      throw AppError.badRequest('Informe um horario futuro para a consulta.');
    }
    const criada = await consultaRepo.criar({
      uidNutricionista: req.usuario.uid,
      dataHora,
      observacoes: String(req.body.observacoes || '').slice(0, 500),
    });
    res.status(201).json({ sucesso: true, dados: criada });
  } catch (erro) {
    next(erro);
  }
}

/** PUT /api/consultas/:id { dataHora, observacoes } - nutricionista edita consulta. */
async function editar(req, res, next) {
  try {
    const { id, consulta } = await carregarConsulta(req);
    if (consulta.uidNutricionista !== req.usuario.uid) {
      throw AppError.forbidden('Esta consulta nao e sua.');
    }

    let dataHoraNova = undefined;
    if (req.body.dataHora) {
      const parsed = new Date(req.body.dataHora);
      if (Number.isNaN(parsed.getTime())) {
        throw AppError.badRequest('Informe dataHora valida (ISO-8601).');
      }
      dataHoraNova = parsed;
    }

    await consultaRepo.atualizar(id, {
      dataHora: dataHoraNova,
      observacoes: req.body.observacoes !== undefined ? String(req.body.observacoes).slice(0, 500) : undefined,
    });

    const atualizada = await consultaRepo.buscarPorId(id);
    res.json({ sucesso: true, dados: await formatar(atualizada) });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/consultas/lote { horarios: [dataHora1, ...], observacoes } */
async function criarLote(req, res, next) {
  try {
    const lista = Array.isArray(req.body.horarios) ? req.body.horarios : [];
    if (lista.length === 0) throw AppError.badRequest('Informe ao menos um horario.');
    const criadas = [];
    for (const item of lista) {
      const dataHora = new Date(item);
      if (!Number.isNaN(dataHora.getTime()) && dataHora.getTime() > Date.now()) {
        const c = await consultaRepo.criar({
          uidNutricionista: req.usuario.uid,
          dataHora,
          observacoes: String(req.body.observacoes || '').slice(0, 500),
        });
        criadas.push(c);
      }
    }
    res.status(201).json({ sucesso: true, dados: { totalCriados: criadas.length, consultas: criadas } });
  } catch (erro) {
    next(erro);
  }
}

/** Carrega a consulta pelo id da rota ou lanca 404. */
async function carregarConsulta(req) {
  const id = String(req.params.id || '').trim();
  if (!id) throw AppError.badRequest('Informe a consulta.');
  const consulta = await consultaRepo.buscarPorId(id);
  if (!consulta) throw AppError.notFound('Consulta nao encontrada.');
  return { id, consulta };
}

/** POST /api/consultas/:id/solicitar - paciente solicita agendamento em horário vago (status -> pendente). */
async function solicitar(req, res, next) {
  try {
    if (req.usuario.tipoUsuario !== 'paciente') {
      throw AppError.forbidden('Apenas o paciente pode solicitar agendamento.');
    }
    const { id, consulta } = await carregarConsulta(req);

    if (consulta.status !== 'disponivel') {
      throw AppError.conflict('Consulta nao esta disponivel para agendamento.');
    }
    if (consulta.uidNutricionista !== req.usuario.idNutricionista) {
      throw AppError.forbidden('Este horario e de outro nutricionista.');
    }

    await consultaRepo.solicitar(id, req.usuario.uid);
    res.json({ sucesso: true, dados: { idConsulta: id, status: 'pendente' } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/consultas/:id/aprovar - nutricionista aprova pedido pendente (status -> confirmada). */
async function aprovar(req, res, next) {
  try {
    const { id, consulta } = await carregarConsulta(req);
    if (consulta.uidNutricionista !== req.usuario.uid) {
      throw AppError.forbidden('Esta consulta nao e sua.');
    }
    if (consulta.status !== 'pendente') {
      throw AppError.badRequest('Apenas consultas com status pendente podem ser aprovadas.');
    }

    await consultaRepo.aprovar(id);
    res.json({ sucesso: true, dados: { idConsulta: id, status: 'confirmada' } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/consultas/:id/recusar - nutricionista recusa pedido pendente (volta para disponivel). */
async function recusar(req, res, next) {
  try {
    const { id, consulta } = await carregarConsulta(req);
    if (consulta.uidNutricionista !== req.usuario.uid) {
      throw AppError.forbidden('Esta consulta nao e sua.');
    }
    if (consulta.status !== 'pendente') {
      throw AppError.badRequest('Apenas consultas com status pendente podem ser recusadas.');
    }

    await consultaRepo.recusar(id);
    res.json({ sucesso: true, dados: { idConsulta: id, status: 'disponivel' } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/consultas/:id/confirmar - paciente confirma horario livre diretamente (compatibilidade). */
async function confirmar(req, res, next) {
  try {
    if (req.usuario.tipoUsuario !== 'paciente') {
      throw AppError.forbidden('Apenas o paciente confirma um horario.');
    }
    const { id, consulta } = await carregarConsulta(req);

    if (consulta.status !== 'disponivel') {
      throw AppError.conflict('Consulta nao esta disponivel para confirmacao.');
    }
    if (consulta.uidNutricionista !== req.usuario.idNutricionista) {
      throw AppError.forbidden('Este horario e de outro nutricionista.');
    }

    await consultaRepo.confirmar(id, req.usuario.uid);
    res.json({ sucesso: true, dados: { idConsulta: id, status: 'confirmada' } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/consultas/:id/concluir - nutricionista encerra com presença do cliente. */
async function concluir(req, res, next) {
  try {
    const { id, consulta } = await carregarConsulta(req);
    if (consulta.uidNutricionista !== req.usuario.uid) {
      throw AppError.forbidden('Esta consulta nao e sua.');
    }
    await consultaRepo.atualizarStatus(id, 'concluida');
    res.json({ sucesso: true, dados: { idConsulta: id, status: 'concluida' } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/consultas/:id/cancelar - nutricionista dono ou paciente agendado. */
async function cancelar(req, res, next) {
  try {
    const { id, consulta } = await carregarConsulta(req);
    const participa =
      consulta.uidNutricionista === req.usuario.uid ||
      consulta.uidPaciente === req.usuario.uid;
    if (!participa) {
      throw AppError.forbidden('Esta consulta nao e sua.');
    }
    await consultaRepo.atualizarStatus(id, 'cancelada');
    res.json({ sucesso: true, dados: { idConsulta: id, status: 'cancelada' } });
  } catch (erro) {
    next(erro);
  }
}

async function formatar(consulta) {
  let nomePaciente = null;
  let nomeNutricionista = null;

  if (consulta.uidPaciente) {
    const paciente = await usuarioRepo.buscarResumo(consulta.uidPaciente);
    if (paciente) nomePaciente = paciente.nome;
  }
  if (consulta.uidNutricionista) {
    const nutri = await usuarioRepo.buscarResumo(consulta.uidNutricionista);
    if (nutri) nomeNutricionista = nutri.nome;
  }

  return {
    idConsulta: consulta.idConsulta,
    uidNutricionista: consulta.uidNutricionista,
    nomeNutricionista,
    uidPaciente: consulta.uidPaciente ?? null,
    nomePaciente,
    dataHora: consulta.dataHora?.toDate?.().toISOString() ?? null,
    status: consulta.status,
    observacoes: consulta.observacoes || '',
  };
}

// =====================================================================
//  ORIENTACOES
// =====================================================================

/** GET /api/orientacoes - orientacoes destinadas ao paciente logado. */
async function listarOrientacoes(req, res, next) {
  try {
    const orientacoes = await orientacaoRepo.listarDoPaciente(req.usuario.uid);
    res.json({
      sucesso: true,
      dados: {
        orientacoes: orientacoes.map((o) => ({
          idOrientacao: o.idOrientacao,
          categoria: o.categoria,
          texto: o.texto,
          lida: o.lida === true,
          confirmada: o.confirmada === true,
          confirmadaEm: o.confirmadaEm?.toDate?.().toISOString() ?? null,
          criadoEm: o.criadoEm?.toDate?.().toISOString() ?? null,
        })),
      },
    });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/orientacoes/:id/confirmar - paciente confirma/marca como ciente. */
async function confirmarOrientacao(req, res, next) {
  try {
    const idOrientacao = String(req.params.id || '').trim();
    if (!idOrientacao) throw AppError.badRequest('Informe a orientacao.');

    const ok = await orientacaoRepo.confirmar(idOrientacao, req.usuario.uid);
    if (!ok) {
      throw AppError.notFound('Orientacao nao encontrada ou nao pertence a voce.');
    }
    res.json({ sucesso: true, dados: { idOrientacao, confirmada: true } });
  } catch (erro) {
    next(erro);
  }
}

/** POST /api/orientacoes { uidPaciente, categoria, texto }. */
async function enviarOrientacao(req, res, next) {
  try {
    const uidPaciente = String(req.body.uidPaciente || '').trim();
    const texto = parseText(req.body.texto, 'texto', 1000);
    const categoria = String(req.body.categoria || 'neutro').trim();

    const paciente = await usuarioRepo.buscarPorUid(uidPaciente);
    if (!paciente || paciente.tipoUsuario !== 'paciente') {
      throw AppError.notFound('Paciente nao encontrado.');
    }
    if (paciente.idNutricionista !== req.usuario.uid) {
      throw AppError.forbidden('Paciente nao esta vinculado a voce.');
    }

    const criada = await orientacaoRepo.criar({
      uidNutricionista: req.usuario.uid,
      uidPaciente,
      categoria,
      texto,
    });
    res.status(201).json({ sucesso: true, dados: criada });
  } catch (erro) {
    next(erro);
  }
}

module.exports = {
  listar,
  listarHistorico,
  criar,
  editar,
  criarLote,
  solicitar,
  aprovar,
  recusar,
  confirmar,
  concluir,
  cancelar,
  listarOrientacoes,
  confirmarOrientacao,
  enviarOrientacao,
};

