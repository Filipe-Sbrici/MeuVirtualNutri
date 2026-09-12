/**
 * Teste E2E completo: Firebase Auth (real) + API REST + Firestore.
 *
 * Executa TODOS os fluxos do aplicativo contra o projeto Firebase real:
 *   - cria usuarios de teste no Firebase Authentication
 *   - materializa perfis pela API (Bearer ID token real)
 *   - onboarding completo do paciente
 *   - chat (envio + listagem + nao lidas)
 *   - progresso (peso, agua, humor, resumo, remocao)
 *   - cardapio (hoje, checklist, semanal, lista de compras)
 *   - receitas (criacao, biblioteca, compartilhada, avaliacao)
 *   - editor de plano (definir/remover refeicao)
 *   - agenda (criar, confirmar, concluir)
 *   - orientacoes (enviar + listar)
 *   - relatorios do nutricionista
 *   - perfil (atualizar + excluir)
 *   - limpeza total dos dados de teste
 *
 * Requisitos:
 *   - .env com FIREBASE_PROJECT_ID e credencial
 *     (GOOGLE_APPLICATION_CREDENTIALS ou FIREBASE_SERVICE_ACCOUNT)
 *   - API rodando: npm start
 *
 * Uso: node scripts/e2e-firebase.js   (opcional: --manter para nao limpar)
 */
'use strict';

require('dotenv').config();

const admin = require('firebase-admin');
const crypto = require('node:crypto');

const API = `http://localhost:${process.env.PORT || 3000}/api`;
const MANTER_DADOS = process.argv.includes('--manter');

const SUFFIX = crypto.randomBytes(4).toString('hex');
const NUTRI = {
  email: `e2e-nutri-${SUFFIX}@mvn-teste.com`,
  senha: 'senha123456',
  nome: 'Dr. E2E Nutri',
  crn: `CRN-3 ${SUFFIX}`,
};
const PACIENTE = {
  email: `e2e-pac-${SUFFIX}@mvn-teste.com`,
  senha: 'senha123456',
  nome: 'Paciente E2E',
};
// Segundo nutricionista, sem vinculo com o paciente: usado para provar
// o isolamento entre profissionais (receitas, agenda e chat).
const NUTRI2 = {
  email: `e2e-nutri2-${SUFFIX}@mvn-teste.com`,
  senha: 'senha123456',
  nome: 'Dra. E2E Estranha',
  crn: `CRN-3 x${SUFFIX}`,
};

let passou = 0;
let falhou = 0;

function ok(condicao, mensagem) {
  if (condicao) {
    passou++;
    console.log(`  ok: ${mensagem}`);
  } else {
    falhou++;
    console.error(`  FALHOU: ${mensagem}`);
  }
}

