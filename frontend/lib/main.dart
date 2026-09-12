/// Meu Virtual Nutri - Aplicativo Flutter.
///
/// Ponto de entrada do aplicativo.
///
/// Arquitetura:
///   Flutter/Dart
///     -> Firebase Authentication (login, cadastro, redefinicao)
///     -> REST API Node.js (Bearer token) -> Cloud Firestore
///
/// Fluxo de navegacao:
/// 1. [LoginScreen]: autentica paciente ou nutricionista.
/// 2. [CadastroPacienteScreen] / [CadastroNutricionistaScreen].
/// 3. [OnboardingScreen]: configuracao do perfil do paciente em 5
///    etapas + tutorial interativo (novos usuarios).
/// 4. [PacienteHomeScreen]: area do paciente (Cardapio, Bem-Estar,
///    Progresso/Evolucao, Chat, Perfil).
/// 5. [NutricionistaHomeScreen]: painel do nutricionista (pacientes,
///    cardapios, receitas, agenda, relatorios, chat).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_settings.dart';
import 'core/firebase_config.dart';
import 'core/theme.dart';
import 'models/usuario.dart';
import 'screens/login_screen.dart';
import 'screens/nutricionista_home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/paciente_home_screen.dart';
import 'services/api_services.dart';
import 'services/chat_service.dart';
import 'services/mvn_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.inicializar();
  runApp(const MvnApp());
}

class MvnApp extends StatefulWidget {
  const MvnApp({super.key, this.api});

  /// Cliente HTTP opcional. Em producao o aplicativo cria o seu; os
  /// testes podem injetar um cliente falso para exercitar as telas sem rede.
  final ApiClient? api;

  @override
  State<MvnApp> createState() => _MvnAppState();
}

class _MvnAppState extends State<MvnApp> {
  // Injecao de dependencias: ApiClient e servicos compartilhados.
  late final ApiClient _api = widget.api ?? ApiClient();
  late final AuthService _authService = AuthService(_api);
  late final ChatService _chatService = ChatService(_api);
  late final ProgressoService _progressoService = ProgressoService(_api);
  late final EvolucaoService _evolucaoService = EvolucaoService(_api);
  late final OnboardingService _onboardingService = OnboardingService(_api);
  late final CardapioService _cardapioService = CardapioService(_api);
  late final NutricionistaService _nutricionistaService =
      NutricionistaService(_api);

  /// Estado da sessao: usuario autenticado no momento.
  Usuario? _usuarioLogado;

  bool _inicializando = true;

  @override
  void initState() {
    super.initState();
    _restaurarSessao();
  }

  /// Recupera a sessao do Firebase Auth e o perfil na API.
  Future<void> _restaurarSessao() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _inicializando = false);
      return;
    }
    try {
      final usuario = await _authService.carregarPerfil();
      if (!mounted) return;
      setState(() {
        _usuarioLogado = usuario;
        _inicializando = false;
      });
    } on ApiException {
      // Perfil ainda nao materializado (ex.: cadastro interrompido).
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() => _inicializando = false);
    }
  }

  @override
  void dispose() {
    if (widget.api == null) _api.fechar();
    super.dispose();
  }

  void _definirUsuario(Usuario usuario) {
    setState(() {
      _usuarioLogado = usuario;
      _inicializando = false;
    });
  }

  Future<void> _fazerLogout() async {
    await _authService.logout();
    if (!mounted) return;
    setState(() => _usuarioLogado = null);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Meu Virtual Nutri',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.temaClaro,
          darkTheme: AppTheme.temaEscuro,
          themeMode: AppSettings.instance.themeMode,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler:
                    TextScaler.linear(AppSettings.instance.textScaleFactor),
              ),
              child: child!,
            );
          },
          home: _corpoInicial(),
        );
      },
    );
  }

  Widget _corpoInicial() {
    if (_inicializando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.verde)),
      );
    }

    final usuario = _usuarioLogado;
    if (usuario == null) {
      return LoginScreen(
        authService: _authService,
        aoAutenticar: _definirUsuario,
      );
    }

    // Pacientes passam pelo onboarding antes de usar o app.
    if (usuario.ehPaciente && !usuario.onboardingCompleto) {
      return OnboardingScreen(
        usuario: usuario,
        onboardingService: _onboardingService,
        chatService: _chatService,
        progressoService: _progressoService,
        evolucaoService: _evolucaoService,
        cardapioService: _cardapioService,
        aoConcluir: () => _definirUsuario(usuario.copiarCom(
          const <String, dynamic>{'onboardingCompleto': true},
        )),
        aoFazerLogout: _fazerLogout,
      );
    }

    if (usuario.ehNutricionista) {
      return NutricionistaHomeScreen(
        usuario: usuario,
        nutricionistaService: _nutricionistaService,
        chatService: _chatService,
        evolucaoService: _evolucaoService,
        aoFazerLogout: _fazerLogout,
      );
    }

    return PacienteHomeScreen(
      usuario: usuario,
      authService: _authService,
      onboardingService: _onboardingService,
      chatService: _chatService,
      progressoService: _progressoService,
      evolucaoService: _evolucaoService,
      cardapioService: _cardapioService,
      aoAtualizarUsuario: _definirUsuario,
      aoFazerLogout: _fazerLogout,
    );
  }
}
