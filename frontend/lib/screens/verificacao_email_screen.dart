/// Tela de Verificacao de E-mail (Seguranca Firebase Authentication).
///
/// Exibida automaticamente apos o cadastro ou login quando a conta
/// ainda nao teve o endereco de e-mail confirmado (`emailVerified == false`).
/// Permite:
/// - Verificar se o link de confirmacao ja foi clicado (`verificarStatusEmail`).
/// - Reenviar o link de verificacao para a caixa de entrada (`reenviarEmailVerificacao`).
/// - Sair da conta para entrar com outro e-mail (`aoFazerLogout`).
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/usuario.dart';
import '../services/api_services.dart';

class VerificacaoEmailScreen extends StatefulWidget {
  const VerificacaoEmailScreen({
    super.key,
    required this.usuario,
    required this.authService,
    required this.aoConfirmarVerificacao,
    required this.aoFazerLogout,
  });

  final Usuario usuario;
  final AuthService authService;
  final VoidCallback aoConfirmarVerificacao;
  final Future<void> Function() aoFazerLogout;

  @override
  State<VerificacaoEmailScreen> createState() => _VerificacaoEmailScreenState();
}

class _VerificacaoEmailScreenState extends State<VerificacaoEmailScreen> {
  bool _verificando = false;
  bool _reenviando = false;
  String? _mensagemSucesso;
  String? _mensagemErro;

  Future<void> _checarConfirmacao() async {
    setState(() {
      _verificando = true;
      _mensagemErro = null;
      _mensagemSucesso = null;
    });

    try {
      final confirmado = await widget.authService.verificarStatusEmail();
      if (!mounted) return;

      if (confirmado) {
        setState(() {
          _verificando = false;
        });
        widget.aoConfirmarVerificacao();
      } else {
        setState(() {
          _verificando = false;
          _mensagemErro =
              'Ainda nao identificamos a confirmacao. Abra o e-mail enviado, clique no link de verificacao e tente novamente.';
        });
      }
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _verificando = false;
        _mensagemErro = erro.mensagem;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _verificando = false;
        _mensagemErro = mensagemDeErroFirebase(erro);
      });
    }
  }

  Future<void> _reenviarLink() async {
    setState(() {
      _reenviando = true;
      _mensagemErro = null;
      _mensagemSucesso = null;
    });

    try {
      await widget.authService.reenviarEmailVerificacao();
      if (!mounted) return;
      setState(() {
        _reenviando = false;
        _mensagemSucesso =
            'Novo link de verificacao enviado para ${widget.usuario.email}. Verifique tambem a pasta de Spam ou Lixo Eletronico.';
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _reenviando = false;
        _mensagemErro = erro.mensagem;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _reenviando = false;
        _mensagemErro = mensagemDeErroFirebase(erro);
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.paletaVerdeSuave,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: AppColors.verdeEscuro,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Verifique seu e-mail',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.texto,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Para garantir a seguranca da sua conta, enviamos um link de confirmacao para:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cinzaSegmento,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.alternate_email,
                            size: 18,
                            color: AppColors.verdeEscuro,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.usuario.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.texto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Clique no link recebido no seu e-mail e, em seguida, toque no botao abaixo para liberar seu acesso ao aplicativo. Caso nao encontre na caixa de entrada, confira a pasta de Spam.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    if (_mensagemErro != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _mensagemErro!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_mensagemSucesso != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.paletaVerdeSuave,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.verde),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.verdeEscuro,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _mensagemSucesso!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.verdeEscuro,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_verificando || _reenviando) ? null : _checarConfirmacao,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.verde,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _verificando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(
                          _verificando
                              ? 'Verificando...'
                              : 'Ja confirmei meu e-mail',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed:
                            (_verificando || _reenviando) ? null : _reenviarLink,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.verdeEscuro,
                          side: const BorderSide(color: AppColors.verde),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _reenviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.verdeEscuro,
                                ),
                              )
                            : const Icon(Icons.mark_email_read_outlined),
                        label: Text(
                          _reenviando
                              ? 'Reenviando...'
                              : 'Reenviar link de verificacao',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: (_verificando || _reenviando)
                          ? null
                          : () async {
                              await widget.aoFazerLogout();
                            },
                      icon: const Icon(
                        Icons.logout,
                        size: 18,
                        color: AppColors.textoSuave,
                      ),
                      label: const Text(
                        'Sair / Usar outro e-mail',
                        style: TextStyle(color: AppColors.textoSuave),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

