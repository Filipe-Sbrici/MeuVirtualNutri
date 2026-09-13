/// Tela de Login do Meu Virtual Nutri.
///
/// Especificada no documento de requisitos (tela 1):
/// - Possui 2 campos de texto: Email e Senha.
/// - Possui 4 botoes de acao:
///   1. Alternancia de visibilidade da senha (olho).
///   2. 'Esqueceu a senha?' (recuperacao de credenciais).
///   3. 'entrar' (autenticacao com a API REST).
///   4. 'Cadastre-se aqui' (leva ao fluxo de criacao de conta de Paciente ou Nutricionista).
///
/// Ao autenticar com sucesso, direciona:
/// - Paciente -> Tela inicial do paciente (AppShell / Progresso e Evolucao).
/// - Nutricionista -> Tela principal do nutricionista (NutricionistaHomeScreen).
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/usuario.dart';
import '../services/api_services.dart';
import '../widgets/auth_text_field.dart';
import 'cadastro_nutricionista_screen.dart';
import 'cadastro_paciente_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.aoAutenticar,
  });

  final AuthService authService;
  final void Function(Usuario usuario) aoAutenticar;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _ocultarSenha = true;
  bool _carregando = false;
  String? _mensagemErro;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Executa o login no Firebase com as credenciais informadas.
  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final usuario = await widget.authService.login(
        emai: _emailController.text.trim(),
        senha: _senhaController.text,
      );

      if (!mounted) return;
      widget.aoAutenticar(usuario);
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagemErro = erro.mensagem;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagemErro = mensagemDeErroFirebase(erro);
        _carregando = false;
      });
    }
  }

  /// Dialogo de recuperacao de senha (Esqueceu a senha? - tela 4.5.4):
  /// envia o e-mail de redefinicao pelo Firebase Authentication.
  Future<void> _mostrarEsqueceuSenha() async {
    final controlador = TextEditingController(text: _emailController.text);

    final enviou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        ),
        title: const Text(
          'Recuperacao de Senha',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe seu e-mail cadastrado. Enviaremos um link para '
              'redefinir sua senha.',
              style: TextStyle(fontSize: 13.5, color: AppColors.fonteSubtitulo),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controlador,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.fonteSubtitulo)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar',
                style: TextStyle(
                    color: AppColors.paletaVerde, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (enviou != true) return;

    try {
      await widget.authService.redefinirSenha(controlador.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-mail de redefinicao enviado! Verifique sua caixa '
              'de entrada e o spam.'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagemDeErroFirebase(erro)),
          backgroundColor: AppColors.vermelho,
        ),
      );
    } finally {
      controlador.dispose();
    }
  }

  /// Modal para escolher o tipo de cadastro (Paciente ou Nutricionista).
  void _abrirSelecaoCadastro() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bordaClara,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Como deseja se cadastrar?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fonteTitulo,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha o tipo de perfil correspondente para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.fonteSubtitulo,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.paletaVerdeSuave,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: AppColors.paletaVerde),
                ),
                title: const Text(
                  'Sou Paciente / Cliente',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.fonteTitulo),
                ),
                subtitle: const Text(
                  'Acompanhe seu progresso, metas e fale com seu nutricionista',
                  style: TextStyle(fontSize: 12, color: AppColors.fonteSubtitulo),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.fonteSubtitulo),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CadastroPacienteScreen(
                        authService: widget.authService,
                        aoCadastrar: widget.aoAutenticar,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF21262D)
                        : AppColors.paletaLilasSuave,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.medical_services,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.paletaLilasSuave
                        : AppColors.paletaRoxo,
                  ),
                ),
                title: const Text(
                  'Sou Nutricionista',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.fonteTitulo),
                ),
                subtitle: const Text(
                  'Cadastre com seu CRN e acompanhe a evolucao dos pacientes',
                  style: TextStyle(fontSize: 12, color: AppColors.fonteSubtitulo),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.fonteSubtitulo),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CadastroNutricionistaScreen(
                        authService: widget.authService,
                        aoCadastrar: widget.aoAutenticar,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paletaClaro,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Logo da aplicacao ---
                  Center(
                    child: Image.asset(
                      'lib/assets/logo MVN.png',
                      width: 90,
                      height: 90,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          color: AppColors.paletaVerdeSuave,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_dining,
                          size: 48,
                          color: AppColors.paletaVerde,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // --- Titulo e Subtitulo ---
                  const Text(
                    'Virtual Nutri App',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fonteTitulo,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Entre para continuar sua jornada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.fonteSubtitulo,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // --- Mensagem de Erro ---
                  if (_mensagemErro != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.vermelho.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.vermelho.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.vermelho,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _mensagemErro!,
                              style: const TextStyle(
                                color: AppColors.vermelho,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- Campo: Email ---
                  AuthTextField(
                    label: 'Email',
                    controller: _emailController,
                    hint: 'seu@email.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe seu e-mail';
                      }
                      if (!valor.contains('@') || !valor.contains('.')) {
                        return 'Informe um e-mail valido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Campo: Senha (com Botao 1: Olho) ---
                  AuthTextField(
                    label: 'Senha',
                    controller: _senhaController,
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    obscureText: _ocultarSenha,
                    onToggleVisibility: () {
                      setState(() => _ocultarSenha = !_ocultarSenha);
                    },
                    validator: (valor) {
                      if (valor == null || valor.isEmpty) {
                        return 'Informe sua senha';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // --- Botao 2: Esqueceu a senha? ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _mostrarEsqueceuSenha,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Esqueceu a senha?',
                        style: TextStyle(
                          color: AppColors.fonteSubtitulo,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Botao 3: entrar (com gradiente da paleta) ---
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradienteAuth,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.paletaVerde.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _carregando ? null : _fazerLogin,
                        borderRadius: BorderRadius.circular(12),
                        child: Center(
                          child: _carregando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'entrar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Divisor 'ou' ---
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(color: AppColors.bordaClara, thickness: 1),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ou',
                          style: TextStyle(
                            color: AppColors.fontePlaceholder,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: AppColors.bordaClara, thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Botao 4: Nao tem uma conta? Cadastre-se aqui ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Nao tem uma conta? ',
                        style: TextStyle(
                          color: AppColors.fonteSubtitulo,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: _abrirSelecaoCadastro,
                        child: const Text(
                          'Cadastre-se aqui',
                          style: TextStyle(
                            color: AppColors.paletaVerde,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
