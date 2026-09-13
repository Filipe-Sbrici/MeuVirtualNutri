<h1> MeuVirtualNutri 
<img width="40.66" height="42.53" align=left alt="logo MVN" src="https://github.com/user-attachments/assets/cfc99f53-b953-4dce-9906-8cd905dc4592" />
</h1>
<h4> 
  
  *Uma alimentação mais saudável para todos*
</h4>

---

## 📌 Sobre o projeto

O **Meu Virtual Nutri (MVN)** consiste em um ambiente digital que conecta o **nutricionista** e o **paciente**. O projeto surge como uma resposta ao aumento na procura por profissionais na área, com a intenção de agilizar o trabalho do nutricionista ao deixar as informações e contato do paciente mais acessíveis e de facilitar a rotina do paciente, ao permitir que ele tenha um acesso mais direto e fácil à sua rotina alimentar e ao seu acompanhamento profissional.

O sistema foi desenhado separando a jornada em dois perfis principais:

### 🩺 Perfil do Nutricionista:
- **Segurança e Registro:** Cadastro corporativo com validação de CRN e especialização.
- **Dashboard Centralizado:** Atalhos de acesso rápido para gestão de agenda, lista de clientes e chat.
- **Segurança Clínica na UI:** Destaque visual no topo da tela para restrições alimentares, alergias e metas do paciente.
- **Editor de Cardápio e Receitas:** Montagem de planos alimentares semanais e biblioteca de receitas com cálculo automático de macronutrientes.
- **UX Conversacional:** Chat interno para envio de feedbacks imediatos sobre refeições e orientações.
- **Painel Analítico:** Relatórios de evolução de peso, aderência ao plano e frequência de consultas.

### 🥗 Perfil do Paciente:
- **Cronograma Diário Interativo:** Plano alimentar visual em formato de checklist vertical por horários.
- **Micro-interações de Hábitos:** Contador tátil de consumo de água (hidratação) e registro diário de humor.
- **Acompanhamento de Evolução:** Gráficos interativos de peso, IMC automático e histórico de progresso.
- **Lista de Compras:** Geração automática da lista de ingredientes com base no plano semanal.
- **Compartilhamento de Receitas:** Envio de receitas caseiras para validação e aprovação do nutricionista.
- **Busca e Favoritos:** Opção de sinalizar alimentos preferidos para o nutricionista.

---

## 👥 Sobre nós

Este software é desenvolvido como **Trabalho de Conclusão de Curso (TCC)** do curso de Ensino Médio Integrado ao Técnico em Desenvolvimento de Sistemas na **ETEC Euro Albino de Souza** (Mogi Guaçu / SP).

### 🎓 Alunos Responsáveis:
- Emilly Christinny Alves de Jesus
- Filipe Soares Sbrici
- Gabriel Ferrareiz da Costa
- Isaque Machado
- João Vitor Daltio

### 👨‍🏫 Professores Orientadores:
- Prof. Marcus Bretas
- Prof. Pedro Amalfi

---

## 🛠️ Tecnologias

O projeto utiliza uma arquitetura moderna voltada para desempenho móvel, escalabilidade em nuvem e alta confiabilidade:

