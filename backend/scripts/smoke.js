/**
 * Teste de sanidade da API sem Firebase (valida camada HTTP + erros).
 *
 * Com Firebase emulado/real disponivel, rode `node scripts/smoke.js`
 * depois do seed para validar os fluxos completos.
 *
 * Aqui, sem FIREBASE_DEMO_MODE e sem credenciais, o esperado e:
 *  - GET /            -> 200 com indice de rotas
 *  - GET /api         -> 200 com indice de rotas
 *  - GET /api/health  -> 503 (Firestore inacessivel) - JSON de erro
 *  - GET /api/progresso (sem token) -> 401 - JSON de erro
 *  - Rota inexistente -> 404 - JSON de erro
 */
'use strict';

const app = require('../src/app');

const servidor = app.listen(0, async () => {
  const porta = servidor.address().port;
  const base = `http://localhost:${porta}`;
  const ok = (condicao, mensagem) => {
    if (!condicao) {
      console.error(`FALHOU: ${mensagem}`);
      process.exit(1);
    }
    console.log(`ok: ${mensagem}`);
  };

  const chamar = async (caminho, opcoes = {}) => {
    const resposta = await fetch(`${base}${caminho}`, opcoes);
    const json = await resposta.json().catch(() => null);
    return { status: resposta.status, json };
  };

  try {
    // Raiz e indice de rotas.
    let r = await chamar('/');
    ok(r.status === 200 && r.json?.sucesso === true, `GET / -> ${r.status}`);
    r = await chamar('/api');
    ok(r.status === 200 && Boolean(r.json?.rotas), `GET /api -> ${r.status}`);

    // Autenticacao exigida: sem token, 401 em JSON.
    r = await chamar('/api/progresso');
    ok(
      r.status === 401 && r.json?.sucesso === false,
      `GET /api/progresso sem token -> ${r.status} (401 esperado)`,
    );

    // Rota inexistente: 404 em JSON.
    r = await chamar('/api/rota-inexistente');
    ok(
      r.status === 404 && r.json?.erro?.mensagem,
      `GET /api/rota-inexistente -> ${r.status} (404 esperado)`,
    );

    // Health tenta falar com Firestore; sem credenciais deve responder
    // 503 com mensagem util (e nao derrubar o processo).
    r = await chamar('/api/health');
    ok(
      (r.status === 200 || r.status === 503) && r.json?.sucesso !== undefined,
      `GET /api/health -> ${r.status} (200 com emulador, 503 sem)`,
    );

    // Login demo desativado fora do modo demo.
    r = await chamar('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'ana@mvn.com', senha: '123456' }),
    });
    ok(
      r.status === 404,
      `POST /api/auth/login fora do demo -> ${r.status} (404 esperado)`,
    );

    console.log('\nSmoke test da camada HTTP: TODOS PASSARAM');
    servidor.close(() => process.exit(0));
  } catch (erro) {
    console.error('Erro no smoke test:', erro.message);
    servidor.close(() => process.exit(1));
  }
});
