/**
 * Servico da tela de Chat.
 *
 * Regras:
 *  - O remetente e sempre o usuario autenticado (identificacao
 *    dinamica baseada no ID do usuario logado, como no prototipo).
 *  - `ehMinha` no JSON permite ao Flutter escolher o balao correto
 *    sem repetir a comparacao de IDs na camada de UI.
 */
'use strict';

const conversaRepo = require('../repositories/conversa.repository');
const usuarioRepo = require('../repositories/usuario.repository');
const AppError = require('../utils/AppError');

const LIMITE_MENSAGENS = 500;
const TAMANHO_MAX_MENSAGEM = 2000;

/**
 * Valida o contato e devolve seu resumo.
 *
 * O prototipo preve conversa apenas entre um paciente e o seu
 * nutricionista vinculado. A checagem e feita aqui (e nao so na UI)
 * para que a API nao permita abrir conversa com um usuario qualquer.
 */
async function validarContato(uidContato, usuario) {
  if (!uidContato || uidContato === usuario.uid) {
    throw AppError.badRequest('Contato invalido para a conversa.');
  }
  const contato = await usuarioRepo.buscarResumo(uidContato);
  if (!contato) throw AppError.notFound('Contato nao encontrado.');

  const vinculado =
    usuario.tipoUsuario === 'paciente'
      ? contato.tipoUsuario === 'nutricionista' &&
        usuario.idNutricionista === uidContato
      : contato.tipoUsuario === 'paciente' &&
        (await usuarioRepo.buscarPorUid(uidContato))?.idNutricionista ===
          usuario.uid;

  if (!vinculado) {
    throw AppError.forbidden(
      'A conversa so esta disponivel entre o paciente e o seu nutricionista.',
    );
  }
  return contato;
}

/** Cabecalho + mensagens da conversa. */
async function obterConversa({ usuario, uidContato, depoisDe }) {
  const contato = await validarContato(uidContato, usuario);

  const idConversa = conversaRepo.idDaConversa(usuario.uid, uidContato);
  const mensagens = depoisDe
    ? await conversaRepo.listarNovas(idConversa, usuario.uid, depoisDe)
    : await conversaRepo.listarConversa(idConversa, usuario.uid, LIMITE_MENSAGENS);

  // Abrir a conversa zera as nao lidas do contato.
  await conversaRepo.marcarComoLidas(idConversa, usuario.uid, uidContato);

  return {
    contato: {
      ...contato,
      papel: contato.tipoUsuario === 'nutricionista' ? 'Nutricionista' : 'Paciente',
    },
    mensagens,
  };
}

/** Envia uma mensagem e devolve o registro persistido. */
async function enviarMensagem({ usuario, uidContato, texto }) {
  const contato = await validarContato(uidContato, usuario);

  const idConversa = conversaRepo.idDaConversa(usuario.uid, uidContato);
  await conversaRepo.garantirConversa(idConversa, usuario.uid, uidContato, {
    [usuario.uid]: usuario.nome,
    [uidContato]: contato.nome,
  });

  return conversaRepo.inserirMensagem({
    idConversa,
    remetente: usuario.uid,
    destinatario: uidContato,
    nomeRemetente: usuario.nome,
    texto,
  });
}

/**
 * Contato padrao: pacientes falam com o nutricionista vinculado;
 * nutricionistas indicam o paciente explicitamente.
 */
async function obterContatoPadrao({ usuario, uidPaciente }) {
  if (usuario.tipoUsuario === 'paciente') {
    const nutri = await usuarioRepo.nutricionistaDoPaciente(usuario.uid);
    if (!nutri) {
      throw AppError.notFound(
        'Nenhum nutricionista vinculado a este paciente foi encontrado.',
      );
    }
    return {
      idUsuario: nutri.uid,
      uid: nutri.uid,
      idNutricionista: nutri.uid,
      nome: nutri.nome,
      crn: nutri.crn,
      especializacao: nutri.especializacao,
      papel: 'Nutricionista',
    };
  }

  if (!uidPaciente) {
    throw AppError.badRequest('Informe o paciente via ?uidPaciente=...');
  }
  const paciente = await usuarioRepo.buscarPorUid(uidPaciente);
  if (!paciente || paciente.tipoUsuario !== 'paciente') {
    throw AppError.notFound('Paciente nao encontrado.');
  }
  if (paciente.idNutricionista !== usuario.uid) {
    throw AppError.forbidden('Paciente nao esta vinculado a voce.');
  }
  return {
    uid: paciente.uid,
    idUsuario: paciente.uid,
    nome: paciente.nome,
    tipoUsuario: paciente.tipoUsuario,
    crn: null,
    especializacao: null,
    papel: 'Paciente',
  };
}

/** Total de mensagens nao lidas destinadas ao usuario (banner). */
async function contarNaoLidas(uid) {
  return conversaRepo.naoLidasDoUsuario(uid);
}

module.exports = {
  obterConversa,
  enviarMensagem,
  obterContatoPadrao,
  contarNaoLidas,
  TAMANHO_MAX_MENSAGEM,
};
