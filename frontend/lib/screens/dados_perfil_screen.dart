/// Tela de Visualizacao e Edicao de Dados Profissionais (Nutricionista) / Dados Pessoais (Paciente).
///
/// Permite alterar Nome, Telefone, CRN, Especializacao e dados de contato,
/// persistindo as mudancas na API e no Firestore.
///
/// Relacionamento:
/// - Acessada a partir da [ConfiguracoesScreen] via botao "Dados Profissionais".
/// - Atualiza o objeto [Usuario] ativo na sessao da aplicacao.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/usuario.dart';
import '../services/mvn_services.dart';
import '../widgets/common.dart';

class DadosPerfilScreen extends StatefulWidget {
  const DadosPerfilScreen({
    super.key,
    required this.usuario,
    required this.onboardingService,
    required this.aoAtualizarUsuario,
  });

  final Usuario usuario;
  final OnboardingService onboardingService;
  final void Function(Usuario usuario) aoAtualizarUsuario;

  @override
  State<DadosPerfilScreen> createState() => _DadosPerfilScreenState();
}

class _DadosPerfilScreenState extends State<DadosPerfilScreen> {
  final _chaveForm = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _telefoneController;
  late final TextEditingController _crnController;
  late final TextEditingController _especializacaoController;

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nomeController = TextEditingController(text: u.nome);
    _telefoneController = TextEditingController(text: u.telefone ?? '');
    _crnController = TextEditingController(text: u.crn ?? '');
    _especializacaoController =
        TextEditingController(text: u.especializacao ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _crnController.dispose();
    _especializacaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_chaveForm.currentState?.validate() != true) return;

    setState(() => _salvando = true);
    try {
      final campos = <String, dynamic>{
        'nome': _nomeController.text.trim(),
        'telefone': _telefoneController.text.trim().isEmpty
            ? null
            : _telefoneController.text.trim(),
        if (widget.usuario.ehNutricionista) ...{
          'crn': _crnController.text.trim().isEmpty
              ? null
              : _crnController.text.trim(),
          'especializacao': _especializacaoController.text.trim().isEmpty
              ? null
              : _especializacaoController.text.trim(),
        },
      };

      final atualizado = await widget.onboardingService.atualizarPerfil(campos);
      widget.aoAtualizarUsuario(atualizado);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados profissionais atualizados com sucesso!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final ehNutri = widget.usuario.ehNutricionista;

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(ehNutri ? 'Dados Profissionais' : 'Dados do Perfil'),
        backgroundColor:
            escuro ? AppColors.paletaEscuroCard : AppColors.paletaRoxo,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _chaveForm,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.telaPadding),
          children: [
            // Card de resumo cadastral
            MvnCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.paletaVerde.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          ehNutri ? Icons.badge_outlined : Icons.person_outline,
                          color: AppColors.paletaVerde,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ehNutri
                                  ? 'Informações do Profissional'
                                  : 'Informações Pessoais',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Estes dados são visíveis aos seus ${ehNutri ? "pacientes" : "nutricionista"}.',
                              style: TextStyle(
                                fontSize: 12,
                                color: escuro
                                    ? AppColors.fonteSubtituloClaro
                                    : AppColors.fonteSubtitulo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Campos do formulario
            MvnCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _campo(
                    controlador: _nomeController,
                    rotulo: 'Nome Completo',
                    icone: Icons.person_outline,
                    validador: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe seu nome completo.'
                        : null,
                    escuro: escuro,
                  ),
                  const SizedBox(height: 14),

                  // Email (apenas leitura)
                  _campoLeitura(
                    rotulo: 'E-mail cadastrado',
                    valor: widget.usuario.email,
                    icone: Icons.email_outlined,
                    escuro: escuro,
                  ),
                  const SizedBox(height: 14),

                  _campo(
                    controlador: _telefoneController,
                    rotulo: 'Telefone / WhatsApp',
                    icone: Icons.phone_outlined,
                    teclado: TextInputType.phone,
                    escuro: escuro,
                  ),

                  if (ehNutri) ...[
                    const SizedBox(height: 14),
                    _campo(
                      controlador: _crnController,
                      rotulo: 'Número do CRN (com região)',
                      icone: Icons.assignment_ind_outlined,
                      hint: 'Ex: CRN-3 45678',
                      escuro: escuro,
                    ),
                    const SizedBox(height: 14),
                    _campo(
                      controlador: _especializacaoController,
                      rotulo: 'Especialização / Área de Atuação',
                      icone: Icons.school_outlined,
                      hint: 'Ex: Nutrição Esportiva, Clínica, Funcional',
                      escuro: escuro,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botao Salvar
            SizedBox(
              height: AppSizes.botaoAltura,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.paletaVerde,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.botaoRadius),
                  ),
                  elevation: 0,
                ),
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Salvar Alterações',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controlador,
    required String rotulo,
    required IconData icone,
    String? hint,
    TextInputType teclado = TextInputType.text,
    String? Function(String?)? validador,
    required bool escuro,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: escuro
                ? AppColors.fonteSubtituloClaro
                : AppColors.fonteSubtitulo,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controlador,
          keyboardType: teclado,
          validator: validador,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icone, size: 20, color: AppColors.paletaVerde),
            filled: true,
            fillColor: escuro ? const Color(0xFF0D1117) : AppColors.fundo,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: escuro ? AppColors.bordaEscura : AppColors.borda,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: escuro ? AppColors.bordaEscura : AppColors.borda,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.paletaVerde,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoLeitura({
    required String rotulo,
    required String valor,
    required IconData icone,
    required bool escuro,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: escuro
                ? AppColors.fonteSubtituloClaro
                : AppColors.fonteSubtitulo,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: escuro ? const Color(0xFF1F242C) : AppColors.cinzaSegmento,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: escuro ? AppColors.bordaEscura : AppColors.borda,
            ),
          ),
          child: Row(
            children: [
              Icon(icone, size: 20, color: AppColors.textoFraco),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  valor,
                  style: TextStyle(
                    fontSize: 14,
                    color: escuro
                        ? AppColors.fonteSubtituloClaro
                        : AppColors.textoSuave,
                  ),
                ),
              ),
              const Icon(Icons.lock_outline,
                  size: 16, color: AppColors.textoFraco),
            ],
          ),
        ),
      ],
    );
  }
}
