# Configuração do Firebase — Meu Virtual Nutri

Guia completo para conectar o projeto ao Firebase (Authentication + Cloud Firestore), tanto para **desenvolvimento com emuladores** quanto para **produção com projeto real**.

---

## 1. Serviços utilizados e por quê

| Serviço | Uso | Por que |
|---|---|---|
| **Firebase Authentication** | cadastro, login, logout, redefinição de senha, sessão | Gerenciamento seguro de credenciais sem expor senhas à API; tokens `id-token` assinados pelo Google |
| **Cloud Firestore** | TODOS os dados do app (perfis, planos, chat, progresso, agenda, receitas) | Banco NoSQL em tempo real, escalável, com regras de segurança |

Não usamos: Realtime Database (Firestore é o sucessor recomendado), Cloud Messaging/FCM (notificações ficam como evolução futura), Hosting/Functions (a API Node.js é o backend exigido pela arquitetura REST do TCC).

### Arquitetura resultante

```
Flutter ──► Firebase Authentication (SDK cliente)
Flutter ──► REST/JSON ──► Node.js ──► Admin SDK ──► Firestore (regras fechadas p/ clientes)
```

---

## 2. Criar o projeto Firebase (uma vez)

1. Acesse https://console.firebase.google.com → **Adicionar projeto**.
2. Nome sugerido: `Meu Virtual Nutri` (o ID gerado, ex. `meu-virtual-nutri`, é o `FIREBASE_PROJECT_ID`).
3. Google Analytics: opcional (pode desativar).

### 2.1 Habilitar o Authentication

1. Console → **Build → Authentication → Get started**.
2. Aba **Sign-in method** → habilite **Email/Password**.
3. (Opcional, para testes) Aba **Templates** de e-mail em português.

### 2.2 Criar o Cloud Firestore

1. Console → **Build → Firestore Database → Create database**.
2. Localização: `southamerica-east1` (São Paulo).
3. **Modo de produção** (as regras do projeto já são seguras — ver seção 5).

---

## 3. Configurar o BACKEND (Node.js)

O backend usa o **Admin SDK** — precisa de uma **conta de serviço**.

1. Console → ⚙️ **Configurações do projeto → Contas de serviço** → botão **Gerar nova chave privada** → baixa um `serviceAccount-XXXX.json`.
2. Guarde o arquivo **fora do repositório** (ex.: `C:\firebase\mvn-serviceAccount.json`).
3. No `backend/.env`:

```env
PORT=3000
FIREBASE_PROJECT_ID=meu-virtual-nutri
CORS_ORIGIN=*
```

4. Aponte a variável de ambiente do sistema para o arquivo (Windows):

```cmd
setx GOOGLE_APPLICATION_CREDENTIALS "C:\firebase\mvn-serviceAccount.json"
```

   Alternativa sem variável de sistema (útil em PaaS): cole o **conteúdo do JSON em uma única linha** em `FIREBASE_SERVICE_ACCOUNT=...` dentro do `.env`.

5. Teste:

```bash
cd backend
npm start          # deve logar "Firestore conectado com sucesso."
npm run db:seed    # popula os dados de demonstração
npm run smoke      # valida a camada HTTP
```

> **Nunca** comite o `serviceAccount.json` nem o `.env` (o `.gitignore` do backend já cobre).

---

## 4. Configurar o FRONTEND (Flutter)

### 4.1 Registro dos apps no Firebase

Console → ⚙️ Configurações do projeto → **Seus apps**:
- **Android** (ícone 🤖): pacote `com.example.mvn_app` (confira em `frontend/android/app/build.gradle.kts` → `applicationId`) → baixar `google-services.json` → colocar em `frontend/android/app/`.
- **iOS** (se for usar): baixar `GoogleService-Info.plist` → `frontend/ios/Runner/`.
- **Web** (opcional): anote a `apiKey`, `appId`, `messagingSenderId` do config.

### 4.2 Configuração Dart (duas opções)

**Opção A — CLI FlutterFire (recomendada):**

