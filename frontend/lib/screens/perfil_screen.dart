/// Tela de Perfil do Paciente (4.5.19 do prototipo).
///
/// Permite visualizar/editar dados cadastrais, fisicos/clinicos,
/// seguranca alimentar (restricoes, alergias, condicoes medicas e alertas),
/// preferencias alimentares (tipo de dieta, favoritos e rejeitados)
/// e privacidade de compartilhamento com o nutricionista.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/usuario.dart';
import '../services/api_services.dart';
import '../services/mvn_services.dart';
import '../widgets/common.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({
    super.key,
    required this.usuario,
    required this.authService,
    required this.onboardingService,
    required this.aoAtualizarUsuario,
    required this.aoFazerLogout,
  });

  final Usuario usuario;
  final AuthService authService;
  final OnboardingService onboardingService;
  final void Function(Usuario usuario) aoAtualizarUsuario;
  final VoidCallback aoFazerLogout;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _salvando = false;

  final _chaveForm = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _telefoneController;
  late final TextEditingController _idadeController;
  late final TextEditingController _pesoController;
  late final TextEditingController _alturaController;
  late final TextEditingController _pesoMetaController;
  late final TextEditingController _metaController;
  late final TextEditingController _obsSegurancaController;

  String? _tipoDietaSelecionado;
  late List<String> _restricoes;
  late List<String> _condicoesMedicas;
  late List<String> _alimentosFavoritos;
  late List<String> _alimentosRejeitados;
  late bool _compartilharListaCompras;
  late bool _compartilharHumor;

  static const List<String> _opcoesDieta = [
    'Onívora / Convencional',
    'Vegetariana',
    'Vegana',
    'Low Carb',
    'Flexitariana',
    'Sem Glúten',
    'Sem Lactose',
    'Cetogênica',
    'Outra',
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nomeController = TextEditingController(text: u.nome);
    _telefoneController = TextEditingController(text: u.telefone ?? '');
    _idadeController =
        TextEditingController(text: u.idade != null ? u.idade.toString() : '');
    _pesoController = TextEditingController(
        text: u.pesoAtual != null ? u.pesoAtual!.toStringAsFixed(1) : '');
    _alturaController = TextEditingController(
        text: u.altura != null ? u.altura!.toStringAsFixed(2) : '');
    _pesoMetaController = TextEditingController(
        text: u.pesoMeta != null ? u.pesoMeta!.toStringAsFixed(1) : '');
    _metaController = TextEditingController(text: u.meta ?? '');
    _obsSegurancaController =
        TextEditingController(text: u.observacoesSeguranca);

    _tipoDietaSelecionado = u.tipoDieta;
    _restricoes = List<String>.from(u.restricoes);
    _condicoesMedicas = List<String>.from(u.condicoesMedicas);
    _alimentosFavoritos = List<String>.from(u.alimentosFavoritos);
    _alimentosRejeitados = List<String>.from(u.alimentosRejeitados);
    _compartilharListaCompras = u.compartilharListaCompras;
    _compartilharHumor = u.compartilharHumor;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _idadeController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    _pesoMetaController.dispose();
    _metaController.dispose();
    _obsSegurancaController.dispose();
    super.dispose();
  }

  static double? _numero(TextEditingController controlador) =>
      double.tryParse(controlador.text.replaceAll(',', '.').trim());

  double? _calcularImcAtual() {
    final p = _numero(_pesoController);
    final a = _numero(_alturaController);
    if (p == null || a == null || a <= 0) return null;
    return p / (a * a);
  }

  String _classificacaoImc(double imc) {
    if (imc < 18.5) return 'Abaixo do peso';
    if (imc < 25.0) return 'Peso adequado';
    if (imc < 30.0) return 'Sobrepeso';
    if (imc < 35.0) return 'Obesidade Grau I';
    return 'Obesidade Grau II/III';
  }

  Future<void> _salvar() async {
    if (_chaveForm.currentState?.validate() != true) return;

    setState(() => _salvando = true);
    try {
      final idade = int.tryParse(_idadeController.text.trim());
      final peso = _numero(_pesoController);
      final altura = _numero(_alturaController);
      final pesoMeta = _numero(_pesoMetaController);
      final telefone = _telefoneController.text.trim();
      final meta = _metaController.text.trim();

      final campos = <String, dynamic>{
        'nome': _nomeController.text.trim(),
        'telefone': telefone.isEmpty ? null : telefone,
        if (idade != null) 'idade': idade,
        if (peso != null) 'pesoAtual': peso,
        if (altura != null) 'altura': altura,
        if (pesoMeta != null) 'pesoMeta': pesoMeta,
        if (meta.isNotEmpty) 'meta': meta,
        if (_tipoDietaSelecionado != null && _tipoDietaSelecionado!.isNotEmpty)
          'tipoDieta': _tipoDietaSelecionado,
        'restricoes': _restricoes,
        'condicoesMedicas': _condicoesMedicas,
        'alimentosFavoritos': _alimentosFavoritos,
        'alimentosRejeitados': _alimentosRejeitados,
        'observacoesSeguranca': _obsSegurancaController.text.trim(),
        'compartilharListaCompras': _compartilharListaCompras,
        'compartilharHumor': _compartilharHumor,
      };

      final atualizado =
          await widget.onboardingService.atualizarPerfil(campos);
      if (!mounted) return;
      widget.aoAtualizarUsuario(atualizado);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil atualizado com sucesso!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
      Navigator.of(context).maybePop();
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem), backgroundColor: AppColors.vermelho),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o perfil. Tente novamente.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _sair() {
    Navigator.of(context).popUntil((rota) => rota.isFirst);
    widget.aoFazerLogout();
  }

  Future<void> _excluirConta() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Esta ação é permanente. Todos os seus dados serão apagados. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir',
                style: TextStyle(color: AppColors.vermelho)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await widget.authService.excluirConta();
      if (!mounted) return;
      _sair();
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemDeErroFirebase(erro))),
      );
    }
  }

  Future<void> _adicionarItemDialog({
    required String titulo,
    required String hint,
    required void Function(String item) aoAdicionar,
  }) async {
    final controller = TextEditingController();
    final item = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
          ),
          onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.paletaVerde,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (item != null && item.isNotEmpty) {
      setState(() => aoAdicionar(item));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final imc = _calcularImcAtual();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Perfil',
            icone: Icons.account_circle_outlined,
            aoVoltar: () => Navigator.of(context).maybePop(),
            acoes: [
              IconButton(
                onPressed: _salvando ? null : _salvar,
                tooltip: 'Salvar alterações',
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded,
                        color: Colors.white, size: 24),
              ),
            ],
          ),
          Expanded(
            child: Form(
              key: _chaveForm,
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.telaPadding),
                children: [
                  // 1. Card com Avatar & Identificação
                  MvnCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: escuro
                              ? const Color(0xFF21262D)
                              : AppColors.paletaVerdeSuave,
                          child: Text(
                            _iniciais(u.nome),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: escuro
                                  ? AppColors.paletaLilasSuave
                                  : AppColors.paletaRoxo,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.nome,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                u.email,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textoSuave,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.paletaVerde.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Paciente Virtual Nutri',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.verdeEscuro,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.espacoEntreCards),

                  // 2. Dados Cadastrais
                  MvnCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TituloCard(texto: 'Dados Cadastrais', emoji: '👤'),
                        const SizedBox(height: 14),
                        _campo('Nome Completo', _nomeController, 'Seu nome',
                            validador: (valor) =>
                                (valor ?? '').trim().isEmpty
                                    ? 'Informe seu nome.'
                                    : null),
                        _campo('Telefone / WhatsApp', _telefoneController,
                            '(00) 00000-0000',
                            teclado: TextInputType.phone),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.espacoEntreCards),

                  // 3. Dados Clínicos & Físicos
                  MvnCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TituloCard(texto: 'Dados Clínicos & Físicos', emoji: '⚖️'),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _campo('Idade', _idadeController, '28',
                                  teclado: TextInputType.number,
                                  validador: (valor) => _validarFaixa(
                                      valor, 10, 120,
                                      inteiro: true)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _campo('Altura (m)', _alturaController,
                                  '1.65',
                                  teclado: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  validador: (valor) =>
                                      _validarFaixa(valor, 0.9, 2.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _campo('Peso Atual (kg)', _pesoController,
                                  '68.1',
                                  teclado: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  validador: (valor) =>
                                      _validarFaixa(valor, 20, 400)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _campo('Peso-Meta (kg)',
                                  _pesoMetaController, '65.0',
                                  teclado: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  validador: (valor) =>
                                      _validarFaixa(valor, 20, 400)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _campo('Objetivo Nutricional', _metaController,
                            'Ex: Emagrecimento saudável, Ganho de massa'),
                        if (imc != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: escuro
                                  ? const Color(0xFF161B22)
                                  : AppColors.cinzaSegmento,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: escuro
                                    ? AppColors.bordaEscura
                                    : AppColors.borda,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Índice de Massa Corporal (IMC)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textoSuave,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'IMC atual: ${imc.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: escuro
                                            ? AppColors.paletaLilasSuave
                                            : AppColors.paletaRoxo,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.paletaVerde
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _classificacaoImc(imc),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.verdeEscuro,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.espacoEntreCards),

                  // 4. 🛡️ Segurança Alimentar (Alergias, Condições e Alertas Clínicos)
                  MvnCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.vermelho.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.health_and_safety_rounded,
                                color: AppColors.vermelho,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Seguranca alimentar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.vermelho,
                                    ),
                                  ),
                                  Text(
                                    'Condições críticas comunicadas ao nutricionista',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textoSuave,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Alergias / Restrições
                        _secaoChips(
                          titulo: 'Alergias e Restrições Alimentares',
                          itens: _restricoes,
                          corBadge: AppColors.vermelho,
                          hintAdicionar: 'Ex: Glúten, Lactose, Amendoim',
                          aoRemover: (index) =>
                              setState(() => _restricoes.removeAt(index)),
                          aoAdicionar: (item) => _restricoes.add(item),
                        ),
                        const SizedBox(height: 14),

                        // Condições Médicas
                        _secaoChips(
                          titulo: 'Condições Médicas / Diagnósticos',
                          itens: _condicoesMedicas,
                          corBadge: const Color(0xFFD97706),
                          hintAdicionar: 'Ex: Diabetes Tipo 2, Hipertensão, Refluxo',
                          aoRemover: (index) =>
                              setState(() => _condicoesMedicas.removeAt(index)),
                          aoAdicionar: (item) => _condicoesMedicas.add(item),
                        ),
                        const SizedBox(height: 14),

                        // Observações de Segurança
                        Text(
                          'Observações e Alertas de Segurança',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: escuro
                                ? AppColors.fonteSubtituloClaro
                                : AppColors.fonteSubtitulo,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _obsSegurancaController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText:
                                'Descreva alergias severas, remédios contínuos ou detalhes de segurança clínica...',
                            hintStyle: const TextStyle(
                                fontSize: 12.5, color: AppColors.textoFraco),
                            filled: true,
                            fillColor: escuro
                                ? const Color(0xFF0D1117)
                                : AppColors.fundo,
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borda),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.espacoEntreCards),

                  // 5. 🍽️ Preferências Alimentares (Tipo de Dieta, Favoritos e Rejeitados)
                  MvnCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.paletaVerde.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.restaurant_rounded,
                                color: AppColors.paletaVerde,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Preferências Alimentares',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Seus gostos e hábitos para personalizar seus planos',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textoSuave,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Tipo de Dieta
                        Text(
                          'Padrão / Tipo de Dieta',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: escuro
                                ? AppColors.fonteSubtituloClaro
                                : AppColors.fonteSubtitulo,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _opcoesDieta.contains(_tipoDietaSelecionado)
                              ? _tipoDietaSelecionado
                              : null,
                          hint: const Text('Selecione seu padrão de dieta',
                              style: TextStyle(fontSize: 13, color: AppColors.textoFraco)),
                          items: _opcoesDieta
                              .map((dieta) => DropdownMenuItem(
                                    value: dieta,
                                    child: Text(dieta, style: const TextStyle(fontSize: 13.5)),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _tipoDietaSelecionado = val),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borda),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Alimentos Favoritos
                        _secaoChips(
                          titulo: 'Alimentos Favoritos / Que você mais gosta',
                          itens: _alimentosFavoritos,
                          corBadge: AppColors.paletaVerde,
                          hintAdicionar: 'Ex: Abacate, Aveia, Frango grelhado',
                          aoRemover: (index) =>
                              setState(() => _alimentosFavoritos.removeAt(index)),
                          aoAdicionar: (item) => _alimentosFavoritos.add(item),
                        ),
                        const SizedBox(height: 14),

                        // Alimentos Rejeitados
                        _secaoChips(
                          titulo: 'Alimentos Rejeitados / Que não consome',
                          itens: _alimentosRejeitados,
                          corBadge: AppColors.paletaRoxo,
                          hintAdicionar: 'Ex: Berinjela, Coentro, Fígado',
                          aoRemover: (index) =>
                              setState(() => _alimentosRejeitados.removeAt(index)),
                          aoAdicionar: (item) => _alimentosRejeitados.add(item),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.espacoEntreCards),

                  // 6. 🔒 Privacidade & Compartilhamento
                  MvnCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.paletaRoxo.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.lock_person_rounded,
                                color: AppColors.paletaRoxo,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Privacidade & Compartilhamento',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Controle o que o nutricionista pode visualizar',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textoSuave,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Compartilhar Lista de Compras',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Permite que seu nutricionista veja os itens da sua lista e saiba o que você está comprando.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textoSuave),
                            ),
                            activeThumbColor: AppColors.paletaVerde,
                            activeTrackColor: AppColors.paletaVerde.withValues(alpha: 0.35),
                            value: _compartilharListaCompras,
                            onChanged: (val) =>
                                setState(() => _compartilharListaCompras = val),
                          ),
                        ),
                        const Divider(height: 16),
                        Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Compartilhar Humor e Sintomas',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Permite que seu nutricionista acompanhe seus registros diários de humor, disposição e bem-estar.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textoSuave),
                            ),
                            activeThumbColor: AppColors.paletaVerde,
                            activeTrackColor: AppColors.paletaVerde.withValues(alpha: 0.35),
                            value: _compartilharHumor,
                            onChanged: (val) =>
                                setState(() => _compartilharHumor = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 7. Botão Salvar
                  SizedBox(
                    height: AppSizes.botaoAltura,
                    child: ElevatedButton.icon(
                      onPressed: _salvando ? null : _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.paletaVerde,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.botaoRadius),
                        ),
                        elevation: 0,
                      ),
                      icon: _salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: Text(
                        _salvando ? 'Salvando...' : 'Salvar Alterações',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 8. Botão Sair da Conta
                  OutlinedButton.icon(
                    onPressed: _sair,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sair da conta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textoSuave,
                      side: const BorderSide(color: AppColors.borda),
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 9. Botão Excluir Conta
                  TextButton.icon(
                    onPressed: _excluirConta,
                    icon: const Icon(Icons.delete_forever_rounded,
                        size: 18, color: AppColors.vermelho),
                    label: const Text('Excluir minha conta',
                        style: TextStyle(color: AppColors.vermelho)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoChips({
    required String titulo,
    required List<String> itens,
    required Color corBadge,
    required String hintAdicionar,
    required void Function(int index) aoRemover,
    required void Function(String item) aoAdicionar,
  }) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: escuro
                    ? AppColors.fonteSubtituloClaro
                    : AppColors.fonteSubtitulo,
              ),
            ),
            InkWell(
              onTap: () => _adicionarItemDialog(
                titulo: 'Adicionar Item',
                hint: hintAdicionar,
                aoAdicionar: aoAdicionar,
              ),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.paletaVerde),
                    SizedBox(width: 2),
                    Text(
                      'Adicionar',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.paletaVerde,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (itens.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: escuro ? const Color(0xFF161B22) : AppColors.fundo,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: escuro ? AppColors.bordaEscura : AppColors.borda,
              ),
            ),
            child: const Text(
              'Nenhum item adicionado.',
              style: TextStyle(fontSize: 12, color: AppColors.textoFraco),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
              itens.length,
              (index) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: corBadge.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: corBadge.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      itens[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: corBadge,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => aoRemover(index),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: corBadge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String? _validarFaixa(
    String? valor,
    double minimo,
    double maximo, {
    bool inteiro = false,
  }) {
    final texto = (valor ?? '').replaceAll(',', '.').trim();
    if (texto.isEmpty) return null;
    final numero = double.tryParse(texto);
    if (numero == null) return 'Numero invalido.';
    if (inteiro && numero != numero.roundToDouble()) {
      return 'Use um numero inteiro.';
    }
    if (numero < minimo || numero > maximo) {
      return 'Entre $minimo e $maximo.';
    }
    return null;
  }

  Widget _campo(
    String rotulo,
    TextEditingController controlador,
    String dica, {
    TextInputType teclado = TextInputType.text,
    String? Function(String?)? validador,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.texto),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controlador,
            keyboardType: teclado,
            validator: validador,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: dica,
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppColors.textoFraco),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borda),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.verde, width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _iniciais(String nome) {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }
}
