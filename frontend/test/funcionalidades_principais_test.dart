/// Suíte de Testes Automatizados das Funcionalidades Principais do MVN (CI/CD).
///
/// Credenciais dos perfis de teste:
/// - Nutricionista: nteste@gmail.com / 123456
/// - Paciente: pteste@gmail.com / 123456
///
/// Funcionalidades avaliadas:
/// GERAL:
///   1. Login com perfil de Nutricionista
///   2. Login com perfil de Paciente
///   3. Mudar informações da conta e salvar
///   4. Mudar tema do app
///   5. Navegar na barra inferior
///   6. Mensagem de chat
/// PACIENTE:
///   7. Registrar peso
///   8. Compartilhar receita
///   9. Sair da conta
/// NUTRICIONISTA:
///   10. Configurar horários de atendimento
///   11. Criar uma receita
///   12. Mandar orientação ao paciente
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mvn_app/core/api_client.dart';
import 'package:mvn_app/core/app_settings.dart';
import 'package:mvn_app/core/theme.dart';
import 'package:mvn_app/models/cardapio.dart';
import 'package:mvn_app/models/usuario.dart';
import 'package:mvn_app/screens/aparencia_acessibilidade_screen.dart';
import 'package:mvn_app/screens/chat_screen.dart';
import 'package:mvn_app/screens/configuracoes_screen.dart';
import 'package:mvn_app/screens/dados_perfil_screen.dart';
import 'package:mvn_app/screens/login_screen.dart';
import 'package:mvn_app/screens/nutricionista_home_screen.dart';
import 'package:mvn_app/screens/paciente_home_screen.dart';
import 'package:mvn_app/screens/progresso_screen.dart';
import 'package:mvn_app/services/api_services.dart';
import 'package:mvn_app/services/chat_service.dart';
import 'package:mvn_app/services/mvn_services.dart';
import 'package:mvn_app/widgets/bottom_nav.dart';

import 'fixtures.dart';

// --- Perfis de Teste ---
const kNutriUsuario = Usuario(
  uid: 'nutri_teste_id',
  idNutricionista: 'nutri_teste_id',
  nome: 'Dr. Nutri Teste',
  email: 'nteste@gmail.com',
  telefone: '(11) 98888-0000',
  tipoUsuario: 'nutricionista',
  crn: 'CRN-3 99999',
  especializacao: 'Nutrição Clínica e Esportiva',
  onboardingCompleto: true,
  tutorialVisto: true,
);

const kPacienteUsuario = Usuario(
  uid: 'paciente_teste_id',
  nome: 'Paciente Teste',
  email: 'pteste@gmail.com',
  telefone: '(11) 97777-1111',
  tipoUsuario: 'paciente',
  idade: 29,
  pesoAtual: 68.5,
  pesoMeta: 65.0,
  altura: 1.70,
  genero: 'Feminino',
  meta: 'Perda de peso',
  tipoDieta: 'Low carb',
  onboardingCompleto: true,
  tutorialVisto: true,
);

/// Mock do AuthService para simular login direto sem dependência do Firebase nativo.
class MockAuthServiceParaTeste extends AuthService {
  MockAuthServiceParaTeste(super.api);

  @override
  Future<Usuario> login({required String email, required String senha}) async {
    if (email == 'nteste@gmail.com' && senha == '123456') {
      return kNutriUsuario;
    } else if (email == 'pteste@gmail.com' && senha == '123456') {
      return kPacienteUsuario;
    }
    throw ApiException('E-mail ou senha incorretos.');
  }

  @override
  Future<void> logout() async {}
}

Widget _envolverWidget(Widget tela, {ThemeMode? themeMode}) {
  return MaterialApp(
    theme: AppTheme.tema,
    darkTheme: AppTheme.temaEscuro,
    themeMode: themeMode ?? ThemeMode.light,
    home: tela,
  );
}