/** Chamada HTTP na API. */
async function api(metodo, caminho, { token, corpo, query } = {}) {
  const url = new URL(`${API}${caminho}`);
  if (query) Object.entries(query).forEach(([k, v]) => url.searchParams.set(k, v));

  const resposta = await fetch(url, {
    method: metodo,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  const json = await resposta.json().catch(() => null);
  return { status: resposta.status, json };
}

/** Cria usuario no Auth e devolve um ID token real. */
async function criarUsuarioAuth({ email, senha, nome }) {
  const usuario = await admin.auth().createUser({
    email,
    password: senha,
    displayName: nome,
  });
  const customToken = await admin.auth().createCustomToken(usuario.uid);
  const resposta = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${await apiKeyDoProjeto()}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  ).then((r) => r.json());
  if (!resposta.idToken) throw new Error(`Falha ao trocar custom token: ${JSON.stringify(resposta)}`);
  return { uid: usuario.uid, idToken: resposta.idToken };
}

/** Chave publica do app Web (necessaria p/ trocar custom token por idToken). */
async function apiKeyDoProjeto() {
  const apiKey = process.env.FIREBASE_API_KEY;
  if (!apiKey) {
    throw new Error(
      'Defina FIREBASE_API_KEY no .env (a mesma do app Web em Configuracoes do projeto > Seus apps).',
    );
  }
  return apiKey;
}

async function main() {
  console.log('=== E2E Firebase: Meu Virtual Nutri ===\n');

  // ------------------------------------------------------------------
  console.log('[1] Credenciais e conexao');
  const { firebaseApp, db: getDb } = require('../src/config/firebase');
  firebaseApp();
  const db = getDb();
  const ping = await db.collection('usuarios').limit(1).get();
  ok(true, `Firestore conectado (projeto ${process.env.FIREBASE_PROJECT_ID || 'meu-virtual-nutri'})`);
  void ping;

  // ------------------------------------------------------------------
  console.log('\n[2] Usuarios no Firebase Authentication');
  const nutriAuth = await criarUsuarioAuth(NUTRI);
  const pacAuth = await criarUsuarioAuth(PACIENTE);
  const nutri2Auth = await criarUsuarioAuth(NUTRI2);
  ok(Boolean(nutriAuth.idToken), `nutricionista criado: ${NUTRI.email}`);
  ok(Boolean(pacAuth.idToken), `paciente criado: ${PACIENTE.email}`);
  ok(Boolean(nutri2Auth.idToken), `nutricionista 2 criado: ${NUTRI2.email}`);

  // ------------------------------------------------------------------
  console.log('\n[3] Cadastro de perfis pela API');
  let r = await api('POST', '/auth/cadastro/nutricionista', {
    token: nutriAuth.idToken,
    corpo: {
      nome: NUTRI.nome,
      email: NUTRI.email,
      crn: NUTRI.crn,
      especializacao: 'Nutricao Esportiva',
    },
  });
  ok(r.status === 201 && r.json?.dados?.tipoUsuario === 'nutricionista',
    `cadastro nutricionista -> ${r.status}`);

  r = await api('POST', '/auth/cadastro/paciente', {
    token: pacAuth.idToken,
    corpo: { nome: PACIENTE.nome, email: PACIENTE.email },
  });
  ok(r.status === 201 && r.json?.dados?.tipoUsuario === 'paciente',
    `cadastro paciente -> ${r.status}`);

  r = await api('POST', '/auth/cadastro/nutricionista', {
    token: nutri2Auth.idToken,
    corpo: { nome: NUTRI2.nome, email: NUTRI2.email, crn: NUTRI2.crn },
  });
  ok(r.status === 201, `cadastro nutricionista 2 -> ${r.status}`);

  // Perfil da sessao.
  r = await api('GET', '/auth/perfil', { token: pacAuth.idToken });
  ok(r.status === 200 && r.json?.dados?.onboardingCompleto === false,
    `perfil paciente (onboarding incompleto) -> ${r.status}`);

  // ------------------------------------------------------------------
  console.log('\n[4] Onboarding do paciente');
  r = await api('GET', '/onboarding/nutricionistas', { token: pacAuth.idToken });
  ok(r.status === 200 && Array.isArray(r.json?.dados?.nutricionistas),
    `listar nutricionistas -> ${r.status}`);

  r = await api('POST', '/onboarding/nutricionista', {
    token: pacAuth.idToken,
    corpo: { uidNutricionista: nutriAuth.uid },
  });
  ok(r.status === 200, `escolher nutricionista -> ${r.status}`);

  r = await api('POST', '/onboarding/dados-pessoais', {
    token: pacAuth.idToken,
    corpo: { idade: 30, pesoAtual: 80.5, altura: 1.75, genero: 'Masculino', pesoMeta: 75 },
  });
  ok(r.status === 200, `dados pessoais -> ${r.status}`);

  r = await api('POST', '/onboarding/estilo-vida', {
    token: pacAuth.idToken,
    corpo: { nivelAtividade: 'moderado', meta: 'Perda de peso' },
  });
  ok(r.status === 200, `estilo de vida -> ${r.status}`);

  r = await api('POST', '/onboarding/perfil-alimentar', {
    token: pacAuth.idToken,
    corpo: {
      tipoDieta: 'Low carb',
      alimentosFavoritos: ['frango', 'batata doce'],
      alimentosRejeitados: ['peixe'],
    },
  });
  ok(r.status === 200, `perfil alimentar -> ${r.status}`);

  r = await api('POST', '/onboarding/restricoes', {
    token: pacAuth.idToken,
    corpo: { restricoes: ['Intolerancia a lactose'], condicoesMedicas: [] },
  });
  ok(r.status === 200 && r.json?.dados?.perfil?.onboardingCompleto === true,
    `restricoes (onboarding completo) -> ${r.status}`);

  r = await api('POST', '/onboarding/tutorial', { token: pacAuth.idToken });
  ok(r.status === 200, `tutorial concluido -> ${r.status}`);

  // O perfil da sessao precisa devolver os dados clinicos: a tela de
  // Perfil (4.5.19) calcula o IMC e mostra as restricoes a partir deles.
  r = await api('GET', '/auth/perfil', { token: pacAuth.idToken });
  ok(
    r.json?.dados?.idade === 30 &&
      r.json?.dados?.pesoAtual === 80.5 &&
      r.json?.dados?.altura === 1.75 &&
      r.json?.dados?.pesoMeta === 75,
    `perfil devolve dados clinicos (idade/peso/altura/meta) -> ${r.status}`,
  );
  ok(
    Array.isArray(r.json?.dados?.restricoes) &&
      r.json.dados.restricoes.includes('Intolerancia a lactose') &&
      r.json?.dados?.nivelAtividade === 'moderado' &&
      r.json?.dados?.tipoDieta === 'Low carb',
    'perfil devolve restricoes, nivelAtividade e tipoDieta',
  );

  // ------------------------------------------------------------------
  console.log('\n[5] Chat');
  r = await api('GET', '/chat/contato', { token: pacAuth.idToken });
  ok(r.status === 200 && r.json?.dados?.idUsuario === nutriAuth.uid,
    `contato padrao do paciente -> ${r.status}`);

  r = await api('POST', '/chat/mensagens', {
    token: pacAuth.idToken,
    corpo: { uidContato: nutriAuth.uid, mensagem: 'Ola doutor, bom dia!' },
  });
  ok(r.status === 201 && r.json?.dados?.ehMinha === true, `paciente envia -> ${r.status}`);

  r = await api('POST', '/chat/mensagens', {
    token: nutriAuth.idToken,
    corpo: { uidContato: pacAuth.uid, mensagem: 'Bom dia! Tudo certo?' },
  });
  ok(r.status === 201 && r.json?.dados?.ehMinha === true, `nutri responde -> ${r.status}`);

  r = await api('GET', `/chat/conversa/${pacAuth.uid}`, { token: nutriAuth.idToken });
  ok(r.status === 200 && r.json?.dados?.mensagens?.length === 2,
    `conversa com 2 mensagens -> ${r.status}`);

  r = await api('GET', '/chat/nao-lidas', { token: pacAuth.idToken });
  // O paciente abriu a conversa? Nao: quem abriu foi o nutri. Paciente tem 1 nao lida.
  ok(r.status === 200 && r.json?.dados?.total === 1, `nao lidas do paciente = 1 -> ${r.json?.dados?.total}`);

  // ------------------------------------------------------------------
  console.log('\n[6] Progresso');
  r = await api('POST', '/progresso/peso', {
    token: pacAuth.idToken,
    corpo: { peso: 80.2, dataRegistro: hojeMenos(1) },
  });
  ok(r.status === 201, `registrar peso -> ${r.status}`);

  r = await api('POST', '/progresso/peso', {
    token: pacAuth.idToken,
    corpo: { peso: 79.8 },
  });
  ok(r.status === 201, `registrar peso hoje -> ${r.status}`);

  r = await api('GET', '/progresso', { token: pacAuth.idToken });
  ok(r.status === 200 && r.json?.dados?.historico?.length === 2,
    `resumo com 2 pesagens -> ${r.status}`);
  ok(r.json?.dados?.resumo?.pesoAtual === 79.8, `peso atual 79.8 -> ${r.json?.dados?.resumo?.pesoAtual}`);

  r = await api('POST', '/progresso/agua', {
    token: pacAuth.idToken,
    corpo: { coposAgua: 5 },
  });
  ok(r.status === 200, `agua (5 copos) -> ${r.status}`);

  r = await api('POST', '/progresso/humor', {
    token: pacAuth.idToken,
    corpo: { humor: 'bom' },
  });
  ok(r.status === 200, `humor (bom) -> ${r.status}`);

  // A aba Bem-Estar reabre com a hidratacao/humor do dia ja gravados.
  r = await api('GET', '/progresso', { token: pacAuth.idToken });
  ok(
    r.json?.dados?.hoje?.coposAgua === 5 && r.json?.dados?.hoje?.humor === 'bom',
    `progresso devolve registros de hoje (agua/humor) -> ` +
      `${r.json?.dados?.hoje?.coposAgua}/${r.json?.dados?.hoje?.humor}`,
  );

  r = await api('GET', '/evolucao', { token: pacAuth.idToken, query: { periodo: 'semanal' } });
  ok(r.status === 200 && r.json?.dados?.periodo === 'semanal', `evolucao semanal -> ${r.status}`);

  // Sem plano alimentar a meta vem do calculo de Mifflin-St Jeor sobre
  // os dados clinicos do onboarding: precisa ser um numero, nao null.
  const metaSemPlano = r.json?.dados?.metaCalorica;
  ok(
    typeof metaSemPlano === 'number' && metaSemPlano > 1000,
    `meta calorica calculada do perfil -> ${metaSemPlano}`,
  );
  ok(
    r.json?.dados?.macronutrientes?.origemMeta === 'calculo_mifflin_st_jeor' &&
      (r.json?.dados?.macronutrientes?.itens ?? []).every((i) => i.meta > 0),
    'metas de macronutrientes derivadas da meta calorica',
  );

  // ------------------------------------------------------------------
  console.log('\n[7] Receitas do nutricionista');
  r = await api('POST', '/nutricionista/receitas', {
    token: nutriAuth.idToken,
    corpo: {
      nome: 'Frango E2E',
      modoPreparo: 'Grelhe o frango.',
      ingredientes: [
        { idAlimento: 'frango', nome: 'Peito de frango grelhado', categoria: 'Proteinas', calorias: 165, proteinas: 31, carboidratos: 0, gorduras: 3.6, quantidadeG: 150 },
        { idAlimento: 'brocolis', nome: 'Brocolis cozido', categoria: 'Vegetais', calorias: 35, proteinas: 2.4, carboidratos: 7, gorduras: 0.4, quantidadeG: 100 },
      ],
    },
  });
  ok(r.status === 201 && r.json?.dados?.calorias > 0, `criar receita -> ${r.status}`);
  const idReceita = r.json?.dados?.idReceita;

  r = await api('GET', '/nutricionista/receitas', { token: nutriAuth.idToken });
  ok(r.status === 200 && r.json?.dados?.receitas?.length === 1, `biblioteca com 1 receita -> ${r.status}`);

  r = await api('GET', '/nutricionista/alimentos', { token: nutriAuth.idToken });
  const temAlimentos = (r.json?.dados?.alimentos?.length ?? 0) > 0;
  ok(r.status === 200, `base de alimentos -> ${r.status}${temAlimentos ? '' : ' (VAZIA: rode npm run db:seed)'}`);

  // ------------------------------------------------------------------
  console.log('\n[8] Editor de cardapio');
  r = await api('GET', `/nutricionista/pacientes/${pacAuth.uid}/plano`, { token: nutriAuth.idToken });
  ok(r.status === 200, `plano para edicao -> ${r.status}`);

  r = await api('POST', `/nutricionista/pacientes/${pacAuth.uid}/plano/refeicoes`, {
    token: nutriAuth.idToken,
    corpo: { dia: 'segunda', tipo: 'almoco', idReceita, horario: '12:30' },
  });
  ok(r.status === 201, `definir refeicao almoco/segunda -> ${r.status}`);

  // ------------------------------------------------------------------
  console.log('\n[9] Cardapio do paciente');
  r = await api('GET', '/cardapio/hoje', { token: pacAuth.idToken });
  const refeicoesHoje = r.json?.dados?.refeicoes ?? [];
  ok(r.status === 200, `cardapio de hoje -> ${r.status}`);
  // A refeicao so aparece se hoje for segunda; valida o payload de qualquer forma.
  ok(r.json?.dados?.dia !== undefined, `campo dia presente (${r.json?.dados?.dia})`);

  // Sempre conseguimos consultar o semanal.
  r = await api('GET', '/cardapio/semanal', { token: pacAuth.idToken });
  const segunda = (r.json?.dados?.dias ?? []).find((d) => d.dia === 'segunda');
  ok(r.status === 200 && segunda?.refeicoes?.length === 1, `plano semanal (segunda com 1 refeicao) -> ${r.status}`);

  if (segunda?.refeicoes[0]) {
    // O checklist opera sobre o dia corrente; define a refeicao no dia
    // de hoje para exercitar o fluxo completo do paciente.
    const diaHoje = diaAtual();
    r = await api('POST', `/nutricionista/pacientes/${pacAuth.uid}/plano/refeicoes`, {
      token: nutriAuth.idToken,
      corpo: { dia: diaHoje, tipo: 'almoco', idReceita, horario: '12:30' },
    });
    ok(r.status === 201, `definir refeicao do dia (${diaHoje}) -> ${r.status}`);

    r = await api('POST', '/cardapio/hoje/check', {
      token: pacAuth.idToken,
      corpo: { dia: diaHoje, tipo: 'almoco', concluida: true },
    });
    ok(r.status === 200 && r.json?.dados?.resumo?.concluidas === 1, `checklist concluir -> ${r.status}`);

    r = await api('GET', '/cardapio/lista-compras', { token: pacAuth.idToken });
    ok(r.status === 200 && (r.json?.dados?.itens?.length ?? 0) > 0, `lista de compras com itens -> ${r.status}`);
  }

  // ------------------------------------------------------------------
  console.log('\n[10] Agenda');
  const amanha = new Date(Date.now() + 24 * 3600 * 1000);
  amanha.setHours(10, 0, 0, 0);
  r = await api('POST', '/consultas', {
    token: nutriAuth.idToken,
    corpo: { dataHora: amanha.toISOString(), observacoes: 'Primeira consulta' },
  });
  ok(r.status === 201, `nutri abre horario -> ${r.status}`);
  const idConsulta = r.json?.dados?.idConsulta;

  r = await api('GET', '/consultas', { token: pacAuth.idToken });
  ok(r.status === 200 && r.json?.dados?.consultas?.length >= 1, `agenda do paciente -> ${r.status}`);

  if (idConsulta) {
    r = await api('POST', `/consultas/${idConsulta}/confirmar`, { token: pacAuth.idToken });
    ok(r.status === 200, `paciente confirma -> ${r.status}`);

    r = await api('POST', `/consultas/${idConsulta}/concluir`, { token: nutriAuth.idToken });
    ok(r.status === 200, `nutri conclui -> ${r.status}`);
  }

  // ------------------------------------------------------------------
  console.log('\n[11] Orientacoes');
  r = await api('POST', '/nutricionista/orientacoes', {
    token: nutriAuth.idToken,
    corpo: { uidPaciente: pacAuth.uid, categoria: 'positivo', texto: 'Otimo progresso!' },
  });
  ok(r.status === 201, `enviar orientacao -> ${r.status}`);

  r = await api('GET', '/orientacoes', { token: pacAuth.idToken });
  ok(r.status === 200 && r.json?.dados?.orientacoes?.length === 1, `paciente lista orientacoes -> ${r.status}`);

  // ------------------------------------------------------------------
  console.log('\n[12] Minhas receitas (compartilhamento)');
  r = await api('POST', '/minhas-receitas', {
    token: pacAuth.idToken,
    corpo: {
      nome: 'Suco E2E',
      modoPreparo: 'Bata tudo.',
      ingredientes: [
        { idAlimento: 'banana', nome: 'Banana', categoria: 'Frutas', calorias: 89, proteinas: 1.1, carboidratos: 23, gorduras: 0.3, quantidadeG: 100 },
      ],
    },
  });
  ok(r.status === 201, `paciente compartilha receita -> ${r.status}`);
  // 100 g de banana a 89 kcal/100 g: prova que os macros por 100 g
  // enviados pelo app viram os totais da receita (e nao 0).
  ok(
    r.json?.dados?.calorias === 89 && r.json?.dados?.carboidratos === 23,
    `macros da receita calculados dos ingredientes -> ` +
      `${r.json?.dados?.calorias} kcal`,
  );

  r = await api('GET', '/nutricionista/receitas/pendentes', { token: nutriAuth.idToken });
  const pendente = (r.json?.dados?.receitas ?? []).find(
    (rec) => rec.uidPacienteAutor === pacAuth.uid,
  );
  ok(r.status === 200 && Boolean(pendente), `receita pendente visivel ao nutri -> ${r.status}`);

  if (pendente) {
    r = await api('POST', `/nutricionista/receitas/${pendente.idReceita}/avaliar`, {
      token: nutriAuth.idToken,
      corpo: { status: 'aprovada' },
    });
    ok(r.status === 200, `aprovar receita -> ${r.status}`);
  }

  // ------------------------------------------------------------------
  console.log('\n[13] Pacientes e relatorios do nutricionista');
  r = await api('GET', '/nutricionista/pacientes', { token: nutriAuth.idToken });
  ok(r.status === 200 && r.json?.dados?.pacientes?.some((p) => p.uid === pacAuth.uid),
    `lista de pacientes -> ${r.status}`);

  r = await api('GET', '/nutricionista/relatorios', { token: nutriAuth.idToken });
  const relatorio = (r.json?.dados?.relatorios ?? []).find((x) => x.uid === pacAuth.uid);
  ok(r.status === 200 && Boolean(relatorio), `relatorios -> ${r.status}`);

  // Evolucao do paciente vista pelo nutri.
  r = await api('GET', `/evolucao/${pacAuth.uid}`, { token: nutriAuth.idToken });
  ok(r.status === 200, `evolucao do paciente pelo nutri -> ${r.status}`);

  // Paciente NAO pode ver evolucao de outro.
  r = await api('GET', `/evolucao/${nutriAuth.uid}`, { token: pacAuth.idToken });
  ok(r.status === 403, `paciente nao ve evolucao de outro (403) -> ${r.status}`);

  // ------------------------------------------------------------------
  console.log('\n[14] Seguranca');
  r = await api('GET', '/progresso');
  ok(r.status === 401, `sem token -> ${r.status} (401)`);

  r = await api('POST', '/nutricionista/pacientes', { token: pacAuth.idToken, corpo: {} });
  ok(r.status === 403, `paciente nao usa rota de nutri (403) -> ${r.status}`);

  r = await api('POST', '/progresso/peso', {
    token: pacAuth.idToken,
    corpo: { peso: 500 },
  });
  ok(r.status === 400, `peso invalido rejeitado (400) -> ${r.status}`);

  // ------------------------------------------------------------------
  console.log('\n[15] Perfil');
  r = await api('PUT', '/perfil/perfil', {
    token: pacAuth.idToken,
    corpo: { nome: 'Paciente E2E Renomeado' },
  });
  ok(r.status === 200 && r.json?.dados?.perfil?.nome === 'Paciente E2E Renomeado',
    `atualizar perfil -> ${r.status}`);

  r = await api('DELETE', '/progresso/peso/' + hojeMenos(1), { token: pacAuth.idToken });
  ok(r.status === 200, `remover pesagem antiga -> ${r.status}`);

  // ------------------------------------------------------------------
  console.log('\n[16] Isolamento entre profissionais e integridade');

  // Receitas: o nutricionista 2 nao ve nem avalia as pendentes do 1.
  r = await api('GET', '/nutricionista/receitas/pendentes', { token: nutri2Auth.idToken });
  const vazamento = (r.json?.dados?.receitas ?? []).some(
    (rec) => rec.uidPacienteAutor === pacAuth.uid,
  );
  ok(r.status === 200 && !vazamento,
    `nutri 2 nao ve receitas pendentes do nutri 1 -> ${r.status}`);

  if (idReceita) {
    r = await api('POST', `/nutricionista/receitas/${idReceita}/avaliar`, {
      token: nutri2Auth.idToken,
      corpo: { status: 'recusada' },
    });
    ok(r.status === 403, `nutri 2 nao avalia receita do nutri 1 (403) -> ${r.status}`);

    // Edicao com id de receita alheia nao pode sobrescrever a original.
    r = await api('POST', '/nutricionista/receitas', {
      token: nutri2Auth.idToken,
      corpo: {
        idReceita,
        nome: 'Sequestro de receita',
        ingredientes: [{ nome: 'x', quantidadeG: 10, calorias: 1 }],
      },
    });
    ok(r.status === 403, `nutri 2 nao sobrescreve receita do nutri 1 (403) -> ${r.status}`);
  }

  // Agenda: horario do nutri 1 nao pode ser concluido/cancelado pelo 2.
  const outroHorario = new Date(Date.now() + 48 * 3600 * 1000);
  outroHorario.setHours(9, 0, 0, 0);
  r = await api('POST', '/consultas', {
    token: nutriAuth.idToken,
    corpo: { dataHora: outroHorario.toISOString(), observacoes: 'Retorno' },
  });
  const idLivre = r.json?.dados?.idConsulta;
  ok(r.status === 201 && Boolean(idLivre), `nutri 1 abre segundo horario -> ${r.status}`);

  if (idLivre) {
    r = await api('POST', `/consultas/${idLivre}/concluir`, { token: nutri2Auth.idToken });
    ok(r.status === 403, `nutri 2 nao conclui consulta do nutri 1 (403) -> ${r.status}`);

    r = await api('POST', `/consultas/${idLivre}/cancelar`, { token: nutri2Auth.idToken });
    ok(r.status === 403, `nutri 2 nao cancela consulta do nutri 1 (403) -> ${r.status}`);
  }

  // Id inexistente devolve 404 (e nao cria documento fantasma).
  r = await api('POST', '/consultas/id-que-nao-existe/cancelar', { token: nutriAuth.idToken });
  ok(r.status === 404, `cancelar consulta inexistente -> ${r.status} (404)`);
  const fantasma = await admin.firestore()
    .collection('consultas').doc('id-que-nao-existe').get();
  ok(!fantasma.exists, 'consulta inexistente nao foi criada no Firestore');

  // O paciente nao ve horarios livres de nutricionistas nao vinculados.
  const horarioEstranho = new Date(Date.now() + 72 * 3600 * 1000);
  horarioEstranho.setHours(8, 0, 0, 0);
  r = await api('POST', '/consultas', {
    token: nutri2Auth.idToken,
    corpo: { dataHora: horarioEstranho.toISOString(), observacoes: 'De outro nutri' },
  });
  const idEstranho = r.json?.dados?.idConsulta;
  ok(r.status === 201, `nutri 2 abre horario proprio -> ${r.status}`);

  r = await api('GET', '/consultas', { token: pacAuth.idToken });
  const listaPaciente = r.json?.dados?.consultas ?? [];
  ok(
    !listaPaciente.some((c) => c.idConsulta === idEstranho),
    'agenda do paciente nao mostra horario de nutricionista nao vinculado',
  );

  if (idEstranho) {
    r = await api('POST', `/consultas/${idEstranho}/confirmar`, { token: pacAuth.idToken });
    ok(r.status === 403, `paciente nao confirma horario de outro nutri (403) -> ${r.status}`);
  }

  // Chat: apenas paciente <-> nutricionista vinculado.
  r = await api('GET', `/chat/conversa/${nutri2Auth.uid}`, { token: pacAuth.idToken });
  ok(r.status === 403, `paciente nao conversa com nutri nao vinculado (403) -> ${r.status}`);

  r = await api('POST', '/chat/mensagens', {
    token: nutri2Auth.idToken,
    corpo: { uidContato: pacAuth.uid, mensagem: 'Oi, sou de outro consultorio.' },
  });
  ok(r.status === 403, `nutri 2 nao envia mensagem ao paciente do nutri 1 (403) -> ${r.status}`);

  // Checklist: dia/tipo fora do plano nao pode virar refeicao fantasma.
  r = await api('POST', '/cardapio/hoje/check', {
    token: pacAuth.idToken,
    corpo: { dia: 'domingo', tipo: 'ceia', concluida: true },
  });
  ok(r.status === 404, `checklist de refeicao inexistente -> ${r.status} (404)`);

  r = await api('POST', '/cardapio/hoje/check', {
    token: pacAuth.idToken,
    corpo: { dia: 'feriado', tipo: 'almoco', concluida: true },
  });
  ok(r.status === 400, `checklist com dia invalido -> ${r.status} (400)`);

  r = await api('GET', '/cardapio/semanal', { token: pacAuth.idToken });
  const totalRefeicoes = (r.json?.dados?.dias ?? []).reduce(
    (soma, d) => soma + (d.refeicoes?.length ?? 0),
    0,
  );
  ok(
    r.json?.dados?.progressoMontagem?.preenchidas === totalRefeicoes &&
      r.json?.dados?.progressoMontagem?.total === 42,
    `barra de montagem coerente (${totalRefeicoes}/42)`,
  );

  // Base de alimentos: o paciente precisa dela para montar a receita
  // que vai compartilhar (com os macros por 100 g).
  r = await api('GET', '/alimentos', { token: pacAuth.idToken });
  const alimentos = r.json?.dados?.alimentos ?? [];
  ok(
    r.status === 200 && alimentos.length > 0 &&
      alimentos.every((a) => typeof a.calorias === 'number'),
    `paciente acessa base de alimentos (${alimentos.length}) -> ${r.status}`,
  );

  // Horario no passado nao pode ser publicado na agenda.
  r = await api('POST', '/consultas', {
    token: nutriAuth.idToken,
    corpo: { dataHora: new Date(Date.now() - 3600 * 1000).toISOString() },
  });
  ok(r.status === 400, `horario no passado recusado -> ${r.status} (400)`);

  // O nutricionista dono remove o proprio horario livre (botao da Agenda).
  if (idLivre) {
    r = await api('POST', `/consultas/${idLivre}/cancelar`, {
      token: nutriAuth.idToken,
    });
    ok(r.status === 200 && r.json?.dados?.status === 'cancelada',
      `nutri cancela horario proprio -> ${r.status}`);

    r = await api('GET', '/consultas', { token: pacAuth.idToken });
    ok(
      !(r.json?.dados?.consultas ?? []).some(
        (c) => c.idConsulta === idLivre && c.status === 'disponivel',
      ),
      'horario cancelado sai da agenda do paciente',
    );
  }

  // ------------------------------------------------------------------
  // Resumo
  console.log('\n==============================');
  console.log(`RESULTADO: ${passou} passaram, ${falhou} falharam`);
  console.log('==============================');

  if (!MANTER_DADOS) {
    console.log('\n[limpeza] removendo dados de teste...');
    await limpar(pacAuth.uid, nutriAuth.uid, nutri2Auth.uid);
    console.log('limpeza concluida.');
  } else {
    console.log(`\nDados mantidos (--manter). UIDs:\n  nutri: ${nutriAuth.uid}\n  nutri2: ${nutri2Auth.uid}\n  paciente: ${pacAuth.uid}`);
  }

  process.exit(falhou > 0 ? 1 : 0);
}

function hojeMenos(dias) {
  const d = new Date();
  d.setDate(d.getDate() - dias);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** Dia da semana corrente na chave usada pelo plano (segunda..domingo). */
function diaAtual() {
  // getDay(): 0=domingo, 1=segunda, ..., 6=sabado.
  const mapa = ['domingo', 'segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado'];
  return mapa[new Date().getDay()];
}

async function limpar(uidPaciente, uidNutri, uidNutri2 = null) {
  const db = admin.firestore();
  const apagarDocs = async (refs) => {
    for (const ref of refs) await ref.delete().catch(() => {});
  };

  // progresso do paciente
  const progresso = await db.collection('usuarios').doc(uidPaciente).collection('progresso').get();
  await apagarDocs(progresso.docs.map((d) => d.ref));
  await db.collection('usuarios').doc(uidPaciente).delete();

  // conversas
  const conversas = await db.collection('conversas')
    .where('participantes', 'array-contains', uidPaciente).get();
  for (const conversa of conversas.docs) {
    const mensagens = await conversa.ref.collection('mensagens').get();
    await apagarDocs(mensagens.docs.map((d) => d.ref));
    await conversa.ref.delete();
  }

  // planos + refeicoes
  const planos = await db.collection('planos').where('uidPaciente', '==', uidPaciente).get();
  for (const plano of planos.docs) {
    const refeicoes = await plano.ref.collection('refeicoes').get();
    await apagarDocs(refeicoes.docs.map((d) => d.ref));
    await plano.ref.delete();
  }

  // receitas dos nutris + compartilhadas pelo paciente
  for (const uid of [uidNutri, uidNutri2].filter(Boolean)) {
    const receitas = await db.collection('receitas').where('uidNutricionista', '==', uid).get();
    await apagarDocs(receitas.docs.map((d) => d.ref));
  }
  const receitasPaciente = await db.collection('receitas').where('uidPacienteAutor', '==', uidPaciente).get();
  await apagarDocs(receitasPaciente.docs.map((d) => d.ref));

  // consultas + orientacoes
  for (const uid of [uidNutri, uidNutri2].filter(Boolean)) {
    const consultas = await db.collection('consultas')
      .where('participantes', 'array-contains', uid).get();
    await apagarDocs(consultas.docs.map((d) => d.ref));
  }
  const orientacoes = await db.collection('orientacoes').where('uidPaciente', '==', uidPaciente).get();
  await apagarDocs(orientacoes.docs.map((d) => d.ref));

  for (const uid of [uidNutri, uidNutri2].filter(Boolean)) {
    await db.collection('usuarios').doc(uid).delete();
  }

  // usuarios do Auth
  for (const uid of [uidPaciente, uidNutri, uidNutri2].filter(Boolean)) {
    await admin.auth().deleteUser(uid).catch(() => {});
  }
}

main().catch(async (erro) => {
  console.error('\nERRO FATAL:', erro.message);
  process.exit(1);
});
