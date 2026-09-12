/**
 * Seed do Firestore: recria os dados de demonstracao do prototipo.
 *
 * Requer um dos modos de acesso:
 *  - Emulador:  FIRESTORE_EMULATOR_HOST=localhost:8080 (e
 *               FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 quando quiser
 *               criar os usuarios de demonstracao no Auth emulado).
 *  - Producao: GOOGLE_APPLICATION_CREDENTIALS ou FIREBASE_SERVICE_ACCOUNT.
 *
 * Dados (equivalentes ao antigo 02_seed.sql):
 *   - Dr. Gabriel (nutricionista) e Ana Beatriz (paciente), senha 123456
 *   - Conversa inicial do chat
 *   - Pesagens semanais (70.5 -> 68.1 = 2.4 kg perdidos, meta 65 kg)
 *   - Consumo calorico diario dos ultimos dias
 *   - Plano alimentar "Low Carb Semanal" com receitas de exemplo
 *
 * Uso: npm run db:seed [-- --auth]
 */
'use strict';

require('dotenv').config();

const { firebaseApp, db: getDb } = require('../src/config/firebase');
const admin = require('firebase-admin');
const crypto = require('node:crypto');

// ---------------------------------------------------------------------
// Inicializacao
// ---------------------------------------------------------------------

const uidDemo = (prefixo) =>
  `demo_${prefixo}_${crypto.randomBytes(6).toString('hex')}`;