- **Frontend:** [Flutter](https://flutter.dev/) & [Dart](https://dart.dev/) (Android, iOS, Web e Desktop)
- **Backend:** [Node.js](https://nodejs.org/) com [Express](https://expressjs.com/)
- **Autenticação:** [Firebase Authentication](https://firebase.google.com/docs/auth) (Login, Cadastro e Redefinição de Senha)
- **Banco de Dados:** [Cloud Firestore](https://firebase.google.com/docs/firestore) (NoSQL em tempo real e escalável)
- **Comunicação:** API REST com payloads JSON e Bearer Token
- **Integração e Entrega Contínua:** [GitHub Actions](https://github.com/features/actions) (CI/CD automatizado)
- **UI/UX & Prototipagem:** [Figma](https://www.figma.com/)

Para mais informações técnicas, consulte o [Estudo de Viabilidade na Wiki](https://github.com/Filipe-Sbrici/MeuVirtualNutri/wiki/2.-Estudo-de-Viabilidade).

---

## 🚀 Status de Desenvolvimento

- **Status Atual:** *Fase de Desenvolvimento de Código e Integração Contínua (CI/CD)*
- O projeto concluiu com sucesso a modelagem de requisitos, migração arquitetural para Firebase/Firestore, suíte completa de testes automatizados e pipeline de integração contínua (CI/CD).
- Um protótipo navegável de alta fidelidade do projeto foi inteiramente desenhado no Figma:
  - 🎨 **Link Direto do Figma:** [Acessar Protótipo Interativo no Figma](https://www.figma.com/make/gLCupjo0KZUrHNLI9NHuNC/mvn?p=f&preview-route=%2Flogin)
  - 📖 **Documentação do Protótipo:** [Página de Prototipagem na Wiki](https://github.com/Filipe-Sbrici/MeuVirtualNutri/wiki/4.-Prototipagem) (contém imagens e descrição detalhada de cada fluxo).

---

## 🏗️ Arquitetura do Sistema (v2 — Firebase)

```
Flutter / Dart (Mobile & Web)
   │
   ├── Firebase Authentication (Login, Cadastro, Recuperação de Senha)
   │
   └── REST API / JSON ──► Node.js (Express) ──► Firebase Admin SDK ──► Cloud Firestore
```

- **Autenticação:** O aplicativo comunica-se diretamente com o Firebase Authentication (SDK cliente). A API Node.js valida o `Bearer <id-token>` em cada requisição através do Admin SDK.
- **Dados:** Todo acesso ao Firestore passa pela API REST protegida. As **Security Rules** do Firestore estão fechadas para acesso direto de clientes (`firestore.rules`), garantindo governança e segurança centralizadas.

---

## 📁 Estrutura do Repositório

```
mvn/
├── .github/workflows/       # Pipelines de CI/CD (GitHub Actions)
├── backend/                 # API REST Node.js + Firebase Admin SDK
│   ├── src/
│   │   ├── config/          # env.js, firebase.js
│   │   ├── middlewares/     # auth (Bearer token), errorHandler
│   │   ├── controllers/     # Camada de controle HTTP
│   │   ├── services/        # Regras de negócio da aplicação
│   │   ├── repositories/    # Acesso e queries ao Cloud Firestore
│   │   ├── routes/          # Rotas Express (/api)
│   │   └── utils/           # Validadores, cálculos nutricionais e erros
│   └── scripts/             # seed-firestore.js, smoke.js
├── frontend/                # Aplicativo Flutter
│   ├── lib/
│   │   ├── core/            # ApiClient, temas (claro/escuro), config Firebase
│   │   ├── models/          # Modelos de dados (Usuario, Cardapio, Progresso...)
│   │   ├── services/        # Serviços de comunicação com a API
│   │   ├── screens/         # Telas de Paciente, Nutricionista e Autenticação
│   │   └── widgets/         # Componentes visuais compartilhados
│   └── test/                # Suíte de testes unitários e de widgets
├── database/                # (legado) Esquema MySQL original mantido para histórico do TCC
├── firestore.rules          # Regras de segurança do Firestore
├── firestore.indexes.json   # Índices compostos
└── firebase.json            # Configuração de emuladores locais
```

---

## ⚡ Como Rodar o Projeto

### 1. Pré-requisitos
- [Node.js 18+](https://nodejs.org/)
- [Flutter SDK 3.x](https://flutter.dev/)
- [Firebase CLI](https://firebase.google.com/docs/cli) (opcional, para emulador)

### 2. Backend (Node.js)
```bash
cd backend
npm install
cp .env.example .env   # Configure as credenciais do Firebase
npm run db:seed        # Popula o banco com dados de demonstração
npm start              # Inicia o servidor na porta configurada
```

### 3. Frontend (Flutter)
```bash
cd frontend
flutter pub get
flutter run
```

> Para orientações detalhadas de ambiente e credenciais, consulte o arquivo **[CONFIGURACAO-FIREBASE.md](CONFIGURACAO-FIREBASE.md)** e **[backend/README.md](backend/README.md)**.

---

## 📱 Telas Implementadas (Protótipo → Aplicativo)

### Autenticação e Onboarding
| Protótipo | Tela no App | Status |
|---|---|---|
| 4.5.1 Login | `login_screen` | ✅ Firebase Auth + link "esqueci a senha" |
| 4.5.2 Criação de conta Cliente | `cadastro_paciente_screen` | ✅ Cadastro completo |
| 4.5.3 Criação de conta Nutricionista | `cadastro_nutricionista_screen` | ✅ CRN + especialização |
| 4.5.4 Recuperação de senha | Diálogo de e-mail | ✅ `sendPasswordResetEmail` |
| 4.5.5–4.5.10 Onboarding (5 etapas) | `onboarding_screen` | ✅ Nutricionista → Dados → Estilo de Vida → Perfil → Restrições |
| 4.5.11 Tutorial interativo | 6ª etapa do onboarding | ✅ Apresentação dos recursos |

### Área do Paciente
| Protótipo | Tela no App | Status |
|---|---|---|
| 4.5.12 Central (Cardápio + Bem-Estar) | `paciente_home_screen` + `bem_estar_screen` | ✅ Checklist diário, hidratação, humor e alertas |
| 4.5.13 Plano alimentar semanal | `PlanoSemanalScreen` | ✅ Navegação por dias e detalhes de refeições |
| 4.5.14 Progresso e Evolução | `progresso_screen` + `evolucao_screen` | ✅ Registro de peso e gráficos com `fl_chart` |
| 4.5.15 Meu nutricionista | `meu_nutri_screen` | ✅ Contato, orientações recebidas e agenda |
| 4.5.16 Chat | `chat_screen` | ✅ Mensagens em tempo real com envio otimista |
| 4.5.17 Vídeo chamada | `_VideochamadaScreen` | ✅ Interface de chamada (câmera, microfone) |
| 4.5.18 Lista de compras | `ListaComprasScreen` | ✅ Gerada automaticamente a partir do cardápio |
| 4.5.19 Perfil do paciente | `perfil_screen` | ✅ Edição de dados, cálculo de IMC e configurações |

### Área do Nutricionista
| Protótipo | Tela no App | Status |
|---|---|---|
| 4.5.20 Inicial | `nutricionista_home_screen` | ✅ Atalhos rápidos e visão geral |
| 4.5.21 Vinculação de paciente | Diálogo de vinculação | ✅ Vínculo direto por e-mail |
| 4.5.22 Perfil clínico do paciente | `PerfilClinicoScreen` | ✅ Restrições em destaque, histórico e metas |
| 4.5.23 Editor de cardápio | `EditorCardapioScreen` | ✅ Gestão das 42 refeições semanais |
| 4.5.24 Biblioteca de receitas | `ReceitasTab` + `EditorReceitaScreen` | ✅ Cálculo automático de macronutrientes |
| 4.5.25 Receitas compartilhadas | `CompartilharReceitaScreen` | ✅ Aprovação/recusa com justificativa clínica |
| 4.5.26 Agenda de consultas | `AgendaTab` | ✅ Gestão de horários, confirmação e cancelamento |
| 4.5.27 Relatórios e análise | `RelatoriosScreen` | ✅ Variação de peso, aderência e frequência |
| 4.5.28 Configurações do profissional | `perfil_screen` | ✅ Atualização de dados cadastrais e CRN |

---

## 🧪 Testes Automatizados e CI/CD

O projeto conta com uma suíte de testes robusta e integração contínua configurada via **GitHub Actions** (`.github/workflows/ci_cd.yml`):

### Como rodar os testes localmente:

```bash
# 1. Backend (testes de rotas HTTP, segurança e middlewares)
cd backend && npm test

# 2. Frontend Flutter (49 testes de widget, telas e contratos de API)
cd frontend && flutter test

# 3. Testes E2E (com API em execução)
cd backend && npm run e2e
```

### Pipeline Automatizado (GitHub Actions):
- **Frontend CI:** Execução automática da suíte completa de testes no Flutter (`flutter test --coverage`).
- **Backend CI:** Validação de rotas, middlewares e *smoke tests* no Node.js (`npm test`).
- **CD (Web Release):** Compilação automática da aplicação Web (`flutter build web --release`) e publicação dos artefatos em cada push na branch principal.

---

## 🔒 Segurança e Boas Práticas

- **Autenticação Forte:** Credenciais gerenciadas pelo Firebase Auth com criptografia e tokens JWT de curta duração.
- **Autorização na API:** Vínculos e dados clínicos são validados no backend antes de qualquer operação.
- **Defesa em Profundidade:** Regras do Firestore (`firestore.rules`) bloqueadas para acesso cliente não autenticado.
- **Privacidade de Credenciais:** Variáveis sensíveis e chaves de API isoladas em `.env` e fora do versionamento público.

---

## 📚 Wiki do Projeto

Toda a documentação técnica, atas de reuniões, levantamento de requisitos, diagramas UML, modelagem e relatórios estão centralizados na Wiki oficial:

<p align="center">
  <b><a href="https://github.com/Filipe-Sbrici/MeuVirtualNutri/wiki">📖 Acessar a Wiki Oficial do Projeto no GitHub</a></b>
</p>

---

<h5 align="center">
  Meu Virtual Nutri • ETEC Euro Albino de Souza (Mogi Guaçu / SP)
</h5>
