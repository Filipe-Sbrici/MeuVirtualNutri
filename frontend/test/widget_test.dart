/// Testes das telas do app (Chat, Progresso, Evolucao, Cardapio,
/// Login e Cadastros).
///
/// Cada teste monta a tela real com um `http.Client` falso que devolve o
/// JSON produzido pela API (ver `fixtures.dart`). Isso exercita a cadeia
/// completa — ApiClient -> service -> model -> widget — e falha se algum
/// campo do JSON nao casar com o modelo Dart ou se a tela lancar erro
/// durante a construcao.
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
import 'package:mvn_app/models/mensagem.dart';
import 'package:mvn_app/models/progresso.dart';
import 'package:mvn_app/models/usuario.dart';
import 'package:mvn_app/screens/aparencia_acessibilidade_screen.dart';
import 'package:mvn_app/screens/bem_estar_screen.dart';
import 'package:mvn_app/screens/chat_screen.dart';
import 'package:mvn_app/screens/configuracoes_screen.dart';
import 'package:mvn_app/screens/dados_perfil_screen.dart';
import 'package:mvn_app/screens/evolucao_screen.dart';
import 'package:mvn_app/screens/notificacoes_config_screen.dart';
import 'package:mvn_app/screens/nutricionista_home_screen.dart';
import 'package:mvn_app/screens/paciente_home_screen.dart';
import 'package:mvn_app/screens/perfil_screen.dart';
import 'package:mvn_app/screens/progresso_screen.dart';
import 'package:mvn_app/widgets/common.dart';
import 'package:mvn_app/services/api_services.dart';
import 'package:mvn_app/services/chat_service.dart';
import 'package:mvn_app/services/mvn_services.dart';

import 'fixtures.dart';

