/// Tela de Cadastro do Paciente / Cliente do Meu Virtual Nutri.
///
/// Especificada no documento de requisitos (tela 2):
/// - Possui 4 campos de texto:
///   1. Nome Completo ('Seu nome')
///   2. Email ('seu@email.com')
///   3. Senha ('Minimo 6 caracteres')
///   4. Confirmacao de Senha ('Digite a senha novamente')
/// - Possui 4 botoes de acao:
///   1. Olho para alternar visibilidade do campo Senha.
///   2. Olho para alternar visibilidade do campo Confirmacao de Senha.
///   3. 'criar conta' (submete cadastro na API e leva a tela inicial do paciente).
///   4. 'Ja tem uma conta? Voltar a tela de login' (retorna a tela anterior).
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/usuario.dart';
import '../services/api_services.dart';
import '../widgets/auth_text_field.dart';

class CadastroPacienteScreen extends StatefulWidget {
  const CadastroPacienteScreen({
    super.key,
    required this.authService,
    required this.aoCadastrar,
  });

  final AuthService authService;
  final void Function(Usuario usuario) aoCadastrar;

  @override
  State<CadastroPacienteScreen> createState() => _CadastroPacienteScreenState();
}

class _CadastroPacienteScreenState extends State<CadastroPacienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _ocultarSenha = true;
  bool _ocultarConfirmarSenha = true;
  bool _carregando = false;
  String? _mensagemErro;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  /// Submete o formulario e cadastra o novo paciente na API.
  Future<void> _criarConta() async {
    if (!_formKey.currentState!.validate()) return;

    if (_senhaController.text != _confirmarSenhaController.text) {
      setState(() => _mensagemErro = 'As senhas nao coincidem.');
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final usuario = await widget.authService.cadastrarPaciente(
        nome: _nomeController.text.trim(),
        email: _emailController.text.trim(),
        senha: _senhaController.text,
        confirmarSenha: _confirmarSenhaController.text,
      );

      if (!mounted) return;
      // Retorna e notifica para abrir a tela inicial do paciente
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.aoCadastrar(usuario);
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
                      width: 80,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: AppColors.paletaVerdeSuave,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_dining,
                          size: 40,
                          color: AppColors.paletaVerde,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Titulo e Subtitulo ---
                  const Text(
                    'Virtual Nutri App',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fonteTitulo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cadastro de Paciente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.paletaVerde,
                    ),
                  ),
                  const SizedBox(height: 20),

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

                  // --- Campo 1: Nome Completo ---
                  AuthTextField(
                    label: 'Nome Completo',
                    controller: _nomeController,
                    hint: 'Seu nome',
                    prefixIcon: Icons.person_outline,
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe seu nome completo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // --- Campo 2: Email ---
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
                  const SizedBox(height: 14),

                  // --- Campo 3: Senha (com Botao 1: Olho) ---
                  AuthTextField(
                    label: 'Senha',
                    controller: _senhaController,
                    hint: 'Minimo 6 caracteres',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    obscureText: _ocultarSenha,
                    onToggleVisibility: () {
                      setState(() => _ocultarSenha = !_ocultarSenha);
                    },
                    validator: (valor) {
                      if (valor == null || valor.isEmpty) {
                        return 'Informe uma senha';
                      }
                      if (valor.length < 6) {
                        return 'A senha deve ter pelo menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // --- Campo 4: Confirmar Senha (com Botao 2: Olho) ---
                  AuthTextField(
                    label: 'Confirmar Senha',
                    controller: _confirmarSenhaController,
                    hint: 'Digite a senha novamente',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    obscureText: _ocultarConfirmarSenha,
                    onToggleVisibility: () {
                      setState(() => _ocultarConfirmarSenha = !_ocultarConfirmarSenha);
                    },
                    validator: (valor) {
                      if (valor == null || valor.isEmpty) {
                        return 'Confirme sua senha';
                      }
                      if (valor != _senhaController.text) {
                        return 'As senhas nao conferem';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- Botao 3: criar conta ---
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
                        onTap: _carregando ? null : _criarConta,
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
                                  'criar conta',
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

                  // --- Botao 4: Ja tem uma conta? Voltar a tela de login ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Ja tem uma conta? ',
                        style: TextStyle(
                          color: AppColors.fonteSubtitulo,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Voltar a tela de login',
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
