/**
 * Servico de Assinatura do Nutricionista integrado ao Mercado Pago e Firestore.
 *
 * Regras de negocio:
 *  - Plano Gratuito (padrao): limite de ate 15 pacientes ativos vinculados.
 *  - Plano Pro (assinante): R$ 29,90/mes com pacientes ilimitados.
 *  - Quando `MP_ACCESS_TOKEN` esta configurado no `.env`, utiliza a API oficial
 *    de Assinaturas do Mercado Pago (`https://api.mercadopago.com/preapproval`),
 *    vinculando o `uid` do Firebase no campo `external_reference`.
 *  - Quando `MP_ACCESS_TOKEN` nao esta configurado (ambiente de desenvolvimento,
 *    testes ou demonstracao), opera em modo Sandbox Simulado integrado ao Firestore.
 */
'use strict';

const { db } = require('../config/firebase');
const config = require('../config/env');
const usuarioRepo = require('../repositories/usuario.repository');
const AppError = require('../utils/AppError');

const COLECAO_ASSINATURAS = 'assinaturas';
const MP_API_BASE = 'https://api.mercadopago.com';

function precoMensalPadrao() {
  return config.mercadoPago?.precoMensal || 29.9;
}

function limiteGratuitoPadrao() {
  return config.mercadoPago?.limitePacientesGratuito || 15;
}

function temTokenMercadoPagoReal() {
  return Boolean(config.mercadoPago?.accessToken);
}

function calcularProximoVencimento(dias = 30) {
  const data = new Date();
  data.setDate(data.getDate() + dias);
  return data.toISOString();
}

/**
 * Verifica se o nutricionista pode vincular/aceitar mais um paciente.
 * Lanca AppError 403 caso nao seja assinante Pro e ja tenha atingido 15 pacientes.
 */
async function verificarLimitePacientes(uidNutricionista, uidPacienteAlvo = null) {
  const nutri = await usuarioRepo.buscarPorUid(uidNutricionista);
  if (!nutri || nutri.tipoUsuario !== 'nutricionista') {
    throw AppError.forbidden('Apenas nutricionistas podem gerenciar pacientes.');
  }

  // Se for assinante ativo do Plano Pro, nao ha limite de pacientes.
  if (nutri.ehAssinante) {
    return;
  }

  const limite = nutri.limitePacientes ?? limiteGratuitoPadrao();
  const pacientesAtivos = await usuarioRepo.listarPacientesDoNutricionista(uidNutricionista);

  // Se o paciente alvo ja faz parte da lista ativa deste nutricionista, permite.
  if (uidPacienteAlvo && pacientesAtivos.some((p) => p.uid === uidPacienteAlvo)) {
    return;
  }

  if (pacientesAtivos.length >= limite) {
    throw AppError.forbidden(
      `Limite de ${limite} pacientes do plano gratuito atingido. ` +
        `Assine o Plano Pro por R$ ${precoMensalPadrao().toFixed(2).replace('.', ',')}/mês ` +
        'nas Configurações para atender pacientes ilimitados.',
      {
        codigo: 'LIMITE_PACIENTES_ATINGIDO',
        limitePacientes: limite,
        totalPacientes: pacientesAtivos.length,
        precoAssinatura: precoMensalPadrao(),
      }
    );
  }
}

/**
 * Retorna o resumo completo da assinatura do nutricionista e uso de pacientes.
 */