/// Cliente falso que roteia por caminho, como a API real.
MockClient _clienteFalso({
  Map<String, String> respostas = const {},
  void Function(http.Request requisicao)? aoReceber,
}) {
  return MockClient((requisicao) async {
    aoReceber?.call(requisicao);
    final caminho = requisicao.url.path;

    for (final entrada in respostas.entries) {
      if (caminho.contains(entrada.key)) {
        return http.Response(
          entrada.value,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    }
    return http.Response(kErroJson, 404,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

Widget _envolver(Widget tela) => MaterialApp(
      theme: AppTheme.tema,
      home: tela,
    );

/// Rola a tela ate o widget ficar visivel.
Future<void> _rolarAte(WidgetTester tester, Finder alvo) async {
  await tester.scrollUntilVisible(
    alvo,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Tela de Progresso', () {
    testWidgets('renderiza resumo e historico vindos da API', (tester) async {
      final api = ApiClient(
        cliente: _clienteFalso(respostas: {'/progresso': kProgressoJson}),
      );

      await tester.pumpWidget(_envolver(
        ProgressoScreen(progressoService: ProgressoService(api)),
      ));
      await tester.pumpAndSettle();

      // Numeros exatos do prototipo.
      expect(find.text('2.4kg'), findsOneWidget);
      expect(find.text('Perdidos desde o inicio'), findsOneWidget);
      expect(find.text('Meta: 65kg (3.1kg restantes)'), findsOneWidget);
      expect(find.text('Peso atual: 68.1kg'), findsOneWidget);
      expect(find.text('Historico de Peso'), findsOneWidget);
      expect(find.textContaining(' kg'), findsWidgets);
    });

    testWidgets('mostra erro amigavel quando a API falha', (tester) async {
      final api = ApiClient(cliente: _clienteFalso());

      await tester.pumpWidget(_envolver(
        ProgressoScreen(progressoService: ProgressoService(api)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Paciente 99 nao encontrado.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('alternar Semanal/Mensal nao quebra a tela', (tester) async {
      final api = ApiClient(
        cliente: _clienteFalso(respostas: {'/progresso': kProgressoJson}),
      );

      await tester.pumpWidget(_envolver(
        ProgressoScreen(progressoService: ProgressoService(api)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mensal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semanal'));
      await tester.pumpAndSettle();

      expect(find.text('Peso atual: 68.1kg'), findsOneWidget);
    });

    testWidgets('registrar peso atualiza o resumo', (tester) async {
      final api = ApiClient(
        cliente: MockClient((requisicao) async {
          final corpo = requisicao.method == 'POST'
              ? kPesoRegistradoJson
              : kProgressoJson;
          return http.Response(corpo, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

      await tester.pumpWidget(_envolver(
        ProgressoScreen(progressoService: ProgressoService(api)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('REGISTRAR PESO'));
      await tester.pumpAndSettle();

      expect(find.text('Registrar peso'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '67.8');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Peso atual: 67.8kg'), findsOneWidget);
      expect(find.text('2.7kg'), findsOneWidget);
    });
  });

  group('Tela de Evolucao', () {
    testWidgets('renderiza os tres graficos', (tester) async {
      final api = ApiClient(
        cliente: _clienteFalso(respostas: {'/evolucao': kEvolucaoJson}),
      );

      await tester.pumpWidget(_envolver(
        EvolucaoScreen(evolucaoService: EvolucaoService(api)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Evolucao de Peso'), findsOneWidget);
      expect(find.text('Consumo Calorico Semanal'), findsOneWidget);
      expect(find.text('Consumido'), findsOneWidget);
      expect(find.text('Meta'), findsOneWidget);

      await _rolarAte(tester, find.text('Macronutrientes (Media Semanal)'));
      expect(find.text('Macronutrientes (Media Semanal)'), findsOneWidget);
      expect(find.text('110g / 121g'), findsOneWidget);
      expect(find.text('209g / 230g'), findsOneWidget);
      expect(find.text('40g / 44g'), findsOneWidget);
    });

    testWidgets('trocar periodo recarrega sem erro', (tester) async {
      var chamadas = 0;
      final api = ApiClient(
        cliente: _clienteFalso(
          respostas: {'/evolucao': kEvolucaoJson},
          aoReceber: (_) => chamadas++,
        ),
      );

      await tester.pumpWidget(_envolver(
        EvolucaoScreen(evolucaoService: EvolucaoService(api)),
      ));
      await tester.pumpAndSettle();
      expect(chamadas, 1);

      await tester.tap(find.text('Semanal'));
      await tester.pumpAndSettle();
      expect(chamadas, 2);
      expect(find.text('Evolucao de Peso'), findsOneWidget);
    });
  });

  group('Tela de Chat', () {
    testWidgets('renderiza os baloes da conversa', (tester) async {
      final api = ApiClient(
        cliente: _clienteFalso(respostas: {'/chat/conversa': kConversaJson}),
      );

      await tester.pumpWidget(_envolver(
        ChatScreen(
          chatService: ChatService(api),
          idUsuario: kUidPaciente,
          idContato: kUidNutri,
          nomeContato: 'Dr. Gabriel',
          papelContato: 'Nutricionista',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Gabriel'), findsWidgets);
      expect(find.text('ola bom dia! ja atualizei seu cardapio da semana!'),
          findsOneWidget);
      expect(find.text('oiii okei!'), findsOneWidget);
      // Horarios exatos do prototipo, sem deslocamento de fuso.
      expect(find.text('11:54'), findsOneWidget);
      expect(find.text('12:09'), findsOneWidget);
    });

    testWidgets('enviar mensagem faz POST e mostra o balao', (tester) async {
      final metodos = <String>[];
      final api = ApiClient(
        cliente: MockClient((requisicao) async {
          metodos.add('${requisicao.method} ${requisicao.url.path}');
          if (requisicao.method == 'POST') {
            final corpo =
                jsonDecode(requisicao.body) as Map<String, dynamic>;
            expect(corpo['uidContato'], kUidNutri);
            expect(corpo['mensagem'], 'obrigada!');
            return http.Response(kMensagemCriadaJson, 201,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response(kConversaJson, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

      await tester.pumpWidget(_envolver(
        ChatScreen(
          chatService: ChatService(api),
          idUsuario: kUidPaciente,
          idContato: kUidNutri,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'obrigada!');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('obrigada!'), findsOneWidget);
      expect(metodos.any((m) => m.startsWith('POST')), isTrue);
    });

    testWidgets('conversa vazia mostra convite, nao erro', (tester) async {
      const vazio =
          '{"sucesso":true,"dados":{"contato":{"idUsuario":"$kUidNutri",'
          '"nome":"Dr. Gabriel","tipoUsuario":"nutricionista",'
          '"papel":"Nutricionista"},"mensagens":[]}}';

      final api = ApiClient(
        cliente: _clienteFalso(respostas: {'/chat/conversa': vazio}),
      );

      await tester.pumpWidget(_envolver(
        ChatScreen(
          chatService: ChatService(api),
          idUsuario: kUidPaciente,
          idContato: kUidNutri,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhuma mensagem ainda'), findsOneWidget);
    });
  });

  group('Contrato JSON', () {
    test('Mensagem aceita o payload da API', () {
      final json = jsonDecode(kConversaJson) as Map<String, dynamic>;
      final dados = json['dados'] as Map<String, dynamic>;
      final conversa = Conversa.fromJson(dados);

      expect(conversa.contato.nome, 'Dr. Gabriel');
      expect(conversa.contato.papel, 'Nutricionista');
      expect(conversa.mensagens, hasLength(2));
      expect(conversa.mensagens.first.ehMinha, isFalse);
      expect(conversa.mensagens.first.horaFormatada, '11:54');
      expect(conversa.mensagens.last.ehMinha, isTrue);
    });

    test('Contato aceita o payload de /chat/contato', () {
      final json = jsonDecode(kContatoJson) as Map<String, dynamic>;
      final contato =
          Contato.fromJson(json['dados'] as Map<String, dynamic>);

      expect(contato.idUsuario, kUidNutri);
      expect(contato.nome, 'Dr. Gabriel');
      expect(contato.crn, 'CRN-3 45678');
    });

    test('Mensagem tolera campos ausentes', () {
      final mensagem = Mensagem.fromJson(const {
        'idMensagem': 'msg7',
        'idRemetente': 'uid1',
        'nomeRemetente': 'Dr. Gabriel',
        'mensagem': 'ola',
        'dataHora': '2026-08-16T11:54:00',
        'ehMinha': false,
      });

      expect(mensagem.idMensagem, 'msg7');
      expect(mensagem.horaFormatada, '11:54');
    });

    testWidgets('resposta malformada vira erro amigavel, nao tela vermelha',
        (tester) async {
      final api = ApiClient(
        cliente: MockClient((_) async => http.Response(
              '{"sucesso":true,"dados":{"resumo":{}}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      );

      await tester.pumpWidget(_envolver(
        ProgressoScreen(progressoService: ProgressoService(api)),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Formato inesperado'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('API fora do ar mostra instrucao de iniciar o servidor',
        (tester) async {
      final api = ApiClient(
        cliente: MockClient((_) async {
          throw http.ClientException('Connection refused');
        }),
      );

      await tester.pumpWidget(_envolver(
        ProgressoScreen(progressoService: ProgressoService(api)),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nao foi possivel conectar a API'),
          findsOneWidget);
    });
  });

  group('Modelos Cardapio', () {
    test('CardapioDoDia aceita o payload de /cardapio/hoje', () {
      final json = jsonDecode(kCardapioHojeJson) as Map<String, dynamic>;
      final payload = json['dados'] as Map<String, dynamic>;
      expect(payload['refeicoes'], isA<List>());
      expect((payload['refeicoes'] as List).length, 2);
      expect(payload['resumo']['concluidas'], 1);
    });
  });

  group('Bem-Estar (hidratacao e humor)', () {
    /// A tela envia o TOTAL de copos. O contador do dia era gravado com
    /// o dobro do exibido porque a tela somava 1 e quem persistia somava
    /// de novo.
    testWidgets('cada copo registra o total exato, sem duplicar',
        (tester) async {
      final enviados = <int>[];

      await tester.pumpWidget(_envolver(BemEstarScreen(
        coposAgua: 0,
        naoLidas: 0,
        aoRegistrarAgua: (copos) async => enviados.add(copos),
        aoRegistrarHumor: (_) async {},
        aoAbrirChat: () {},
        aoAbrirListaCompras: () {},
        aoAbrirMinhasReceitas: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('0/8 copos'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.water_drop_rounded).first);
      await tester.pumpAndSettle();
      expect(enviados, [1]);
      expect(find.text('1/8 copos'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.water_drop_rounded).first);
      await tester.pumpAndSettle();
      expect(enviados, [1, 2]);
      expect(find.text('2/8 copos'), findsOneWidget);

      await tester.tap(find.text('Zerar'));
      await tester.pumpAndSettle();
      expect(enviados, [1, 2, 0]);
      expect(find.text('0/8 copos'), findsOneWidget);
    });

    testWidgets('reabre com hidratacao e humor ja registrados hoje',
        (tester) async {
      await tester.pumpWidget(_envolver(BemEstarScreen(
        coposAgua: 3,
        humorInicial: 'bom',
        naoLidas: 2,
        aoRegistrarAgua: (_) async {},
        aoRegistrarHumor: (_) async {},
        aoAbrirChat: () {},
        aoAbrirListaCompras: () {},
        aoAbrirMinhasReceitas: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('3/8 copos'), findsOneWidget);
      expect(find.textContaining('2 mensagem(ns)'), findsOneWidget);

      // O humor gravado aparece destacado (negrito) na volta a tela.
      final rotulo = tester.widget<Text>(find.text('Bom'));
      expect(rotulo.style?.fontWeight, FontWeight.w800);
    });

    test('Progresso.fromJson expoe os registros de hoje', () {
      final json = jsonDecode(kProgressoJson) as Map<String, dynamic>;
      final progresso =
          Progresso.fromJson(json['dados'] as Map<String, dynamic>);

      expect(progresso.hoje.coposAgua, 3);
      expect(progresso.hoje.humor, 'bom');
    });

    test('Progresso.fromJson tolera resposta sem o bloco hoje', () {
      final json = jsonDecode(kPesoRegistradoJson) as Map<String, dynamic>;
      final progresso =
          Progresso.fromJson(json['dados'] as Map<String, dynamic>);

      expect(progresso.hoje.coposAgua, 0);
      expect(progresso.hoje.humor, isNull);
    });

    /// Teste do caminho REAL (PacienteHomeScreen -> Bem-Estar -> API):
    /// era aqui que o total gravado saia dobrado, porque a tela somava
    /// um copo e quem persistia somava outro.
    testWidgets('o total gravado na API e igual ao exibido na tela',
        (tester) async {
      final corposEnviados = <Map<String, dynamic>>[];

      final api = ApiClient(
        cliente: MockClient((requisicao) async {
          final caminho = requisicao.url.path;
          if (requisicao.method == 'POST' && caminho.contains('/progresso/agua')) {
            corposEnviados
                .add(jsonDecode(requisicao.body) as Map<String, dynamic>);
            return http.Response('{"sucesso":true,"dados":{}}', 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          if (caminho.contains('/progresso')) {
            return http.Response(kProgressoJson, 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          if (caminho.contains('/cardapio/hoje')) {
            return http.Response(kCardapioHojeJson, 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response('{"sucesso":true,"dados":{"total":0}}', 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

      final usuario = Usuario.fromJson(
        (jsonDecode(kPerfilClinicoJson) as Map<String, dynamic>)['dados']
            as Map<String, dynamic>,
      );

      await tester.pumpWidget(_envolver(PacienteHomeScreen(
        usuario: usuario,
        authService: AuthService(api),
        onboardingService: OnboardingService(api),
        chatService: ChatService(api),
        progressoService: ProgressoService(api),
        evolucaoService: EvolucaoService(api),
        cardapioService: CardapioService(api),
        aoAtualizarUsuario: (_) {},
        aoFazerLogout: () {},
      )));
      await tester.pumpAndSettle();

      await _rolarAte(tester, find.text('BEM-ESTAR DO DIA'));
      await tester.tap(find.text('BEM-ESTAR DO DIA'));
      await tester.pumpAndSettle();

      // O fixture traz coposAgua = 3 registrados hoje.
      expect(find.text('3/8 copos'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.water_drop_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('4/8 copos'), findsOneWidget);
      expect(corposEnviados, hasLength(1));
      expect(corposEnviados.single['coposAgua'], 4);

      // Descarta a tela para encerrar o Timer de mensagens nao lidas.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });

  group('Tela de Perfil', () {
    /// PerfilScreen com um cliente falso e um usuario ja carregado.
    Widget montarPerfil(
      Usuario usuario, {
      required ApiClient api,
      VoidCallback? aoFazerLogout,
    }) =>
        _envolver(PerfilScreen(
          usuario: usuario,
          authService: AuthService(api),
          onboardingService: OnboardingService(api),
          aoAtualizarUsuario: (_) {},
          aoFazerLogout: aoFazerLogout ?? () {},
        ));

    Usuario usuarioClinico() {
      final json = jsonDecode(kPerfilClinicoJson) as Map<String, dynamic>;
      return Usuario.fromJson(json['dados'] as Map<String, dynamic>);
    }

    testWidgets('mostra dados clinicos, IMC e restricoes do perfil',
        (tester) async {
      final api = ApiClient(cliente: _clienteFalso());

      await tester.pumpWidget(montarPerfil(usuarioClinico(), api: api));
      await tester.pumpAndSettle();

      // 68.1 / 1.65^2 = 25.0
      expect(find.text('IMC atual: 25.0'), findsOneWidget);

      // Campos pre-preenchidos com o que veio da API. Comparamos o
      // conteudo dos controladores: as dicas (hints) usam os mesmos
      // numeros e casariam com find.text.
      final valores = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((campo) => campo.controller.text)
          .toList();
      expect(valores, containsAll(<String>['31', '68.1', '1.65', '65.0']));

      await _rolarAte(tester, find.text('Seguranca alimentar'));
      expect(find.text('Seguranca alimentar'), findsOneWidget);
      expect(find.textContaining('Intolerancia a lactose'), findsOneWidget);
      expect(find.textContaining('Hipertensao'), findsOneWidget);
    });

    testWidgets('nome vazio nao e enviado a API', (tester) async {
      final requisicoes = <String>[];
      final api = ApiClient(
        cliente: _clienteFalso(
          respostas: {'/perfil': kPerfilAtualizadoJson},
          aoReceber: (req) => requisicoes.add(req.method),
        ),
      );

      await tester.pumpWidget(montarPerfil(usuarioClinico(), api: api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '   ');
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Informe seu nome.'), findsOneWidget);
      expect(requisicoes, isEmpty);
    });

    testWidgets('valor numerico invalido e barrado antes do envio',
        (tester) async {
      final requisicoes = <String>[];
      final api = ApiClient(
        cliente: _clienteFalso(
          respostas: {'/perfil': kPerfilAtualizadoJson},
          aoReceber: (req) => requisicoes.add(req.method),
        ),
      );

      await tester.pumpWidget(montarPerfil(usuarioClinico(), api: api));
      await tester.pumpAndSettle();

      // Idade e o 3o campo (nome, telefone, idade).
      await tester.enterText(find.byType(TextFormField).at(2), '28 anos');
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Numero invalido.'), findsOneWidget);
      expect(requisicoes, isEmpty);
    });

    testWidgets('perfil sem nome nao derruba a tela', (tester) async {
      final api = ApiClient(cliente: _clienteFalso());

      await tester.pumpWidget(montarPerfil(
        Usuario.fromJson(const {
          'uid': 'uid-sem-nome',
          'nome': '',
          'email': 'sem.nome@mvn.com',
          'tipoUsuario': 'paciente',
        }),
        api: api,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('sair da conta fecha as telas empilhadas', (tester) async {
      var saiu = false;
      final api = ApiClient(cliente: _clienteFalso());

      // Perfil empilhado sobre uma tela inicial, como no app.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.tema,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PerfilScreen(
                    usuario: usuarioClinico(),
                    authService: AuthService(api),
                    onboardingService: OnboardingService(api),
                    aoAtualizarUsuario: (_) {},
                    aoFazerLogout: () => saiu = true,
                  ),
                ),
              ),
              child: const Text('abrir perfil'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('abrir perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil'), findsOneWidget);

      await _rolarAte(tester, find.text('Sair da conta'));
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(saiu, isTrue);
      // A tela de Perfil nao pode continuar visivel apos o logout.
      expect(find.text('Perfil'), findsNothing);
      expect(find.text('abrir perfil'), findsOneWidget);
    });
  });

  group('Compartilhar receita (paciente)', () {
    const alimentosJson =
        '{"sucesso":true,"dados":{"alimentos":['
        '{"idAlimento":"banana","nome":"Banana","categoria":"Frutas",'
        '"calorias":89,"proteinas":1.1,"carboidratos":23,"gorduras":0.3},'
        '{"idAlimento":"aveia","nome":"Aveia","categoria":"Cereais",'
        '"calorias":389,"proteinas":16.9,"carboidratos":66,"gorduras":6.9}'
        ']}}';

    /// A receita enviada precisa levar os macros POR 100 g de cada
    /// ingrediente: sem eles a API gravaria a receita com 0 kcal.
    testWidgets('envia os ingredientes com os macros por 100 g',
        (tester) async {
      Map<String, dynamic>? enviado;
      final api = ApiClient(
        cliente: MockClient((requisicao) async {
          if (requisicao.method == 'POST') {
            enviado = jsonDecode(requisicao.body) as Map<String, dynamic>;
            return http.Response('{"sucesso":true,"dados":{}}', 201,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response(alimentosJson, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

      final alimentos = (jsonDecode(alimentosJson)['dados']['alimentos']
              as List<dynamic>)
          .map((a) => Alimento.fromJson(a as Map<String, dynamic>))
          .toList();

      await tester.pumpWidget(_envolver(CompartilharReceitaScreen(
        cardapioService: CardapioService(api),
        alimentos: alimentos,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Nome da receita'), 'Vitamina');

      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Quantidade (g)'), '150');
      await _rolarAte(tester, find.text('Adicionar'));
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      // 150 g de banana a 89 kcal/100 g = 133,5 kcal.
      await _rolarAte(tester, find.textContaining('Total estimado:'));
      expect(find.textContaining('Banana — 150g (134 kcal)'), findsOneWidget);
      expect(find.text('Total estimado: 134 kcal'), findsOneWidget);

      await _rolarAte(tester, find.text('ENVIAR PARA APROVACAO'));
      await tester.tap(find.text('ENVIAR PARA APROVACAO'));
      await tester.pumpAndSettle();

      expect(enviado, isNotNull);
      expect(enviado!['nome'], 'Vitamina');
      final ingredientes = enviado!['ingredientes'] as List<dynamic>;
      expect(ingredientes, hasLength(1));
      final banana = ingredientes.single as Map<String, dynamic>;
      expect(banana['quantidadeG'], 150);
      expect(banana['calorias'], 89);
      expect(banana['carboidratos'], 23);
    });

    testWidgets('nao envia receita sem nome ou sem ingredientes',
        (tester) async {
      var houvePost = false;
      final api = ApiClient(
        cliente: MockClient((requisicao) async {
          if (requisicao.method == 'POST') houvePost = true;
          return http.Response(alimentosJson, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

      await tester.pumpWidget(_envolver(CompartilharReceitaScreen(
        cardapioService: CardapioService(api),
        alimentos: const [],
      )));
      await tester.pumpAndSettle();

      await _rolarAte(tester, find.text('ENVIAR PARA APROVACAO'));
      await tester.tap(find.text('ENVIAR PARA APROVACAO'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Informe o nome e pelo menos um ingrediente'),
          findsOneWidget);
      expect(houvePost, isFalse);
    });
  });

  group('Configurações do App (Página 1)', () {
    const usuarioNutri = Usuario(
      uid: kUidNutri,
      nome: 'Dr. Gabriel',
      email: 'gabriel@mvn.com',
      tipoUsuario: 'nutricionista',
      crn: 'CRN-3 45678',
      especializacao: 'Nutrição Clínica',
      onboardingCompleto: true,
      tutorialVisto: true,
    );

    testWidgets('ConfiguracoesScreen renderiza os 5 botoes e dados do usuario',
        (tester) async {
      final api = ApiClient(
        cliente: MockClient((_) async => http.Response('{"sucesso":true}', 200)),
      );

      await tester.pumpWidget(_envolver(ConfiguracoesScreen(
        usuario: usuarioNutri,
        authService: AuthService(api),
        onboardingService: OnboardingService(api),
        aoAtualizarUsuario: (_) {},
        aoFazerLogout: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Configurações'), findsOneWidget);
      expect(find.textContaining('Dr. Gabriel'), findsOneWidget);
      expect(find.text('Dados Profissionais'), findsOneWidget);
      expect(find.text('Notificações'), findsOneWidget);
      expect(find.text('Aparência e Acessibilidade'), findsOneWidget);
      expect(find.text('Sair da conta'), findsOneWidget);
      expect(find.text('Excluir conta'), findsOneWidget);
    });

    testWidgets('ConfiguracoesScreen exibe botao de voltar quando aberto pelo paciente',
        (tester) async {
      final api = ApiClient(
        cliente: MockClient((_) async => http.Response('{"sucesso":true}', 200)),
      );

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConfiguracoesScreen(
                    usuario: usuarioNutri,
                    authService: AuthService(api),
                    onboardingService: OnboardingService(api),
                    aoAtualizarUsuario: (_) {},
                    aoFazerLogout: () {},
                  ),
                ),
              ),
              child: const Text('Abrir Config'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Config'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Abrir Config'), findsOneWidget);
    });

    testWidgets('Modo Escuro aplica roxo claro (paletaLilasSuave) em fontes de destaque',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaEscuro,
        home: BemEstarScreen(
          coposAgua: 0,
          naoLidas: 0,
          aoRegistrarAgua: (_) async {},
          aoRegistrarHumor: (_) async {},
          aoAbrirChat: () {},
          aoAbrirListaCompras: () {},
          aoAbrirMinhasReceitas: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final textoCopos = tester.widget<Text>(find.text('0/8 copos'));
      expect(textoCopos.style?.color, AppColors.paletaLilasSuave);
    });

    testWidgets('Modo Escuro renderiza BotaoGradiente com gradiente verde',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaEscuro,
        home: Scaffold(
          body: BotaoGradiente(
            texto: 'SALVAR',
            aoTocar: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BotaoGradiente),
          matching: find.byType(Container),
        ),
      );
      final boxDecoration = container.decoration as BoxDecoration;
      expect(boxDecoration.gradient, AppColors.gradienteVerde);
    });

    testWidgets('NotificacoesConfigScreen permite alternar switches de notificacao',
        (tester) async {
      await tester.pumpWidget(_envolver(const NotificacoesConfigScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Notificações e Alertas'), findsOneWidget);
      expect(find.text('Mensagens do Chat'), findsOneWidget);
      expect(find.text('Solicitações de Atendimento'), findsOneWidget);
      expect(find.text('Lembretes de Consultas'), findsOneWidget);
      expect(find.text('Lembretes de Água e Refeições'), findsOneWidget);

      // Alterna um switch
      final switchFinder = find.byType(Switch).first;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('AparenciaAcessibilidadeScreen permite alterar tema e tamanho da fonte',
        (tester) async {
      await tester.pumpWidget(_envolver(const AparenciaAcessibilidadeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Aparência e Acessibilidade'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);

      // Toca no card do Tema Escuro
      await tester.tap(find.text('Escuro'));
      await tester.pumpAndSettle();
      expect(AppSettings.instance.modoTema, ThemeMode.dark);

      // Toca no card do Tema Claro
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(AppSettings.instance.modoTema, ThemeMode.light);

      // Toca no botao de escala Grande
      await tester.ensureVisible(find.text('Grande'));
      await tester.tap(find.text('Grande'));
      await tester.pumpAndSettle();
      expect(AppSettings.instance.fatorEscalaTexto, 1.15);
    });

    testWidgets('DadosPerfilScreen permite editar e salvar campos profissionais',
        (tester) async {
      Map<String, dynamic>? dadosEnviados;
      final api = ApiClient(
        cliente: MockClient((req) async {
          if (req.method == 'PUT') {
            dadosEnviados = jsonDecode(req.body) as Map<String, dynamic>;
            return http.Response(
              '{"sucesso":true,"dados":{"perfil":{"uid":"$kUidNutri","nome":"Dr. Gabriel Editado","email":"gabriel@mvn.com","tipoUsuario":"nutricionista","crn":"CRN-3 99999"}}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{"sucesso":true}', 200);
        }),
      );

      Usuario? usuarioAtualizado;

      await tester.pumpWidget(_envolver(DadosPerfilScreen(
        usuario: usuarioNutri,
        onboardingService: OnboardingService(api),
        aoAtualizarUsuario: (u) => usuarioAtualizado = u,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Dados Profissionais'), findsOneWidget);
      expect(find.text('Dr. Gabriel'), findsOneWidget);

      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.first, 'Dr. Gabriel Editado');

      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar Alterações'));
      await tester.pumpAndSettle();

      expect(dadosEnviados, isNotNull);
      expect(dadosEnviados!['nome'], 'Dr. Gabriel Editado');
      expect(usuarioAtualizado?.nome, 'Dr. Gabriel Editado');
    });
  });

  group('Agenda e Receitas Práticas (Página 2)', () {
    testWidgets('AgendaTab renderiza subtelas Configurar Horarios e Consultas',
        (tester) async {
      const consultasJson =
          '{"sucesso":true,"dados":{"consultas":['
          '{"idConsulta":"c1","idNutricionista":"$kUidNutri","dataHora":"2026-08-31T09:00:00","status":"disponivel"},'
          '{"idConsulta":"c2","idNutricionista":"$kUidNutri","idPaciente":"$kUidPaciente","dataHora":"2026-08-31T14:00:00","status":"confirmada"}'
          ']}}';

      final api = ApiClient(
        cliente: MockClient((_) async => http.Response(consultasJson, 200,
            headers: {'content-type': 'application/json; charset=utf-8'})),
      );

      await tester.pumpWidget(_envolver(Scaffold(
        body: AgendaTab(
          nutricionistaService: NutricionistaService(api),
        ),
      )));
      await tester.pumpAndSettle();

      // Verifica subtelas
      expect(find.text('Configurar Horários'), findsOneWidget);
      expect(find.textContaining('Consultas'), findsOneWidget);
      expect(find.text('Clique para abrir horário com 1 toque:'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);
      expect(find.text('Gerar Múltiplos Horários em Lote'), findsOneWidget);

      // Alterna para a subtela de Consultas
      await tester.tap(find.textContaining('Consultas'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Consultas Agendadas'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);
    });

    testWidgets('EditorReceitaScreen calcula macros em tempo real e permite adicao rapida',
        (tester) async {
      final alimentos = <Alimento>[
        const Alimento(
          idAlimento: 'frango',
          nome: 'Peito de Frango Grelhado',
          categoria: 'Proteínas',
          calorias: 165,
          proteinas: 31,
          carboidratos: 0,
          gorduras: 3.6,
        ),
      ];

      final api = ApiClient(
        cliente: MockClient((_) async => http.Response('{"sucesso":true,"dados":{}}', 200)),
      );

      await tester.pumpWidget(_envolver(EditorReceitaScreen(
        nutricionistaService: NutricionistaService(api),
        alimentos: alimentos,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Nova Receita Prática'), findsOneWidget);
      expect(find.text('Resumo Nutricional da Receita'), findsOneWidget);
      expect(find.text('0 kcal'), findsOneWidget);

      // Rola a tela ate o botao +100g
      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+100g'));
      await tester.pumpAndSettle();

      // Rola de volta para o topo para ver o painel
      await tester.drag(find.byType(ListView).first, const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(find.text('165 kcal'), findsWidgets);
      expect(find.text('31.0g'), findsOneWidget); // Proteinas
    });
  });
}
