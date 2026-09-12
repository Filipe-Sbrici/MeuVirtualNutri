/// Teste de ponta a ponta: telas Flutter -> HTTP real -> API Node ->
/// Firestore (ou emulador).
///
/// Requisitos para rodar:
///
///   1. API no ar:
///        cd backend && npm start
///   2. Seed carregado:
///        npm run db:seed
///   3. API aceitando chamadas sem token Firebase, porque a VM de teste
///      nao tem sessao do Firebase Authentication:
///        backend/.env -> FIREBASE_DEMO_MODE=true
///      (em modo demo a API autentica como o paciente de demonstracao
///      `ana@mvn.com`.)
///   4. Teste (com API_HOST explicito para nao cair no 10.0.2.2):
///        cd frontend && flutter test test/e2e_test.dart \
///            --dart-define=API_HOST=localhost
///
/// Sem o passo 1 ou o passo 3 os casos sao MARCADOS COMO IGNORADOS (e
/// nao como falha), porque a configuracao segura de producao
/// (FIREBASE_DEMO_MODE=false) impede autenticar daqui.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mvn_app/core/api_client.dart';
import 'package:mvn_app/core/theme.dart';
import 'package:mvn_app/screens/chat_screen.dart';
import 'package:mvn_app/screens/evolucao_screen.dart';
import 'package:mvn_app/screens/progresso_screen.dart';
import 'package:mvn_app/services/api_services.dart';
import 'package:mvn_app/services/chat_service.dart';

Widget _envolver(Widget tela) =>
    MaterialApp(theme: AppTheme.tema, home: tela);

/// A tela ainda mostra o indicador de carregamento?
///
/// `CarregandoView` usa `CircularProgressIndicator`; a barra de meta do
/// Progresso e um `LinearProgressIndicator` e por isso NAO serve como
/// sinal de carregamento.
bool _carregando(WidgetTester tester) =>
    tester.any(find.byType(CircularProgressIndicator));

/// Monta a tela e aguarda a requisicao real terminar.
///
/// Todo o trabalho acontece dentro de `runAsync`: fora dele o HTTP real
/// nao progride e `pumpAndSettle` ficaria preso na animacao do
/// indicador de carregamento.
Future<void> _montarComRedeReal(WidgetTester tester, Widget tela) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(_envolver(tela));

    // Ate 10 s aguardando a resposta da API.
    for (var i = 0; i < 100 && _carregando(tester); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    await tester.pump();
  });
}

/// Descarta a tela para encerrar timers (o Chat faz polling).
Future<void> _desmontar(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

/// Situacao da API detectada uma unica vez antes dos casos.
enum _EstadoApi { pronta, semAutenticacao, indisponivel }

Future<_EstadoApi> _sondarApi() async {
  try {
    await ApiClient().get('/progresso');
    return _EstadoApi.pronta;
  } on ApiException catch (erro) {
    // Sem status = nao conseguiu falar com o servidor.
    if (erro.status == null) return _EstadoApi.indisponivel;
    if (erro.status == 401 || erro.status == 403) {
      return _EstadoApi.semAutenticacao;
    }
    // A API respondeu (404 de perfil inexistente, por exemplo).
    return _EstadoApi.pronta;
  }
}

/// Roda apenas quando o host foi informado explicitamente (senao o
/// teste tentaria 10.0.2.2 e falharia sem backend).
bool get _podeRodar =>
    const String.fromEnvironment('API_HOST', defaultValue: '') != '';

void main() {
  if (!_podeRodar) {
    test('E2E ignorado: rode com --dart-define=API_HOST=localhost', () {
      // ignore: avoid_print
      print('Passe --dart-define=API_HOST=localhost com a API no ar.');
    });
    return;
  }

  group('E2E Flutter -> API -> Firestore', () {
    final api = ApiClient();
    late _EstadoApi estado;

    setUpAll(() async {
      HttpOverrides.global = null;
      estado = await _sondarApi();
    });

    /// Marca o caso como ignorado quando o ambiente nao permite rodar.
    bool semAmbiente() {
      switch (estado) {
        case _EstadoApi.pronta:
          return false;
        case _EstadoApi.indisponivel:
          markTestSkipped(
            'API fora do ar em ${AppConfigBaseUrl.valor}: rode "npm start".',
          );
          return true;
        case _EstadoApi.semAutenticacao:
          markTestSkipped(
            'API exige token Firebase (FIREBASE_DEMO_MODE=false). '
            'Para exercitar as telas contra a API real, defina '
            'FIREBASE_DEMO_MODE=true no backend/.env.',
          );
          return true;
      }
    }

    testWidgets('tela de Progresso carrega dados reais', (tester) async {
      if (semAmbiente()) return;

      await _montarComRedeReal(
        tester,
        ProgressoScreen(progressoService: ProgressoService(api)),
      );

      expect(_carregando(tester), isFalse,
          reason: 'a tela ficou presa no carregamento');
      expect(find.text('Tentar novamente'), findsNothing,
          reason: 'a API devolveu erro para a tela de Progresso');
      // Com o seed, sempre ha um resumo com peso atual.
      expect(find.textContaining('Peso atual:'), findsOneWidget);
      expect(find.text('Historico de Peso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tela de Evolucao carrega graficos reais', (tester) async {
      if (semAmbiente()) return;

      await _montarComRedeReal(
        tester,
        EvolucaoScreen(evolucaoService: EvolucaoService(api)),
      );

      expect(_carregando(tester), isFalse,
          reason: 'a tela ficou presa no carregamento');
      expect(find.text('Tentar novamente'), findsNothing,
          reason: 'a API devolveu erro para a tela de Evolucao');
      expect(find.text('Evolucao de Peso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tela de Chat carrega conversa do contato padrao',
        (tester) async {
      if (semAmbiente()) return;

      final chatService = ChatService(api);

      String uidContato = '';
      String uidLogado = '';
      await tester.runAsync(() async {
        final contato = await chatService.carregarContatoPadrao();
        uidContato = contato.idUsuario;
        final perfil = await AuthService(api).carregarPerfil();
        uidLogado = perfil.uid;
      });
      expect(uidContato, isNotEmpty);
      expect(uidLogado, isNotEmpty);

      await _montarComRedeReal(
        tester,
        ChatScreen(
          chatService: chatService,
          idUsuario: uidLogado,
          idContato: uidContato,
        ),
      );

      expect(_carregando(tester), isFalse,
          reason: 'a tela ficou presa no carregamento');
      expect(find.text('Tentar novamente'), findsNothing,
          reason: 'a API devolveu erro para a tela de Chat');
      expect(tester.takeException(), isNull);

      // O Chat faz polling: descarta a tela para nao deixar timer ativo.
      await _desmontar(tester);
    });
  });
}

/// Exposto apenas para a mensagem de "API fora do ar".
class AppConfigBaseUrl {
  const AppConfigBaseUrl._();

  static String get valor =>
      'http://${const String.fromEnvironment('API_HOST', defaultValue: 'localhost')}:3000/api';
}