async function obterStatusAssinatura(uidNutricionista) {
  const nutri = await usuarioRepo.buscarPorUid(uidNutricionista);
  if (!nutri || nutri.tipoUsuario !== 'nutricionista') {
    throw AppError.forbidden('Apenas nutricionistas possuem plano de assinatura.');
  }

  const pacientesAtivos = await usuarioRepo.listarPacientesDoNutricionista(uidNutricionista);
  const limitePadrao = limiteGratuitoPadrao();
  const ehAssinante = Boolean(nutri.ehAssinante);
  const totalPacientes = pacientesAtivos.length;

  return {
    uidNutricionista,
    planoAssinatura: nutri.planoAssinatura || 'gratuito',
    statusAssinatura: nutri.statusAssinatura || 'inativa',
    ehAssinante,
    precoMensal: precoMensalPadrao(),
    moeda: 'BRL',
    limitePacientes: ehAssinante ? null : limitePadrao,
    limitePlanoGratuito: limitePadrao,
    totalPacientesAtivos: totalPacientes,
    restantesGratuito: ehAssinante ? null : Math.max(0, limitePadrao - totalPacientes),
    limiteAtingido: !ehAssinante && totalPacientes >= limitePadrao,
    assinaturaValidaAte: nutri.assinaturaValidaAte ?? null,
    idAssinaturaMp: nutri.idAssinaturaMp ?? null,
    checkoutUrl: nutri.checkoutUrlAssinatura ?? null,
    metodoPagamento: nutri.metodoPagamentoAssinatura ?? 'pix',
     provedor: 'mercado_pago',
    modoIntegracao: temTokenMercadoPagoReal() ? 'mercadopago_api' : 'mercadopago_sandbox_local',
  };
}

/**
 * Cria uma assinatura de R$ 29,90/mes no Mercado Pago (PreApproval) ou em modo
 * simulado no Firestore caso MP_ACCESS_TOKEN nao esteja definido.
 */
async function iniciarAssinatura({
  uidNutricionista,
  metodoPagamento = 'pix',
  confirmarImediatamente = false,
}) {
  const nutri = await usuarioRepo.buscarPorUid(uidNutricionista);
  if (!nutri || nutri.tipoUsuario !== 'nutricionista') {
    throw AppError.forbidden('Apenas nutricionistas podem assinar o Plano Pro.');
  }

  const metodo = ['pix', 'cartao', 'checkout_mp'].includes(metodoPagamento)
    ? metodoPagamento
    : 'pix';
  const preco = precoMensalPadrao();

  if (temTokenMercadoPagoReal()) {
    const corpoMp = {
      reason: 'Meu Virtual Nutri - Plano Profissional (Pacientes Ilimitados)',
      external_reference: uidNutricionista,
      payer_email: nutri.email,
      auto_recurring: {
        frequency: 1,
        frequency_type: 'months',
        transaction_amount: preco,
        currency_id: 'BRL',
      },
      back_url: config.mercadoPago.backUrl,
      status: 'pending',
    };

    const resposta = await fetch(`${MP_API_BASE}/preapproval`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.mercadoPago.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(corpoMp),
    });

    const dadosMp = await resposta.json().catch(() => ({}));
    if (!resposta.ok || !dadosMp.id) {
      throw new AppError(
        502,
        dadosMp.message || 'Nao foi possivel iniciar a assinatura no Mercado Pago.'
      );
    }

    const idAssinatura = String(dadosMp.id);
    const checkoutUrl = dadosMp.init_point || dadosMp.sandbox_init_point || null;

    await registrarEventoAssinatura(idAssinatura, {
      uidNutricionista,
      idAssinaturaMp: idAssinatura,
      provedor: 'mercado_pago',
      metodoPagamento: metodo,
      valorMensal: preco,
      status: 'pendente',
      checkoutUrl,
      criadoEm: new Date(),
    });

    await usuarioRepo.atualizar(uidNutricionista, {
      idAssinaturaMp: idAssinatura,
      checkoutUrlAssinatura: checkoutUrl,
      metodoPagamentoAssinatura: metodo,
      statusAssinatura: 'pendente',
      precoAssinatura: preco,
    });

    return obterStatusAssinatura(uidNutricionista);
  }

  // Modo Sandbox Local (sem MP_ACCESS_TOKEN configurado):
  // Permite testar todo o fluxo de checkout do Mercado Pago direto pelo app e CI/CD.
  const idSimulado = `mp_sim_${uidNutricionista.slice(0, 8)}_${Date.now()}`;
  const checkoutUrlSimulado = `https://www.mercadopago.com.br/subscriptions/checkout?preapproval_id=${idSimulado}`;
  const ativarAgora = confirmarImediatamente === true;
  const validaAte = ativarAgora ? calcularProximoVencimento(30) : null;

  await registrarEventoAssinatura(idSimulado, {
    uidNutricionista,
    idAssinaturaMp: idSimulado,
    provedor: 'mercado_pago_simulacao',
    metodoPagamento: metodo,
    valorMensal: preco,
    status: ativarAgora ? 'ativa' : 'pendente',
    checkoutUrl: checkoutUrlSimulado,
    criadoEm: new Date(),
  });

  await usuarioRepo.atualizar(uidNutricionista, {
    idAssinaturaMp: idSimulado,
    checkoutUrlAssinatura: checkoutUrlSimulado,
    metodoPagamentoAssinatura: metodo,
    planoAssinatura: ativarAgora ? 'pro' : 'gratuito',
    statusAssinatura: ativarAgora ? 'ativa' : 'pendente',
    limitePacientes: ativarAgora ? null : limiteGratuitoPadrao(),
    precoAssinatura: preco,
    assinaturaValidaAte: validaAte,
  });

  return obterStatusAssinatura(uidNutricionista);
}