```bash
dart pub global activate flutterfire_cli
cd frontend
flutterfire configure    # seleciona o projeto e as plataformas
```

Isso gera `lib/firebase_options.dart`, baixa o `google-services.json` automaticamente e ajusta o Gradle. Então ajuste `main.dart`:

```dart
// lib/main.dart
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MvnApp());
}
```

**Opção B — google-services.json manual (sem CLI):**

1. Coloque o `google-services.json` em `frontend/android/app/`.
2. Descomente a linha do plugin `com.google.gms.google-services` em **dois** arquivos (já marcadas com comentário "Firebase:"):
   - `frontend/android/settings.gradle.kts`
   - `frontend/android/app/build.gradle.kts`
3. Pronto: `flutter run` (Android injeta a configuração nativamente; `FirebaseConfig.inicializar()` já cuida disso).

**Opção C — dart-define (sem arquivos de configuração), já suportada pelo projeto:**

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=AIza... \
  --dart-define=FIREBASE_PROJECT_ID=meu-virtual-nutri \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=1234567890 \
  --dart-define=FIREBASE_APP_ID=1:1234567890:web:abcdef
```

Esses valores vêm do objeto `firebaseConfig` exibido no console (Configurações do projeto → Seus apps → Web). O arquivo `lib/core/firebase_config.dart` lê esses defines. **No Android/iOS com `google-services.json`/`GoogleService-Info.plist` presentes, nenhuma opção extra é necessária** — a configuração nativa é injetada automaticamente.

### 4.3 API_HOST (dispositivo físico)

O app chama a API em `10.0.2.2:3000` (emulador Android) ou `localhost:3000`. Em celular físico, informe o IP da máquina:

```bash
flutter run --dart-define=API_HOST=192.168.0.15
```

---

## 5. Regras de segurança e índices

Os arquivos já estão prontos na raiz:

- `firestore.rules` — Firestore **totalmente fechado** para clientes (todo acesso passa pela API com Admin SDK, que aplica autorização por vínculo paciente↔nutricionista).
- `firestore.indexes.json` — índices compostos das consultas.

Publicar no projeto real (requer `firebase-tools`):

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Ou colar manualmente: console → Firestore → Regras/Índices.

---

## 6. Desenvolvimento sem projeto real (emuladores)

Requisitos: JDK 21+ e Node 18+.

```bash
npm i -g firebase-tools

# terminal 1 — emuladores (Auth :9099, Firestore :8080, UI :4000)
firebase emulators:start --only firestore,auth --project demo-mvn
```

`backend/.env`:

```env
FIRESTORE_EMULATOR_HOST=localhost:8080
FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
```

```bash
# terminal 2 — API
cd backend && npm start

# terminal 3 — seed + contas de teste no Auth emulado
npm run db:seed:auth    # ana@mvn.com / gabriel@mvn.com — senha 123456
```

Flutter apontando para os emuladores:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=demo \
  --dart-define=FIREBASE_PROJECT_ID=demo-mvn \
  --dart-define=FIREBASE_APP_ID=demo \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=demo \
  --dart-define=AUTH_EMULATOR_HOST=localhost:9099
```

---

## 7. Checklist final antes de entregar

- [x] Authentication Email/Password habilitado
- [x] Firestore criado em modo produção
- [x] `firestore.rules` + `firestore.indexes.json` publicados
- [x] `serviceAccount.json` no backend (via `GOOGLE_APPLICATION_CREDENTIALS` ou `.env`)
- [x] `google-services.json` em `frontend/android/app/` + plugin Gradle ativo
- [x] `firebase_options.dart` gerado pela CLI FlutterFire
- [x] Seed executado (`npm run db:seed -- --auth`) — contas `ana@mvn.com` / `gabriel@mvn.com` (senha `123456`)
- [x] `npm run smoke`, `flutter test` e `npm run e2e` passando
- [ ] Nenhum segredo commitado (`git status` limpo de `.env`/JSONs de chave) — **verifique antes do push**
