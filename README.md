# Meu Virtual Nutri (MVN)

**Uma alimentação mais saudável para todos**

Aplicativo TCC (ETEC Euro Albino de Souza) que conecta **nutricionistas** e **pacientes**: plano alimentar com checklist diário, progresso de peso com gráficos, chat, agenda de consultas, lista de compras e painel analítico do profissional.

---

## Arquitetura (v2 — Firebase)

```
Flutter / Dart (mobile)
   │
   ├── Firebase Authentication  (login, cadastro, redefinição de senha)
   │
   └── REST API / JSON  ──►  Node.js (Express)  ──►  Firebase Admin SDK  ──►  Cloud Firestore
```

- **Autenticação**: o app fala **direto** com o Firebase Authentication (SDK cliente). A API Node.js valida o `Bearer <id-token>` de cada requisição com o Admin SDK.
- **Dados**: todo acesso ao Firestore passa pela API (Admin SDK). As **Security Rules** do Firestore estão **fechadas para clientes** (defesa profunda) — ver `firestore.rules`.
- **MySQL foi totalmente removido.**

### Estrutura do repositório

```
mvn/
├── backend/                 # API REST Node.js + Firebase Admin SDK
│   ├── src/
│   │   ├── config/          # env.js, firebase.js
│   │   ├── middlewares/     # auth (Bearer token), errorHandler
│   │   ├── controllers/     # HTTP <-> serviço
│   │   ├── services/        # regras de negócio
│   │   ├── repositories/    # acesso ao Firestore
│   │   ├── routes/          # rotas Express (/api)
│   │   └── utils/           # validadores, cálculos nutricionais, AppError
│   └── scripts/             # seed-firestore.js, smoke.js
├── frontend/                # Aplicativo Flutter (Android/iOS/Web/Desktop)
│   └── lib/
│       ├── core/            # ApiClient (token), tema, config Firebase
│       ├── models/          # Usuario, Mensagem, Progresso, Evolucao, Cardapio...
│       ├── services/        # AuthService, Chat, Progresso, Evolucao, Onboarding...
│       ├── screens/         # Telas (ver mapa abaixo)
│       └── widgets/         # componentes compartilhados
├── database/                # (legado) esquema MySQL original — mantido apenas
│                            # como referência histórica do TCC; NÃO é usado.
├── firestore.rules          # Regras de segurança (Firestore fechado p/ clientes)
├── firestore.indexes.json   # Índices compostos
└── firebase.json            # Configuração de emuladores
```

> **Importante:** a pasta `database/` contém o esquema SQL original usado na fase anterior do projeto. O aplicativo **não** depende mais dele; os arquivos ficam no repositório como documentação da modelagem inicial. Para excluir, remova a pasta e a referência neste README.

---

## Como rodar (visão geral)

1. **Backend** — `cd backend && npm install && cp .env.example .env` (ajuste o Firebase) && `npm start`
2. **Seed** — `npm run db:seed` (popula Firestore de demonstração)
3. **Frontend** — `cd frontend && flutter pub get && flutter run`

Guia completo com as duas opções de ambiente (emulador local e projeto Firebase real): **[backend/README.md](backend/README.md)** e **[CONFIGURACAO-FIREBASE.md](CONFIGURACAO-FIREBASE.md)**.

---

## Telas implementadas (protótipo → app)

### Autenticação e onboarding
| Protótipo | Tela | Status |
|---|---|---|
| 4.5.1 Login | `login_screen` | ✅ Firebase Auth + link "esqueci a senha" |
| 4.5.2 Criação de conta Cliente | `cadastro_paciente_screen` | ✅ |
| 4.5.3 Criação de conta Nutricionista | `cadastro_nutricionista_screen` | ✅ CRN + especialização |
| 4.5.4 Recuperação de senha | diálogo de e-mail | ✅ `sendPasswordResetEmail` |
| 4.5.5–4.5.10 Onboarding (5 etapas) | `onboarding_screen` | ✅ nutricionista→dados→estilo de vida→perfil alimentar→restrições |
| 4.5.11 Tutorial interativo | 6ª etapa do onboarding | ✅ |

### Paciente
| Protótipo | Tela | Status |
|---|---|---|
| 4.5.12 Central (Cardápio + Bem-Estar) | `paciente_home_screen` + `bem_estar_screen` | ✅ checklist diário, água, humor, banner de não lidas |
| 4.5.13 Plano alimentar semanal | `PlanoSemanalScreen` | ✅ navegação por dia, ingredientes |
| 4.5.14 Progresso e Evolução | `progresso_screen` + `evolucao_screen` | ✅ registro de peso, gráficos (fl_chart) |
| 4.5.15 Meu nutricionista | `meu_nutri_screen` | ✅ Contato/Orientações/Agenda |
| 4.5.16 Chat | `chat_screen` | ✅ polling, balões, envio otimista |
| 4.5.17 Vídeo chamada | `_VideochamadaScreen` | ✅ interface simulada (mic/câmera/desligar) |
| 4.5.18 Lista de compras | `ListaComprasScreen` | ✅ gerada do plano, por categoria |
| 4.5.19 Perfil do paciente | `perfil_screen` | ✅ editar dados, IMC, excluir conta |

