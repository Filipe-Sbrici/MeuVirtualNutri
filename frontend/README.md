# Meu Virtual Nutri — Frontend (Flutter)

Aplicativo Flutter do projeto MVN. Comunica-se com:
- **Firebase Authentication** (login/cadastro/redefinição — SDK cliente)
- **API REST Node.js** (dados — `Authorization: Bearer <id-token>` em todas as chamadas)

## Rodar

```bash
flutter pub get
flutter run
```

> Requer a API no ar (`../backend && npm start`) e o Firebase configurado — ver **[../CONFIGURACAO-FIREBASE.md](../CONFIGURACAO-FIREBASE.md)**.

### Endereços da API (automáticos)

| Ambiente | URL base |
|---|---|
| Emulador Android | `http://10.0.2.2:3000/api` |
| Web / Desktop | `http://localhost:3000/api` |
| Dispositivo físico | `--dart-define=API_HOST=<ip-da-maquina>` |

## Estrutura

```
lib/
├── main.dart               # bootstrap: Firebase + sessão + rotas de topo
├── core/
│   ├── api_client.dart     # HTTP + Bearer token + erros amigáveis
│   ├── firebase_config.dart# inicialização (--dart-define/emulador)
│   ├── app_config.dart     # URL da API, polling, timeouts
│   └── theme.dart          # paleta oficial do protótipo (Figma)
├── models/                 # Usuario, Mensagem, Progresso, Evolucao, Cardapio
├── services/               # Auth, Chat, Progresso, Evolucao, Onboarding,
│                           # Cardapio, Nutricionista
├── screens/                # login, cadastros, onboarding, paciente
│                           # (cardápio/bem-estar/progresso/chat/perfil/
│                           #  meu nutri/plano semanal/lista de compras),
│                           # nutricionista (home, pacientes, editor de
│                           # cardápio, receitas, agenda, relatórios)
└── widgets/                # bottom_nav, common (GradientHeader, MvnCard...)
```

## Testes

```bash
flutter test                                    # 28 testes widget/contrato JSON
flutter analyze                                 # análise estática (deve ficar limpa)

# E2E contra a API real. Requer a API no ar, o seed carregado e
# FIREBASE_DEMO_MODE=true no backend/.env (a VM de teste não tem sessão
# do Firebase Auth). Sem isso os casos são ignorados, não falham.
flutter test test/e2e_test.dart --dart-define=API_HOST=localhost
```

## Paleta

Extraída do `lib/assets/Paleta do projeto.pdf`: verde `#5ED360`, roxo `#43164F`, lilás `#E9D3EF`, fundo claro `#F0F0F0` — centralizada em `core/theme.dart`.
