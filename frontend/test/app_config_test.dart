import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvn_app/core/app_config.dart';
import 'package:mvn_app/widgets/config_servidor_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfig - Testes Unitarios', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppConfig.limparUrlCustomizada();
    });

    test('normalizacao de IP simples sem protocolo nem porta', () {
      final normalizada = AppConfig.normalizarUrl('192.168.0.22');
      expect(normalizada, equals('http://192.168.0.22:3000/api'));
    });

    test('normalizacao de IP com porta', () {
      final normalizada = AppConfig.normalizarUrl('192.168.0.100:8080');
      expect(normalizada, equals('http://192.168.0.100:8080/api'));
    });

    test('normalizacao de URL HTTPS sem barra final', () {
      final normalizada =
          AppConfig.normalizarUrl('https://meu-virtual-nutri.onrender.com');
      expect(
        normalizada,
        equals('https://meu-virtual-nutri.onrender.com/api'),
      );
    });

    test('normalizacao preserva URL que ja contem /api', () {
      final normalizada =
          AppConfig.normalizarUrl('https://api.servidor.com/api');
      expect(normalizada, equals('https://api.servidor.com/api'));
    });

    test('normalizacao remove barras extras no final', () {
      final normalizada =
          AppConfig.normalizarUrl('http://192.168.0.15:3000/api///');
      expect(normalizada, equals('http://192.168.0.15:3000/api'));
    });

    test('definicao e limpeza de URL customizada em tempo de execucao',
        () async {
      expect(AppConfig.temUrlCustomizada, isFalse);

      await AppConfig.definirUrlCustomizada('192.168.0.50:4000');
      expect(AppConfig.temUrlCustomizada, isTrue);
      expect(AppConfig.baseUrl, equals('http://192.168.0.50:4000/api'));

      await AppConfig.limparUrlCustomizada();
      expect(AppConfig.temUrlCustomizada, isFalse);
    });
  });

  group('ConfigServidorDialog - Teste de Widget', () {
    testWidgets('renderiza campo de texto, sugestoes e botoes',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfigServidorDialog(),
          ),
        ),
      );

      expect(find.text('Servidor da API'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Testar Conexão'), findsOneWidget);
      expect(find.text('Salvar e Aplicar'), findsOneWidget);
      expect(find.text('192.168.0.22'), findsOneWidget);
      expect(find.text('10.0.2.2 (Emulador)'), findsOneWidget);
      expect(find.text('localhost'), findsOneWidget);
    });
  });
}