/**
 * Confirma ou sincroniza o status da assinatura com o Mercado Pago.
 * - Com MP_ACCESS_TOKEN real: consulta `GET /preapproval/:id` no Mercado Pago.
 * - Em modo Sandbox Local: aprova a assinatura e libera o Plano Pro no Firestore.
 */
async function confirmarOuSincronizarAssinatura(uidNutricionista) {
  const nutri = await usuarioRepo.buscarPorUid(uidNutricionista);
  if (!nutri || nutri.tipoUsuario !== 'nutricionista') {
    throw AppError.forbidden('Apenas nutricionistas possuem assinatura.');
  }

  const idAssinatura = nutri.idAssinaturaMp;

  if (temTokenMercadoPagoReal() && idAssinatura && !idAssinatura.startsWith('mp_sim_')) {
    const resposta = await fetch(`${MP_API_BASE}/preapproval/${encodeURIComponent(idAssinatura)}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${config.mercadoPago.accessToken}`,
        'Content-Type': 'application/json',
      },
    });

    const dadosMp = await resposta.json().catch(() => ({}));
    if (!resposta.ok) {
      throw new AppError(
        502,
        dadosMp.message || 'Nao foi possivel consultar o status no Mercado Pago.'
      );
    }

    await aplicarDadosPreApprovalNoFirestore(dadosMp, uidNutricionista);
    return obterStatusAssinatura(uidNutricionista);
  }

  // Modo Sandbox Local: ativa o Plano Pro por 30 dias no Firestore.
  const idFinal = idAssinatura || `mp_sim_${uidNutricionista.slice(0, 8)}_${Date.now()}`;
  const validaAte = calcularProximoVencimento(30);

  await registrarEventoAssinatura(idFinal, {
    uidNutricionista,
    idAssinaturaMp: idFinal,
    provedor: 'mercado_pago_simulacao',
    metodoPagamento: nutri.metodoPagamentoAssinatura || 'pix',
    valorMensal: precoMensalPadrao(),
    status: 'ativa',
    confirmadoEm: new Date(),
  });

  await usuarioRepo.atualizar(uidNutricionista, {
    idAssinaturaMp: idFinal,
    planoAssinatura: 'pro',
    statusAssinatura: 'ativa',
    limitePacientes: null,
    precoAssinatura: precoMensalPadrao(),
    assinaturaValidaAte: validaAte,
  });

  return obterStatusAssinatura(uidNutricionista);
}

/**
 * Cancela a assinatura ativa do nutricionista no Mercado Pago e no Firestore,
 * retornando a conta para o Plano Gratuito (limite de 15 pacientes).
 */