Future<void> _rolarAte(WidgetTester tester, Finder alvo) async {
  await tester.scrollUntilVisible(
    alvo,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Funcionalidades Principais - GERAL', () {
    testWidgets('1. Login com perfil de Nutricionista (nteste@gmail.com / 123456)',
        (tester) async {
      final api = ApiClient(cliente: MockClient((_) async => http.Response('{}', 200)));
      final authService = MockAuthServiceParaTeste(api);
      Usuario? usuarioLogado;

      await tester.pumpWidget(_envolverWidget(LoginScreen(
        authService: authService,
        aoAutenticar: (u) => usuarioLogado = u,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Virtual Nutri App'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Preenche os dados do Nutricionista
      await tester.enterText(find.byType(TextFormField).first, 'nteste@gmail.com');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.pump();

      // Clica em Entrar
      await tester.tap(find.text('entrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Valida autenticação como Nutricionista
      expect(usuarioLogado, isNotNull);
      expect(usuarioLogado!.email, 'nteste@gmail.com');
      expect(usuarioLogado!.ehNutricionista, isTrue);
    });

    testWidgets('2. Login com perfil de Paciente (pteste@gmail.com / 123456)',
        (tester) async {
      final api = ApiClient(cliente: MockClient((_) async => http.Response('{}', 200)));
      final authService = MockAuthServiceParaTeste(api);
      Usuario? usuarioLogado;

      await tester.pumpWidget(_envolverWidget(LoginScreen(
        authService: authService,
        aoAutenticar: (u) => usuarioLogado = u,
      )));
      await tester.pumpAndSettle();

      // Preenche os dados do Paciente
      await tester.enterText(find.byType(TextFormField).first, 'vteste@gmail.com');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.pump();

      // Clica em Entrar
      await tester.tap(find.text('entrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Valida autenticação como Paciente
      expect(usuarioLogado, isNotNull);
      expect(usuarioLogado!.email, 'pteste@gmail.com');
      expect(usuarioLogado!.ehPaciente, isTrue);
    });

    testWidgets('3. Mudar informações da conta e salvar', (tester) async {
      Map<String, dynamic>? dadosAtualizadosEnviados;

      final api = ApiClient(
        cliente: MockClient((req) async {
          if (req.method == 'PUT' && req.url.path.contains('/perfil/perfil')) {
            dadosAtualizadosEnviados = jsonDecode(req.body) as Map<String, dynamic>;
            return http.Response(
              '{"sucesso":true,"dados":{"perfil":{"uid":"${kNutriUsuario.uid}",'
              '"nome":"${dadosAtualizadosEnviados!['nome']}",'
              '"email":"${kNutriUsuario.email}",'
              '"telefone":"${dadosAtualizadosEnviados!['telefone']}",'
              '"tipoUsuario":"nutricionista"}}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{"sucesso":true}', 200);
        }),
      );

      Usuario? perfilSalvo;

      await tester.pumpWidget(_envolverWidget(DadosPerfilScreen(
        usuario: kNutriUsuario,
        onboardingService: OnboardingService(api),
        aoAtualizarUsuario: (u) => perfilSalvo = u,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Dados Profissionais'), findsOneWidget);

      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.first, 'Dr. Nutri Atualizado');

      await _rolarAte(tester, find.text('Salvar Alterações'));
      await tester.tap(find.text('Salvar Alterações'));
      await tester.pumpAndSettle();

      expect(dadosAtualizadosEnviados, isNotNull);
      expect(dadosAtualizadosEnviados!['nome'], 'Dr. Nutri Atualizado');
      expect(perfilSalvo?.nome, 'Dr. Nutri Atualizado');
    });

    testWidgets('4. Mudar tema do app (Claro / Escuro)', (tester) async {
      await tester.pumpWidget(_envolverWidget(const AparenciaAcessibilidadeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Aparência e Acessibilidade'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);

      // Altera para modo Escuro
      await tester.tap(find.text('Escuro'));
      await tester.pumpAndSettle();
      expect(AppSettings.instance.themeMode, ThemeMode.dark);

      // Altera para modo Claro
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(AppSettings.instance.themeMode, ThemeMode.light);
    });

    testWidgets('5. Navegar na barra inferior', (tester) async {
      AbaNavegacao abaSelecionada = AbaNavegacao.inicio;

      await tester.pumpWidget(_envolverWidget(
        Scaffold(
          bottomNavigationBar: BottomNav(
            abaAtiva: abaSelecionada,
            aoSelecionar: (aba) => abaSelecionada = aba,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Cardápio'), findsOneWidget);
      expect(find.text('Meu Nutri'), findsOneWidget);
      expect(find.text('Progresso'), findsOneWidget);
      expect(find.text('Config'), findsOneWidget);

      // Toca em Cardápio
      await tester.tap(find.text('Cardápio'));
      expect(abaSelecionada, AbaNavegacao.cardapio);

      // Toca em Meu Nutri
      await tester.tap(find.text('Meu Nutri'));
      expect(abaSelecionada, AbaNavegacao.meuNutri);

      // Toca em Progresso
      await tester.tap(find.text('Progresso'));
      expect(abaSelecionada, AbaNavegacao.progresso);

      // Toca em Config
      await tester.tap(find.text('Config'));
      expect(abaSelecionada, AbaNavegacao.perfil);
    });

    testWidgets('6. Mensagem de chat (Enviar mensagem)', (tester) async {
      bool mensagemEnviada = false;

      final api = ApiClient(
        cliente: MockClient((req) async {
          if (req.url.path.contains('/chat/conversa')) {
            return http.Response(kConversaJson, 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          if (req.method == 'POST' && req.url.path.contains('/chat/mensagens')) {
            final corpo = jsonDecode(req.body) as Map<String, dynamic>;
            if (corpo['mensagem'] == 'Olá nutricionista, tudo bem?') {
              mensagemEnviada = true;
            }
            return http.Response(
              '{"sucesso":true,"dados":{"idMensagem":"msg999",'
              '"idRemetente":"${kPacienteUsuario.uid}",'
              '"idDestinatario":"${kNutriUsuario.uid}",'
              '"nomeRemetente":"${kPacienteUsuario.nome}",'
              '"mensagem":"Olá nutricionista, tudo bem?",'
              '"dataHora":"2026-09-12T19:00:00","ehMinha":true}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(kConversaJson, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

      final chatService = ChatService(api);

      await tester.pumpWidget(_envolverWidget(ChatScreen(
        chatService: chatService,
        idUsuario: kPacienteUsuario.uid,
        idContato: kNutriUsuario.uid,
        nomeContato: kNutriUsuario.nome,
        papelContato: 'Nutricionista',
      )));
      await tester.pumpAndSettle();

      // Verifica balões existentes
      expect(find.text('ola bom dia! ja atualizei seu cardapio da semana!'), findsOneWidget);

      // Digita nova mensagem
      final campoTexto = find.byType(TextField);
      await tester.enterText(campoTexto, 'Olá nutricionista, tudo bem?');
      await tester.pump();

      // Clica no botão de envio
      final botaoEnviar = find.byIcon(Icons.send_rounded);
      await tester.tap(botaoEnviar);
      await tester.pumpAndSettle();

      // Valida se a mensagem foi enviada à API e renderizada na tela
      expect(mensagemEnviada, isTrue);
      expect(find.text('Olá nutricionista, tudo bem?'), findsOneWidget);
    });
  });

  group('Funcionalidades Principais - PACIENTE', () {
    testWidgets('7. Registrar peso', (tester) async {
      bool pesoRegistradoNaApi = false;

      final api = ApiClient(
        cliente: MockClient((req) async {
          if (req.method == 'GET' && req.url.path.contains('/progresso')) {
            return http.Response(kProgressoJson, 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          if (req.method == 'POST' && req.url.path.contains('/progresso/peso')) {
            final corpo = jsonDecode(req.body) as Map<String, dynamic>;
            if (corpo['peso'] == 67.8) {
              pesoRegistradoNaApi = true;
            }
            return http.Response(kPesoRegistradoJson, 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response(kProgressoJson, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

      final progressoService = ProgressoService(api);

      await tester.pumpWidget(_envolverWidget(
        ProgressoScreen(progressoService: progressoService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2.4kg'), findsOneWidget);
      expect(find.text('Peso atual: 68.1kg'), findsOneWidget);

      // Clica no botão de registrar peso
      await tester.tap(find.text('REGISTRAR PESO'));
      await tester.pumpAndSettle();

      // Insere o novo peso no diálogo
      expect(find.text('Registrar peso'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '67.8');
      await tester.pump();

      // Salva
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // Valida que o peso foi salvo e a tela recalculou
      expect(pesoRegistradoNaApi, isTrue);
      expect(find.text('2.7kg'), findsOneWidget);
      expect(find.text('Peso atual: 67.8kg'), findsOneWidget);
    });

    testWidgets('8. Compartilhar receita', (tester) async {
      bool receitaCompartilhada = false;

      final api = ApiClient(
        cliente: MockClient((req) async {
          if (req.method == 'POST' && req.url.path.contains('/minhas-receitas')) {
            final corpo = jsonDecode(req.body) as Map<String, dynamic>;
            if (corpo['nome'] == 'Omelete Proteico' &&
                (corpo['ingredientes'] as List).isNotEmpty) {
              receitaCompartilhada = true;
            }
            return http.Response('{"sucesso":true}', 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response('{"sucesso":true}', 200);
        }),
      );

      final cardapioService = CardapioService(api);
      final listaAlimentos = [
        const Alimento(
          idAlimento: 'alim_ovo',
          nome: 'Ovo de Galinha',
          categoria: 'Proteínas',
          calorias: 143,
          proteinas: 13,
          carboidratos: 1,
          gorduras: 10,
        ),
      ];

      await tester.pumpWidget(_envolverWidget(CompartilharReceitaScreen(
        cardapioService: cardapioService,
        alimentos: listaAlimentos,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Compartilhar receita'), findsOneWidget);

      // Preenche nome da receita
      await tester.enterText(
          find.widgetWithText(TextField, 'Nome da receita'), 'Omelete Proteico');

      // Seleciona alimento
      await tester.tap(find.text('Ovo de Galinha'));
      await tester.pumpAndSettle();

      // Informa a quantidade
      await tester.enterText(
          find.widgetWithText(TextField, 'Quantidade (g)'), '150');

      // Adiciona ingrediente
      await _rolarAte(tester, find.text('Adicionar'));
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ovo de Galinha'), findsWidgets);

      // Preenche modo de preparo
      await tester.enterText(
          find.widgetWithText(TextField, 'Modo de preparo (opcional)'),
          'Bater os ovos e dourar na frigideira.');
      await tester.pump();

      // Clica em Enviar para Aprovação
      await _rolarAte(tester, find.text('ENVIAR PARA APROVACAO'));
      await tester.tap(find.text('ENVIAR PARA APROVACAO'));
      await tester.pumpAndSettle();

      expect(receitaCompartilhada, isTrue);
    });

    testWidgets('9. Sair da conta (Logout)', (tester) async {
      bool logoutExecutado = false;
      final api = ApiClient(cliente: MockClient((_) async => http.Response('{}', 200)));

      await tester.pumpWidget(_envolverWidget(ConfiguracoesScreen(
        usuario: kPacienteUsuario,
        authService: AuthService(api),
        onboardingService: OnboardingService(api),
        aoAtualizarUsuario: (_) {},
        aoFazerLogout: () => logoutExecutado = true,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Configurações'), findsOneWidget);

      // Rola até o botão de Sair da Conta
      await _rolarAte(tester, find.text('Sair da conta'));
      final botaoSair = find.text('Sair da conta');
      await tester.tap(botaoSair);
      await tester.pumpAndSettle();

      // Confirma no modal de logout
      expect(find.text('Encerrar Sessão'), findsOneWidget);
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(logoutExecutado, isTrue);
    });
  });

  group('Funcionalidades Principais - NUTRICIONISTA', () {
    testWidgets('10. Configurar horários de atendimento', (tester) async {
      bool horarioCriadoNaApi = false;

      final api = ApiClient(
        cliente: MockClient((req) async {
          if (req.method == 'GET' && req.url.path.contains('/consultas')) {
            return http.Response(
              '{"sucesso":true,"dados":{"consultas":[]}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (req.method == 'POST' && req.url.path.contains('/consultas')) {
            horarioCriadoNaApi = true;
            return http.Response(
              '{"sucesso":true,"dados":{"consulta":{"idConsulta":"c_nova_1"}}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{"sucesso":true}', 200);
        }),
      );

      final nutricionistaService = NutricionistaService(api);

      await tester.pumpWidget(_envolverWidget(Scaffold(
        body: AgendaTab(
          nutricionistaService: nutricionistaService,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Configurar Horários'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);

      // Toca no atalho rápido de horário (08:00)
      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();

      expect(horarioCriadoNaApi, isTrue);
    });

    testWidgets('11. Criar uma receita com cálculo de macros', (tester) async {
      bool receitaCriadaNaApi = false;

      final api = ApiClient(
        cliente: MockClient((req) async {
          if (req.method == 'POST' && req.url.path.contains('/nutricionista/receitas')) {
            final corpo = jsonDecode(req.body) as Map<String, dynamic>;
            if (corpo['nome'] == 'Frango Fit' && (corpo['ingredientes'] as List).isNotEmpty) {
              receitaCriadaNaApi = true;
            }
            return http.Response('{"sucesso":true}', 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response('{"sucesso":true}', 200);
        }),
      );

      final nutricionistaService = NutricionistaService(api);
      final alimentosNutri = [
        const Alimento(
          idAlimento: 'alim_frango',
          nome: 'Peito de Frango Grelhado',
          categoria: 'Proteínas',
          calorias: 165,
          proteinas: 31,
          carboidratos: 0,
          gorduras: 3.6,
        ),
      ];

      await tester.pumpWidget(_envolverWidget(EditorReceitaScreen(
        nutricionistaService: nutricionistaService,
        alimentos: alimentosNutri,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Nova Receita Prática'), findsOneWidget);
      expect(find.text('Resumo Nutricional da Receita'), findsOneWidget);

      // Informa o nome da receita
      final campoNome = find.byType(TextField).first;
      await tester.enterText(campoNome, 'Frango Fit');

      // Rola até o botão de adicionar gramas (+100g)
      await _rolarAte(tester, find.text('+100g'));
      await tester.tap(find.text('+100g'));
      await tester.pumpAndSettle();

      // Rola de volta para o topo para validar o painel de macros
      await tester.drag(find.byType(ListView).first, const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(find.text('165 kcal'), findsWidgets);
      expect(find.text('31.0g'), findsOneWidget); // Proteinas

      // Clica em Salvar Receita no AppBar
      await tester.tap(find.byTooltip('Salvar receita'));
      await tester.pumpAndSettle();

      expect(receitaCriadaNaApi, isTrue);
    });

    testWidgets('12. Mandar orientação ao paciente', (tester) async {
      bool orientacaoEnviada = false;

      final api = ApiClient(
        cliente: MockClient((req) async {
          if (req.method == 'POST' && req.url.path.contains('/nutricionista/orientacoes')) {
            final corpo = jsonDecode(req.body) as Map<String, dynamic>;
            if (corpo['uidPaciente'] == 'paciente_ana_1' &&
                corpo['categoria'] == 'positivo' &&
                corpo['texto'] == 'Ótima adesão ao plano! Parabéns.') {
              orientacaoEnviada = true;
            }
            return http.Response('{"sucesso":true}', 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response('{"sucesso":true}', 200);
        }),
      );

      final nutricionistaService = NutricionistaService(api);
      final evolucaoService = EvolucaoService(api);
      final chatService = ChatService(api);

      const pacienteResumo = PacienteResumo(
        uid: 'paciente_ana_1',
        nome: 'Ana Beatriz Souza',
        email: 'ana@mvn.com',
        objetivo: 'Perda de peso',
        pesoAtual: 68.1,
        pesoMeta: 65.0,
        altura: 1.65,
        idade: 31,
      );

      await tester.pumpWidget(_envolverWidget(PerfilClinicoScreen(
        uidLogado: kNutriUsuario.uid,
        paciente: pacienteResumo,
        nutricionistaService: nutricionistaService,
        evolucaoService: evolucaoService,
        chatService: chatService,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Ana Beatriz Souza'), findsOneWidget);

      // Rola até o botão "ENVIAR ORIENTAÇÃO"
      await _rolarAte(tester, find.text('ENVIAR ORIENTAÇÃO'));
      final botaoOrientacao = find.text('ENVIAR ORIENTAÇÃO');
      await tester.tap(botaoOrientacao);
      await tester.pumpAndSettle();

      expect(find.text('Enviar orientação'), findsOneWidget);

      // Preenche o texto da orientação
      final campoOrientacao = find.widgetWithText(
        TextField,
        'Escreva a orientação para o paciente...',
      );
      await tester.enterText(campoOrientacao, 'Ótima adesão ao plano! Parabéns.');
      await tester.pump();

      // Clica em Enviar no diálogo
      await tester.tap(find.text('Enviar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(orientacaoEnviada, isTrue);
    });
  });
}