async function main() {
  firebaseApp();
  const db = getDb();

  console.log('Semeando Firestore...'
    + (process.env.FIRESTORE_EMULATOR_HOST ? ' (emulador)' : ' (PROJETO REAL)'));

  // -------------------------------------------------------------------
  // Limpeza (ordem inversa de dependencia)
  // -------------------------------------------------------------------
  console.log('Limpando colecoes de demonstracao...');
  await apagarColecao(db, 'usuarios');
  await apagarColecao(db, 'conversas');
  await apagarColecao(db, 'planos', async (doc) => {
    await apagarSubcolecao(doc.ref.collection('refeicoes'));
  });
  await apagarColecao(db, 'receitas');
  await apagarColecao(db, 'consultas');
  await apagarColecao(db, 'orientacoes');
  await apagarColecao(db, 'alimentos');

  // -------------------------------------------------------------------
  // Alimentos (base para receitas e lista de compras)
  // -------------------------------------------------------------------
  const alimentos = [
    ['frango', 'Peito de frango grelhado', 'Proteinas', 165, 31, 0, 3.6],
    ['ovo', 'Ovo de galinha', 'Proteinas', 155, 13, 1.1, 11],
    ['iougurte', 'Iogurte natural', 'Laticinios', 61, 3.5, 4.7, 3.3],
    ['aveia', 'Aveia em flocos', 'Carboidratos', 389, 17, 66, 7],
    ['banana', 'Banana', 'Frutas', 89, 1.1, 23, 0.3],
    ['arroz', 'Arroz integral cozido', 'Carboidratos', 124, 2.6, 26, 1],
    ['feijao', 'Feijao carioca cozido', 'Proteinas', 76, 4.8, 13.6, 0.5],
    ['batataDoce', 'Batata doce cozida', 'Carboidratos', 86, 1.6, 20, 0.1],
    ['brocolis', 'Brocolis cozido', 'Vegetais', 35, 2.4, 7, 0.4],
    ['salada', 'Salada verde mista', 'Vegetais', 20, 1.2, 3.5, 0.2],
    ['salmão', 'File de salmao', 'Proteinas', 208, 20, 0, 13],
    ['tapioca', 'Goma de tapioca', 'Carboidratos', 240, 0, 60, 0],
    ['queijo', 'Queijo minas', 'Laticinios', 264, 17, 3, 21],
    ['maca', 'Maca', 'Frutas', 52, 0.3, 14, 0.2],
    ['whey', 'Whey protein', 'Suplementos', 400, 80, 8, 6],
  ];
  const idAlimento = {};
  for (const [chave, nome, categoria, cal, prot, carb, gord] of alimentos) {
    const ref = db.collection('alimentos').doc(chave);
    await ref.set({
      nome,
      categoria,
      calorias: cal,
      proteinas: prot,
      carboidratos: carb,
      gorduras: gord,
    });
    idAlimento[chave] = { ref, nome, categoria, calorias: cal, proteinas: prot, carboidratos: carb, gorduras: gord };
  }
  console.log(`- alimentos: ${alimentos.length}`);

  // -------------------------------------------------------------------
  // Usuarios
  // -------------------------------------------------------------------
  const senhaDemo = '123456';

  // UIDs: reusa contas ja existentes no Authentication (mesmo UID),
  // garantindo que o login chegue ao perfil correto.
  const uidPorEmail = async (email, prefixo) => {
    try {
      const existente = await admin.auth().getUserByEmail(email);
      return existente.uid;
    } catch {
      return uidDemo(prefixo);
    }
  };

  const uidNutri = await uidPorEmail('gabriel@mvn.com', 'nutri');
  const uidPaciente = await uidPorEmail('ana@mvn.com', 'pac');

  await db.collection('usuarios').doc(uidNutri).set({
    nome: 'Dr. Gabriel',
    email: 'gabriel@mvn.com',
    telefone: '(19) 99888-1122',
    tipoUsuario: 'nutricionista',
    crn: 'CRN-3 45678',
    especializacao: 'Nutricao Clinica',
    onboardingCompleto: true,
    tutorialVisto: true,
    criadoEm: new Date(),
  });

  await db.collection('usuarios').doc(uidPaciente).set({
    nome: 'Ana Beatriz Souza',
    email: 'ana@mvn.com',
    telefone: '(19) 99777-3344',
    tipoUsuario: 'paciente',
    idade: 28,
    pesoAtual: 68.1,
    pesoMeta: 65,
    altura: 1.65,
    genero: 'Feminino',
    meta: 'Perda de peso',
    nivelAtividade: 'moderado',
    tipoDieta: 'Low carb',
    idNutricionista: uidNutri,
    alimentosFavoritos: ['Frango', 'Batata doce'],
    alimentosRejeitados: ['Peixe frito'],
    restricoes: ['Intolerancia a lactose'],
    condicoesMedicas: [],
    onboardingCompleto: true,
    tutorialVisto: true,
    criadoEm: new Date(),
  });
  console.log(`- usuarios: nutricionista=${uidNutri} paciente=${uidPaciente}`);

  // Usuarios de demonstracao no Firebase Authentication (opcional).
  // Funciona tanto no emulador quanto no projeto real (Admin SDK);
  // contas ja existentes sao atualizadas (senha padrao) em vez de falhar.
  if (process.argv.includes('--auth')) {
    try {
      const upsert = async (uid, email, nome) => {
        try {
          await admin.auth().updateUser(uid, { password: senhaDemo, displayName: nome });
        } catch {
          await admin.auth().createUser({ uid, email, password: senhaDemo, displayName: nome });
        }
      };
      await upsert(uidNutri, 'gabriel@mvn.com', 'Dr. Gabriel');
      await upsert(uidPaciente, 'ana@mvn.com', 'Ana Beatriz Souza');
      console.log(`- auth: gabriel@mvn.com / ana@mvn.com prontas (senha ${senhaDemo})`);
    } catch (erro) {
      console.warn(`- auth indisponivel: ${erro.message}`);
      console.warn('  Crie os usuarios manualmente no console (Authentication > Users).');
    }
  }

  // -------------------------------------------------------------------
  // Chat (conversa do prototipo, tela 14)
  // -------------------------------------------------------------------
  const idConversa = [uidNutri, uidPaciente].sort().join('__');
  const agora = new Date();
  const ontem = new Date(agora); ontem.setDate(ontem.getDate() - 1);

  await db.collection('conversas').doc(idConversa).set({
    participantes: [uidNutri, uidPaciente],
    nomes: { [uidNutri]: 'Dr. Gabriel', [uidPaciente]: 'Ana Beatriz Souza' },
    ultimaMensagem: 'oiii okei!',
    ultimaMensagemEm: ontem,
    criadoEm: ontem,
  });
  await db.collection('conversas').doc(idConversa).collection('mensagens').add({
    remetente: uidNutri,
    destinatario: uidPaciente,
    nomeRemetente: 'Dr. Gabriel',
    texto: 'ola bom dia! ja atualizei seu cardapio da semana!',
    lida: true,
    criadoEm: new Date(ontem.getFullYear(), ontem.getMonth(), ontem.getDate(), 11, 54, 0),
  });
  await db.collection('conversas').doc(idConversa).collection('mensagens').add({
    remetente: uidPaciente,
    destinatario: uidNutri,
    nomeRemetente: 'Ana Beatriz Souza',
    texto: 'oiii okei!',
    lida: true,
    criadoEm: new Date(ontem.getFullYear(), ontem.getMonth(), ontem.getDate(), 12, 9, 0),
  });
  console.log('- conversas: conversa Dr. Gabriel <-> Ana');

  // -------------------------------------------------------------------
  // Progresso: pesagens semanais + consumo diario
  // -------------------------------------------------------------------
  const pesagens = [
    [28, 70.5, 2050, 78],
    [21, 69.9, 1980, 82],
    [14, 69.2, 1920, 88],
    [7, 68.7, 1890, 91],
    [0, 68.1, 1900, 94],
  ];
  const consumo = [
    [1, 1950, 90], [2, 2100, 84], [3, 1980, 92], [4, 1850, 96],
    [5, 2050, 87], [6, 1930, 93], [8, 1870, 95], [9, 1990, 89],
    [10, 2020, 86], [11, 1880, 94], [12, 1910, 91], [13, 2060, 83],
  ];

  const progressoRef = db.collection('usuarios').doc(uidPaciente).collection('progresso');
  for (const [dias, peso, kcal, aderencia] of pesagens) {
    progressoRef.doc(dataRelativa(dias)).set({
      dataRegistro: dataRelativa(dias),
      peso,
      consumoCalorico: kcal,
      aderenciaPlano: aderencia,
      coposAgua: 6,
      atualizadoEm: new Date(),
    });
  }
  for (const [dias, kcal, aderencia] of consumo) {
    progressoRef.doc(dataRelativa(dias)).set({
      dataRegistro: dataRelativa(dias),
      consumoCalorico: kcal,
      aderenciaPlano: aderencia,
      coposAgua: 5,
      atualizadoEm: new Date(),
    }, { merge: true });
  }
  console.log(`- progresso: ${pesagens.length} pesagens + ${consumo.length} registros diarios`);

  // -------------------------------------------------------------------
  // Receitas do nutricionista
  // -------------------------------------------------------------------
  const ing = (chave, quantidadeG) => ({
    idAlimento: chave,
    nome: idAlimento[chave].nome,
    categoria: idAlimento[chave].categoria,
    calorias: idAlimento[chave].calorias,
    proteinas: idAlimento[chave].proteinas,
    carboidratos: idAlimento[chave].carboidratos,
    gorduras: idAlimento[chave].gorduras,
    quantidadeG,
    unidade: 'g',
  });

  const receitas = [
    {
      id: 'frango_brocolis',
      nome: 'Frango grelhado com brocolis',
      modoPreparo: 'Tempere o frango com limao e ervas; grelhe 6 min de cada lado. Cozinhe o brocolis no vapor por 5 min.',
      ingredientes: [ing('frango', 150), ing('brocolis', 100), ing('batataDoce', 120)],
    },
    {
      id: 'omelete',
      nome: 'Omelete de queijo',
      modoPreparo: 'Bata os ovos, despeje em frigideira antiaderente, adicione o queijo e dobre quando dourar.',
      ingredientes: [ing('ovo', 120), ing('queijo', 30)],
    },
    {
      id: 'mingau',
      nome: 'Mingau de aveia com banana',
      modoPreparo: 'Cozinhe a aveia com agua, misture o whey apos desligar o fogo e cubra com a banana em rodelas.',
      ingredientes: [ing('aveia', 40), ing('banana', 100), ing('whey', 30)],
    },
    {
      id: 'salmão_salada',
      nome: 'Salmao grelhado com salada',
      modoPreparo: 'Grelhe o salmao 4 min de cada lado; sirva com salada temperada com azeite e limao.',
      ingredientes: [ing('salmão', 140), ing('salada', 120)],
    },
    {
      id: 'tapioca',
      nome: 'Tapioca com ovo mexido',
      modoPreparo: 'Hidrate a goma, espalhe na frigideira quente ate firmar; recheie com ovo mexido.',
      ingredientes: [ing('tapioca', 60), ing('ovo', 60)],
    },
    {
      id: 'iougurte_maca',
      nome: 'Iogurte com maca',
      modoPreparo: 'Misture o iogurte com a maca picada.',
      ingredientes: [ing('iougurte', 150), ing('maca', 100)],
    },
  ];

  for (const r of receitas) {
    const totais = r.ingredientes.reduce(
      (acc, i) => ({
        calorias: acc.calorias + (i.calorias * i.quantidadeG) / 100,
        proteinas: acc.proteinas + (i.proteinas * i.quantidadeG) / 100,
        carboidratos: acc.carboidratos + (i.carboidratos * i.quantidadeG) / 100,
        gorduras: acc.gorduras + (i.gorduras * i.quantidadeG) / 100,
      }),
      { calorias: 0, proteinas: 0, carboidratos: 0, gorduras: 0 },
    );
    await db.collection('receitas').doc(r.id).set({
      uidNutricionista: uidNutri,
      nome: r.nome,
      modoPreparo: r.modoPreparo,
      ingredientes: r.ingredientes,
      calorias: round1(totais.calorias),
      proteinas: round1(totais.proteinas),
      carboidratos: round1(totais.carboidratos),
      gorduras: round1(totais.gorduras),
      status: 'aprovada',
      criadoEm: new Date(),
    });
  }
  console.log(`- receitas: ${receitas.length}`);

  // -------------------------------------------------------------------
  // Plano alimentar ativo com as refeicoes de segunda
  // -------------------------------------------------------------------
  const planoRef = db.collection('planos').doc('plano_demo_ana');
  await planoRef.set({
    uidPaciente,
    uidNutricionista: uidNutri,
    nomePlano: 'Plano Low Carb Semanal',
    objetivo: 'Perda de peso gradual (0.5 kg/semana)',
    ativo: true,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });

  const tipos = {
    cafeManha: { receita: 'mingau', horario: '07:30', rotulo: 'Café da Manhã' },
    lancheManha: { receita: 'iougurte_maca', horario: '10:00', rotulo: 'Lanche da Manhã' },
    almoco: { receita: 'frango_brocolis', horario: '12:30', rotulo: 'Almoço' },
    lancheTarde: { receita: 'tapioca', horario: '16:00', rotulo: 'Lanche da Tarde' },
    jantar: { receita: 'salmão_salada', horario: '19:30', rotulo: 'Jantar' },
    ceia: { receita: 'omelete', horario: '21:30', rotulo: 'Ceia' },
  };
  const receitaPorId = Object.fromEntries(receitas.map((r) => [r.id, r]));

  for (const [tipo, config] of Object.entries(tipos)) {
    const r = receitaPorId[config.receita];
    await planoRef.collection('refeicoes').doc(`segunda_${tipo}`).set({
      dia: 'segunda',
      tipo,
      rotuloTipo: config.rotulo,
      rotuloDia: 'Segunda',
      horario: config.horario,
      idReceita: r.id,
      nomeReceita: r.nome,
      calorias: r.ingredientes.reduce((s, i) => s + (i.calorias * i.quantidadeG) / 100, 0),
      proteinas: round1(r.ingredientes.reduce((s, i) => s + (i.proteinas * i.quantidadeG) / 100, 0)),
      carboidratos: round1(r.ingredientes.reduce((s, i) => s + (i.carboidratos * i.quantidadeG) / 100, 0)),
      gorduras: round1(r.ingredientes.reduce((s, i) => s + (i.gorduras * i.quantidadeG) / 100, 0)),
      ingredientes: r.ingredientes,
      concluidaEm: null,
      atualizadoEm: new Date(),
    });
  }
  console.log('- planos: Plano Low Carb Semanal (segunda completa, 6 refeicoes)');

  // -------------------------------------------------------------------
  // Consulta de exemplo
  // -------------------------------------------------------------------
  const proxima = new Date(agora); proxima.setDate(proxima.getDate() + 3);
  proxima.setHours(10, 0, 0, 0);
  await db.collection('consultas').add({
    uidNutricionista: uidNutri,
    uidPaciente,
    participantes: [uidNutri, uidPaciente],
    dataHora: proxima,
    status: 'confirmada',
    observacoes: 'Retorno - revisar plano alimentar',
    criadoEm: new Date(),
  });
  console.log('- consultas: retorno em 3 dias');

  // -------------------------------------------------------------------
  // Orientacao de exemplo
  // -------------------------------------------------------------------
  await db.collection('orientacoes').add({
    uidNutricionista: uidNutri,
    uidPaciente,
    categoria: 'positivo',
    texto: 'Excelente adesao ao plano nesta semana! Continue assim.',
    lida: false,
    criadoEm: new Date(),
  });
  console.log('- orientacoes: 1 feedback positivo');

  console.log('\nSeed concluido com sucesso!');
  console.log('  Nutricionista: gabriel@mvn.com (CRN-3 45678)');
  console.log('  Paciente .....: ana@mvn.com');
  if (process.argv.includes('--auth')) {
    console.log(`  Senha ........: ${senhaDemo} (contas criadas no Firebase Authentication)`);
  } else {
    console.log('  Obs: use --auth para criar tambem as contas de login, ou crie-as');
    console.log('       no console (Authentication > Users) com esses e-mails.');
  }
  console.log(`  UIDs (exemplo de execucao): ${uidNutri} | ${uidPaciente}`);
  process.exit(0);
}

/** Data local YYYY-MM-DD de hoje menos N dias. */
function dataRelativa(dias) {
  const d = new Date();
  d.setDate(d.getDate() - dias);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

const round1 = (v) => Math.round(v * 10) / 10;

async function apagarColecao(db, nome, antesDeApagar) {
  const snap = await db.collection(nome).limit(500).get();
  if (snap.empty) return;
  for (const doc of snap.docs) {
    if (antesDeApagar) await antesDeApagar(doc);
    await doc.ref.delete();
  }
  // Repete enquanto restarem documentos (limit 500 por rodada).
  const resta = await db.collection(nome).limit(1).get();
  if (!resta.empty) await apagarColecao(db, nome, antesDeApagar);
}

async function apagarSubcolecao(ref) {
  const snap = await ref.limit(500).get();
  for (const doc of snap.docs) await doc.ref.delete();
}

main().catch((erro) => {
  console.error('Falha no seed:', erro.message);
  process.exit(1);
});