### Nutricionista
| Protótipo | Tela | Status |
|---|---|---|
| 4.5.20 Inicial (atalhos + "+") | `nutricionista_home_screen` | ✅ |
| 4.5.21 Cadastro/vinculação de paciente | diálogo "+" | ✅ vincula por e-mail |
| 4.5.22 Perfil clínico do paciente | `PerfilClinicoScreen` | ✅ dados, restrições em destaque, orientações |
| 4.5.23 Editor de cardápio | `EditorCardapioScreen` | ✅ dia → refeição → receita, barra das 42 refeições |
| 4.5.24 Biblioteca de receitas | `ReceitasTab` + `EditorReceitaScreen` | ✅ macros calculados automaticamente |
| 4.5.25 Receitas compartilhadas | aba "Compartilhadas" + `CompartilharReceitaScreen` | ✅ paciente envia (macros da base de alimentos); nutri aprova/recusa com justificativa |
| 4.5.26 Agenda | `AgendaTab` | ✅ abrir horários (só futuros), concluir e cancelar consultas |
| 4.5.27 Relatórios e análise | `RelatoriosScreen` | ✅ variação de peso em 30d, aderência, frequência |
| 4.5.28 Configurações do nutricionista | edição de perfil via API | ✅ (`PUT /api/perfil/perfil`) |

---

## Migração MySQL → Firestore (mapeamento)

| MySQL | Cloud Firestore |
|---|---|
| `usuario` + `paciente` + `nutricionista` | `usuarios/{uid}` — doc achatado, ID = UID do Firebase Auth |
| `mensagem` | `conversas/{uidA__uidB}/mensagens/{autoId}` |
| `progresso` | `usuarios/{uid}/progresso/{YYYY-MM-DD}` (1 doc/dia) |
| `plano_alimentar` | `planos/{id}` |
| `refeicao` + `refeicao_alimento` | `planos/{id}/refeicoes/{dia_tipo}` (ingredientes embutidos) |
| `alimento` | `alimentos/{id}` |
| `favoritos`, `paciente_restricao` | arrays no documento do paciente |
| `consulta` | `consultas/{id}` |
| `restricao` | catálogo fixo no app + arrays no paciente |
| *(novo)* biblioteca de receitas | `receitas/{id}` (status aprovada/pendente/recusada) |
| *(novo)* orientações/feedbacks | `orientacoes/{id}` |

## API REST (resumo)

Autenticação: `Authorization: Bearer <firebase-id-token>` em todas as rotas (exceto `/api` e `/api/health`).

- `POST /api/auth/cadastro/paciente|nutricionista` — cria perfil pós-Firebase-Auth
- `GET  /api/auth/perfil` — inclui os dados clínicos (idade, peso, altura, restrições) usados pela tela de Perfil
- Onboarding: `GET/POST /api/onboarding/...` (nutricionistas, dados, estilo de vida, perfil alimentar, restrições, tutorial)
- Perfil: `PUT|DELETE /api/perfil/perfil`
- Chat: `GET /api/chat/conversa/:uidContato`, `POST /api/chat/mensagens`, `GET /api/chat/contato`, `GET /api/chat/nao-lidas`
- Progresso: `GET /api/progresso` (traz `hoje` com água/humor), `POST /api/progresso/peso`, `DELETE /api/progresso/peso/:data`, `POST /api/progresso/agua|humor`
- Evolução: `GET /api/evolucao/:uidPaciente?periodo=`
- Cardápio: `GET /api/cardapio/hoje|semanal|lista-compras`, `POST /api/cardapio/hoje/check`
- Receitas do paciente: `GET|POST /api/minhas-receitas`; base de alimentos: `GET /api/alimentos`
- Nutricionista: `GET|POST /api/nutricionista/pacientes`, `*/pacientes/:uid/plano`, `*/receitas`, `GET /api/nutricionista/relatorios`, `POST /api/nutricionista/orientacoes`
- Agenda: `GET|POST /api/consultas`, `POST /api/consultas/:id/confirmar|concluir|cancelar`

Índice completo em `GET /api`.

**Autorização aplicada na API** (não só na UI): conversa e agenda só existem entre um paciente e o **seu** nutricionista vinculado; receitas, planos e consultas só podem ser lidos/alterados por quem é dono do vínculo.

## Testes

```bash
# Backend (camada HTTP + segurança, sem Firebase)
cd backend && npm run smoke

# Flutter (28 testes de widget/contrato JSON, sem rede)
cd frontend && flutter test

# E2E completo contra o Firebase real (API no ar + credencial no ambiente)
#   82 verificações: cadastro, onboarding, chat, progresso, cardápio,
#   receitas, agenda, orientações, relatórios, perfil, segurança e
#   isolamento entre nutricionistas.
cd backend && npm run e2e

# E2E Flutter->API->Firestore (requer API no ar + seed carregado).
# A VM de teste não tem sessão do Firebase Auth, então a API precisa
# aceitar o modo demo: backend/.env -> FIREBASE_DEMO_MODE=true.
# Sem isso os casos são IGNORADOS (não falham).
cd frontend && flutter test test/e2e_test.dart --dart-define=API_HOST=localhost
```

## Segurança

- Senhas geridas pelo Firebase Authentication (hash/bcrypt do lado do Google) — a API **nunca** vê senhas.
- Firestore fechado para clientes por `firestore.rules`; toda autorização (paciente↔nutricionista vinculado) é verificada na API.
- Token de sessão injetado automaticamente pelo `ApiClient` a cada requisição.
- Nenhuma chave privada no código; credenciais ficam em `.env` (backend) e nos arquivos gerados pela CLI FlutterFire (frontend).

## Alunos

Emilly Christinny Alves de Jesus • Filipe Soares Sbrici • Gabriel Ferrareiz da Costa • Isaque Machado • João Vitor Daltio

**Orientadores:** Prof. Marcus Bretas • Prof. Pedro Amalfi — ETEC Euro Albino de Souza (Mogi Guaçu/SP)