async function cancelarAssinatura(uidNutricionista) {
  const nutri = await usuarioRepo.buscarPorUid(uidNutricionista);
  if (!nutri || nutri.tipoUsuario !== 'nutricionista') {
    throw AppError.forbidden('Apenas nutricionistas possuem assinatura.');
  }

  const idAssinatura = nutri.idAssinaturaMp;

  if (temTokenMercadoPagoReal() && idAssinatura && !idAssinatura.startsWith('mp_sim_')) {
    await fetch(`${MP_API_BASE}/preapproval/${encodeURIComponent(idAssinatura)}`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${config.mercadoPago.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ status: 'cancelled' }),
    }).catch(() => null);
  }

  if (idAssinatura) {
    await registrarEventoAssinatura(idAssinatura, {
      uidNutricionista,
      idAssinaturaMp: idAssinatura,
      status: 'cancelada',
      canceladoEm: new Date(),
    });
  }

  await usuarioRepo.atualizar(uidNutricionista, {
    planoAssinatura: 'gratuito',
    statusAssinatura: 'cancelada',
    limitePacientes: limiteGratuitoPadrao(),
    assinaturaValidaAte: null,
  });

  return obterStatusAssinatura(uidNutricionista);
}

/**
 * Processa notificacoes de Webhook enviadas pelo Mercado Pago
 * (`POST /api/assinatura/webhook`).
 */
async function processarWebhookMercadoPago(body = {}, query = {}) {
  const tipo = body.type || query.type || query.topic || '';
  const idPreApproval = body.data?.id || query['data.id'] || query.id || null;

  if (!idPreApproval) {
    return { processado: false, motivo: 'Evento sem ID de preapproval.' };
  }

  const ehEventoAssinatura =
    tipo.includes('preapproval') || tipo.includes('subscription') || Boolean(idPreApproval);

  if (!ehEventoAssinatura) {
    return { processado: false, motivo: `Tipo de evento ignorado: ${tipo}` };
  }

  if (temTokenMercadoPagoReal()) {
    const resposta = await fetch(
      `${MP_API_BASE}/preapproval/${encodeURIComponent(String(idPreApproval))}`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${config.mercadoPago.accessToken}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (resposta.ok) {
      const dadosMp = await resposta.json();
      const uid = dadosMp.external_reference;
      if (uid) {
        await aplicarDadosPreApprovalNoFirestore(dadosMp, uid);
        return { processado: true, uidNutricionista: uid, status: dadosMp.status };
      }
    }
  }

  return { processado: false, motivo: 'Token MP ausente ou preapproval nao localizado.' };
}

async function aplicarDadosPreApprovalNoFirestore(dadosMp, uidNutricionista) {
  const statusMp = String(dadosMp.status || '').toLowerCase();
  const autorizada = statusMp === 'authorized';
  const statusInterno = autorizada
    ? 'ativa'
    : statusMp === 'cancelled'
      ? 'cancelada'
      : statusMp === 'paused'
        ? 'pausada'
        : 'pendente';

  const proximoPagamento =
    dadosMp.next_payment_date || (autorizada ? calcularProximoVencimento(30) : null);

  await registrarEventoAssinatura(String(dadosMp.id), {
    uidNutricionista,
    idAssinaturaMp: String(dadosMp.id),
    statusMp,
    status: statusInterno,
    valorMensal: dadosMp.auto_recurring?.transaction_amount ?? precoMensalPadrao(),
    atualizadoEm: new Date(),
  });

  await usuarioRepo.atualizar(uidNutricionista, {
    idAssinaturaMp: String(dadosMp.id),
    planoAssinatura: autorizada ? 'pro' : 'gratuito',
    statusAssinatura: statusInterno,
    limitePacientes: autorizada ? null : limiteGratuitoPadrao(),
    assinaturaValidaAte: proximoPagamento,
  });
}

async function registrarEventoAssinatura(idAssinatura, dados) {
  try {
    await db()
      .collection(COLECAO_ASSINATURAS)
      .doc(String(idAssinatura))
      .set(dados, { merge: true });
  } catch (_) {
    // Nao bloqueia o fluxo principal caso a colecao auxiliar falhe.
  }
}

module.exports = {
  verificarLimitePacientes,
  obterStatusAssinatura,
  iniciarAssinatura,
  confirmarOuSincronizarAssinatura,
  cancelarAssinatura,
  processarWebhookMercadoPago,
  precoMensalPadrao,
  limiteGratuitoPadrao,
};

