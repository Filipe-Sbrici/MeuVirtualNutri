# Backend — API REST do Meu Virtual Nutri

API Node.js/Express que substituiu o acesso MySQL por **Firebase Admin SDK + Cloud Firestore**.

## Requisitos

- Node.js ≥ 18
- Um dos ambientes Firebase:
  - **Emulador local** (JDK 21+ e `firebase-tools`) — sem projeto real, ou
  - **Projeto Firebase real** (conta de serviço)

## Instalação

```bash
cd backend
npm install
copy .env.example .env   # (Linux/macOS: cp)
```

## Variáveis de ambiente (.env)

| Variável | Descrição |
|---|---|
| `PORT` | Porta HTTP (padrão 3000) |
| `FIREBASE_PROJECT_ID` | ID do projeto Firebase (ex.: `meu-virtual-nutri`) |
| `FIREBASE_SERVICE_ACCOUNT` | *(opcional)* JSON da conta de serviço em **uma linha** — alternativa ao `GOOGLE_APPLICATION_CREDENTIALS` |
| `FIREBASE_DEMO_MODE` | `true` apenas para testes sem Firebase: autentica como o e-mail do cabeçalho `x-demo-email`. **Nunca em produção.** |
| `FIRESTORE_EMULATOR_HOST` | `localhost:8080` para usar o emulador |
| `FIREBASE_AUTH_EMULATOR_HOST` | `localhost:9099` (emulador de Auth, usado pelo seed `--auth`) |
| `CORS_ORIGIN` | Origens permitidas (`*` em dev) |

Credencial em arquivo (produção):
```cmd
setx GOOGLE_APPLICATION_CREDENTIALS "C:\caminho\para\serviceAccount.json"
```

## Rodar

```bash
npm start          # produção
npm run dev        # com nodemon
npm run db:seed    # popula dados de demonstração (Dr. Gabriel + Ana)
npm run smoke      # teste da camada HTTP/segurança
npm run e2e        # E2E completo contra o Firebase real (82 verificações)
```

> O E2E (`scripts/e2e-firebase.js`) cria usuários de teste temporários
> no Firebase Authentication, exercita todos os fluxos pela API e remove
> tudo ao final. Requer a API no ar e a credencial configurada; a
> `FIREBASE_API_KEY` (chave pública do app Web) no `.env` é usada para
> trocar custom tokens por ID tokens.

### Com emuladores (desenvolvimento sem projeto real)

```bash
# terminal 1 — emuladores (requer JDK 21+ e firebase-tools)
firebase emulators:start --only firestore,auth --project demo-mvn

# terminal 2 — API apontando para o emulador
#   (.env com FIRESTORE_EMULATOR_HOST=localhost:8080)
npm start

# terminal 3 — dados de demonstração
npm run db:seed:auth   # seed + contas ana@mvn.com / gabriel@mvn.com (senha 123456)
```

## Estrutura

```
src/
├── server.js          # bootstrap HTTP
├── app.js             # Express (CORS, JSON, morgan, rotas, erros)
├── config/
│   ├── env.js         # variáveis de ambiente centralizadas
│   └── firebase.js    # Admin SDK (Firestore + Auth)
├── middlewares/
│   ├── auth.js        # Bearer token -> req.usuario; guards paciente/nutricionista
│   └── errorHandler.js# sempre responde JSON (AppError, erros Firebase)
├── controllers/       # HTTP <-> serviços (auth, perfil, chat, progresso,
│                      # evolucao, cardapio, nutricionista, consulta, relatorios)
├── services/          # regras de negócio (chat, progresso, evolucao, cardapio)
├── repositories/      # Firestore (usuario, conversa, progresso, plano,
│                      # consulta, orientacao)
├── routes/            # auth, perfil/onboarding, chat, progresso, evolucao,
│                      # cardapio, nutricionista, agenda
└── utils/             # AppError, validators, cálculos (Mifflin-St Jeor etc.)
```

## Autenticação

1. O Flutter cria/loga a conta no **Firebase Authentication**.
2. O Flutter chama `POST /api/auth/cadastro/*` (Bearer token) para materializar o perfil em `usuarios/{uid}`.
3. Cada requisição seguinte envia `Authorization: Bearer <id-token>`; o middleware valida com `verifyIdToken` e carrega o perfil.

## Contrato de resposta

```json
// sucesso
{ "sucesso": true, "dados": { ... } }
// erro
{ "sucesso": false, "erro": { "mensagem": "..." } }
```

Códigos: `200/201` ok · `400` validação · `401` sem/invalid token · `403` perfil sem permissão · `404` recurso/rota · `409` conflito (e-mail/CRN) · `503` Firebase indisponível.

## Dados de demonstração (seed)

- **Dr. Gabriel** — nutricionista, CRN-3 45678, Nutrição Clínica
- **Ana Beatriz Souza** — paciente, 68.1 kg → meta 65 kg, 5 pesagens + consumo diário, conversa no chat, plano Low Carb de segunda (6 refeições), consulta em 3 dias, orientação positiva

> O seed gera UIDs de demonstração a cada execução. Com `--auth` (emulador) cria também as contas `ana@mvn.com` / `gabriel@mvn.com` com senha `123456`.
