/// Onboarding do paciente (telas 4.5.5 a 4.5.11 do prototipo).
///
/// Etapas em sequencia, cada uma gravando no perfil (usuarios/{uid}):
///   1. Vincular ao nutricionista informando o e-mail (envio de solicitacao)
///   2. Dados pessoais: idade, sexo, peso, altura (+ peso-meta)
///   3. Nivel de atividade fisica + objetivo nutricional
///   4. Perfil alimentar: tipo de dieta, favoritos, rejeitados
///   5. Restricoes/alergias + condicoes medicas
///   6. Tutorial interativo (5 cartoes) antes do primeiro acesso.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/usuario.dart';
import '../services/api_services.dart';
import '../services/chat_service.dart';
import '../services/mvn_services.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.usuario,
    required this.onboardingService,
    required this.chatService,
    required this.progressoService,
    required this.evolucaoService,
    required this.cardapioService,
    required this.aoConcluir,
    required this.aoFazerLogout,
  });

  final Usuario usuario;
  final OnboardingService onboardingService;
  final ChatService chatService;
  final ProgressoService progressoService;
  final EvolucaoService evolucaoService;
  final CardapioService cardapioService;
  final VoidCallback aoConcluir;
  final VoidCallback aoFazerLogout;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _paginas = PageController();
  int _etapa = 0;
  bool _salvando = false;
  String? _erro;

  static const int _totalEtapas = 6;

  // Etapa 1: solicitacao de vinculo com nutricionista por e-mail.
  final _emailNutricionistaController = TextEditingController();
  bool _pularNutricionista = false;

  // Etapa 2: dados pessoais.
  final _idadeController = TextEditingController();
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();
  final _pesoMetaController = TextEditingController();
  String _genero = 'Feminino';

  // Etapa 3: estilo de vida.
  String _nivelAtividade = 'moderado';
  String _meta = 'Perda de peso';

  // Etapa 4: perfil alimentar.
  final _novoFavorito = TextEditingController();
  final _novoRejeitado = TextEditingController();
  String _tipoDieta = 'Equilibrada';
  final List<String> _favoritos = [];
  final List<String> _rejeitados = [];

  // Etapa 5: restricoes.
  final _novaRestricao = TextEditingController();
  final _novaCondicao = TextEditingController();
  final List<String> _restricoes = [];
  final List<String> _condicoes = [];

  static const List<String> _opcoesGenero = ['Feminino', 'Masculino', 'Outro'];
  static const List<String> _opcoesAtividade = [
    'sedentario',
    'leve',
    'moderado',
    'ativo',
    'muito ativo',
  ];
  static const List<String> _opcoesMeta = [
    'Perda de peso',
    'Ganho de massa',
    'Manutencao',
  ];
  static const List<String> _opcoesDieta = [
    'Equilibrada',
    'Low carb',
    'Vegetariana',
    'Vegana',
    'Sem restricao',
  ];
  static const List<String> _restricoesComuns = [
    'Intolerancia a lactose',
    'Intolerancia a gluten',
    'Alergia a frutos do mar',
    'Alergia a amendoim',
    'Diabetes',
  ];
  static const List<String> _condicoesComuns = [
    'Hipertensao',
    'Colesterol alto',
    'Refluxo',
    'Nenhuma',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-popula com o que ja existe no perfil (onboarding retomado).
    final u = widget.usuario;
    if (u.idade != null) _idadeController.text = u.idade.toString();
    if (u.pesoAtual != null) {
      _pesoController.text = u.pesoAtual!.toStringAsFixed(1);
    }
    if (u.altura != null) _alturaController.text = u.altura.toString();
    if (u.pesoMeta != null) {
      _pesoMetaController.text = u.pesoMeta!.toStringAsFixed(1);
    }
    _genero = u.genero ?? _genero;
    _nivelAtividade = u.nivelAtividade ?? _nivelAtividade;
    _meta = u.meta ?? _meta;
    _tipoDieta = u.tipoDieta ?? _tipoDieta;
    _favoritos.addAll(u.alimentosFavoritos);
    _rejeitados.addAll(u.alimentosRejeitados);
    _restricoes.addAll(u.restricoes);
    _condicoes.addAll(u.condicoesMedicas);
  }

  @override
  void dispose() {
    _paginas.dispose();
    _emailNutricionistaController.dispose();
    _idadeController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    _pesoMetaController.dispose();
    _novoFavorito.dispose();
    _novoRejeitado.dispose();
    _novaRestricao.dispose();
    _novaCondicao.dispose();
    super.dispose();
  }

  Future<void> _avancar() async {
    final emailNutri = _emailNutricionistaController.text.trim();
    if (_etapa == 0 && !_pularNutricionista) {
      if (emailNutri.isEmpty || !emailNutri.contains('@')) {
        _mostrarErro(
          'Informe o e-mail válido do seu nutricionista ou marque a opção para vincular depois.',
        );
        return;
      }
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      switch (_etapa) {
        case 0:
          if (!_pularNutricionista) {
            await widget.onboardingService
                .solicitarNutricionistaPorEmail(emailNutri);
          }
        case 1:
          await widget.onboardingService.salvarDadosPessoais(
            idade: int.parse(_idadeController.text.trim()),
            pesoAtual: double.parse(_pesoController.text.replaceAll(',', '.')),
            altura: double.parse(_alturaController.text.replaceAll(',', '.')),
            genero: _genero,
            pesoMeta: _pesoMetaController.text.trim().isEmpty
                ? null
                : double.parse(
                    _pesoMetaController.text.replaceAll(',', '.')),
          );
        case 2:
          await widget.onboardingService.salvarEstiloVida(
            nivelAtividade: _nivelAtividade,
            meta: _meta,
          );
        case 3:
          await widget.onboardingService.salvarPerfilAlimentar(
            tipoDieta: _tipoDieta,
            favoritos: _favoritos,
            rejeitados: _rejeitados,
          );
        case 4:
          await widget.onboardingService.salvarRestricoes(
            restricoes: _restricoes,
            condicoesMedicas: _condicoes,
          );
          if (!mounted) return;
          setState(() => _etapa = 5);
          _paginas.jumpToPage(5);
          setState(() => _salvando = false);
          return;
        case 5:
          await widget.onboardingService.concluirTutorial();
          if (!mounted) return;
          widget.aoConcluir();
          return;
      }

      if (!mounted) return;
      setState(() {
        _salvando = false;
        _etapa += 1;
      });
      _paginas.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _salvando = false;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _erro = 'Verifique os numeros informados (use ponto ou virgula).';
        _salvando = false;
      });
    }
  }

  void _voltar() {
    if (_etapa == 0) return;
    setState(() => _etapa -= 1);
    _paginas.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: AppColors.vermelho),
    );
  }

  bool get _ehEscuro => Theme.of(context).brightness == Brightness.dark;
  Color get _corTitulo => _ehEscuro ? AppColors.paletaClaro : AppColors.texto;
  Color get _corSubtitulo =>
      _ehEscuro ? AppColors.fonteSubtituloClaro : AppColors.textoSuave;
  Color get _corBorda => _ehEscuro ? AppColors.bordaEscura : AppColors.borda;
  Color get _corSuperficie =>
      _ehEscuro ? AppColors.paletaEscuroCard : Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Vamos configurar seu perfil',
            icone: Icons.person_outline_rounded,
            acoes: [
              IconButton(
                onPressed: widget.aoFazerLogout,
                tooltip: 'Sair',
                icon: const Icon(Icons.logout, color: Colors.white, size: 22),
              ),
            ],
          ),
          _indicadorEtapas(),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _erro!,
                style: const TextStyle(color: AppColors.vermelho, fontSize: 13),
              ),
            ),
          Expanded(
            child: PageView(
              controller: _paginas,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _etapaNutricionista(),
                _etapaDadosPessoais(),
                _etapaEstiloVida(),
                _etapaPerfilAlimentar(),
                _etapaRestricoes(),
                _etapaTutorial(),
              ],
            ),
          ),
          _barraInferior(),
        ],
      ),
    );
  }

  Widget _indicadorEtapas() {
    return Container(
      decoration: BoxDecoration(
        color: _corSuperficie,
        border: Border(bottom: BorderSide(color: _corBorda)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (_etapa + 1) / _totalEtapas,
                minHeight: 8,
                backgroundColor:
                    _ehEscuro ? AppColors.bordaEscura : AppColors.cinzaTrilha,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.verdeBarra),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Etapa ${_etapa + 1}/$_totalEtapas',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _corSubtitulo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraInferior() {
    return Container(
      decoration: BoxDecoration(
        color: _corSuperficie,
        border: Border(top: BorderSide(color: _corBorda)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (_etapa > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _salvando ? null : _voltar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _corSubtitulo,
                  side: BorderSide(color: _corBorda),
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Voltar'),
              ),
            ),
          if (_etapa > 0) const SizedBox(width: 12),
          Expanded(
            flex: _etapa == 0 ? 1 : 2,
            child: BotaoGradiente(
              texto: _etapa == _totalEtapas - 1 ? 'Comecar a usar' : 'Continuar',
              icone: _etapa == _totalEtapas - 1
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
              aoTocar: _salvando ? null : _avancar,
              carregando: _salvando,
            ),
          ),
        ],
      ),
    );
  }

  // ================= Etapa 1: nutricionista (por e-mail) =================
  Widget _etapaNutricionista() {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        Text(
          'Vincule seu nutricionista',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Informe o e-mail do seu nutricionista para enviar uma solicitação de acompanhamento. Assim que ele aceitar, seu cardápio e orientações ficarão disponíveis.',
          style: TextStyle(fontSize: 13, color: _corSubtitulo, height: 1.4),
        ),
        const SizedBox(height: 18),
        MvnCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _ehEscuro
                          ? const Color(0xFF21262D)
                          : AppColors.paletaLilasSuave,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: _ehEscuro
                          ? AppColors.paletaLilasSuave
                          : AppColors.paletaRoxo,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solicitação de vínculo',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _corTitulo,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Digite o e-mail cadastrado pelo seu nutricionista',
                          style: TextStyle(
                            fontSize: 12,
                            color: _corSubtitulo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailNutricionistaController,
                enabled: !_pularNutricionista,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: TextStyle(color: _corTitulo, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'E-mail do nutricionista',
                  hintText: 'exemplo@nutri.com',
                  labelStyle: TextStyle(color: _corSubtitulo, fontSize: 13),
                  hintStyle: TextStyle(color: _corSubtitulo, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    color: _ehEscuro
                        ? AppColors.verdeClaro
                        : AppColors.verdeEscuro,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: _ehEscuro
                      ? const Color(0xFF0D1117)
                      : AppColors.cinzaCampo,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _corBorda),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _corBorda.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.verde, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  _pularNutricionista = !_pularNutricionista;
                  _erro = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _pularNutricionista,
                        activeColor: AppColors.verde,
                        onChanged: (v) => setState(() {
                          _pularNutricionista = v ?? false;
                          _erro = null;
                        }),
                      ),
                      Expanded(
                        child: Text(
                          'Ainda não tenho nutricionista (vincular mais tarde na aba Meu Nutri)',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _corSubtitulo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= Etapa 2: dados pessoais =================
  Widget _etapaDadosPessoais() {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        Text(
          'Dados pessoais',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 16),
        MvnCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Idade',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _corTitulo,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _idadeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _corTitulo),
                      decoration: _decoracaoCampo(sufixo: 'anos'),
                    ),
                  ),
                ],
              ),
              Divider(height: 22, color: _corBorda),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Peso atual',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _corTitulo,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _pesoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _corTitulo),
                      decoration: _decoracaoCampo(sufixo: 'kg'),
                    ),
                  ),
                ],
              ),
              Divider(height: 22, color: _corBorda),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Altura',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _corTitulo,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _alturaController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _corTitulo),
                      decoration: _decoracaoCampo(sufixo: 'm'),
                    ),
                  ),
                ],
              ),
              Divider(height: 22, color: _corBorda),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Peso-meta (opcional)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _corTitulo,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _pesoMetaController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _corTitulo),
                      decoration: _decoracaoCampo(sufixo: 'kg'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Sexo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _opcoesGenero
              .map((g) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: g == _opcoesGenero.last ? 0 : 8),
                      child: ChoiceChip(
                        label: Center(child: Text(g)),
                        selected: _genero == g,
                        onSelected: (_) => setState(() => _genero = g),
                        backgroundColor: _corSuperficie,
                        selectedColor: AppColors.verde,
                        side: BorderSide(
                          color: _genero == g ? AppColors.verde : _corBorda,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _genero == g ? Colors.white : _corSubtitulo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ================= Etapa 3: estilo de vida =================
  Widget _etapaEstiloVida() {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        Text(
          'Estilo de vida',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Nivel de atividade fisica e objetivo nutricional.',
          style: TextStyle(fontSize: 13, color: _corSubtitulo),
        ),
        const SizedBox(height: 16),
        Text(
          'Nivel de atividade',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 10),
        ..._opcoesAtividade.map(
          (opcao) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OpcaoSelecionavel(
              rotulo: opcao[0].toUpperCase() + opcao.substring(1),
              selecionado: _nivelAtividade == opcao,
              aoTocar: () => setState(() => _nivelAtividade = opcao),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Objetivo nutricional',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 10),
        ..._opcoesMeta.map(
          (opcao) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OpcaoSelecionavel(
              rotulo: opcao,
              icone: opcao.contains('Perda')
                  ? Icons.south_rounded
                  : opcao.contains('Ganho')
                      ? Icons.north_rounded
                      : Icons.trending_flat_rounded,
              selecionado: _meta == opcao,
              aoTocar: () => setState(() => _meta = opcao),
            ),
          ),
        ),
      ],
    );
  }

  // ================= Etapa 4: perfil alimentar =================
  Widget _etapaPerfilAlimentar() {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        Text(
          'Perfil alimentar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Essas informacoes vao direto para o seu nutricionista.',
          style: TextStyle(fontSize: 13, color: _corSubtitulo),
        ),
        const SizedBox(height: 16),
        Text(
          'Tipo de dieta',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _opcoesDieta
              .map((d) => ChoiceChip(
                    label: Text(d),
                    selected: _tipoDieta == d,
                    onSelected: (_) => setState(() => _tipoDieta = d),
                    backgroundColor: _corSuperficie,
                    selectedColor: AppColors.verde,
                    side: BorderSide(
                      color: _tipoDieta == d ? AppColors.verde : _corBorda,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: _tipoDieta == d ? Colors.white : _corSubtitulo,
                      fontWeight: FontWeight.w600,
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        _EditorChips(
          titulo: 'Alimentos favoritos',
          dica: 'Ex.: frango, batata doce...',
          controlador: _novoFavorito,
          itens: _favoritos,
          aoAdicionar: (v) => setState(() => _favoritos.add(v)),
          aoRemover: (v) => setState(() => _favoritos.remove(v)),
        ),
        const SizedBox(height: 14),
        _EditorChips(
          titulo: 'Alimentos rejeitados',
          dica: 'Ex.: peixe frito...',
          controlador: _novoRejeitado,
          itens: _rejeitados,
          aoAdicionar: (v) => setState(() => _rejeitados.add(v)),
          aoRemover: (v) => setState(() => _rejeitados.remove(v)),
        ),
      ],
    );
  }

  // ================= Etapa 5: restricoes =================
  Widget _etapaRestricoes() {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        Text(
          'Restricoes e saude',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Informacoes essenciais para um plano alimentar seguro.',
          style: TextStyle(fontSize: 13, color: _corSubtitulo),
        ),
        const SizedBox(height: 16),
        Text(
          'Alergias e intolerancias',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _restricoesComuns
              .map((r) => FilterChip(
                    label: Text(r),
                    selected: _restricoes.contains(r),
                    onSelected: (marcado) => setState(() {
                      if (marcado) {
                        _restricoes.add(r);
                      } else {
                        _restricoes.remove(r);
                      }
                    }),
                    backgroundColor: _corSuperficie,
                    selectedColor: _ehEscuro
                        ? AppColors.paletaRoxo.withValues(alpha: 0.35)
                        : AppColors.paletaLilasSuave,
                    checkmarkColor: _ehEscuro
                        ? AppColors.paletaLilasSuave
                        : AppColors.paletaRoxo,
                    side: BorderSide(
                      color: _restricoes.contains(r)
                          ? AppColors.paletaRoxo
                          : _corBorda,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: _restricoes.contains(r)
                          ? (_ehEscuro
                              ? AppColors.paletaLilasSuave
                              : AppColors.paletaRoxo)
                          : _corSubtitulo,
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),
        _EditorChips(
          titulo: 'Outras restricoes',
          dica: 'Descreva outra restricao...',
          controlador: _novaRestricao,
          itens: _restricoes
              .where((r) => !_restricoesComuns.contains(r))
              .toList(),
          aoAdicionar: (v) => setState(() => _restricoes.add(v)),
          aoRemover: (v) => setState(() => _restricoes.remove(v)),
        ),
        const SizedBox(height: 14),
        Text(
          'Condicoes medicas',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _condicoesComuns
              .map((c) => FilterChip(
                    label: Text(c),
                    selected: _condicoes.contains(c),
                    onSelected: (marcado) => setState(() {
                      if (marcado && c != 'Nenhuma') {
                        _condicoes.add(c);
                      } else {
                        _condicoes.remove(c);
                      }
                    }),
                    backgroundColor: _corSuperficie,
                    selectedColor: _ehEscuro
                        ? AppColors.paletaRoxo.withValues(alpha: 0.35)
                        : AppColors.paletaLilasSuave,
                    checkmarkColor: _ehEscuro
                        ? AppColors.paletaLilasSuave
                        : AppColors.paletaRoxo,
                    side: BorderSide(
                      color: _condicoes.contains(c)
                          ? AppColors.paletaRoxo
                          : _corBorda,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: _condicoes.contains(c)
                          ? (_ehEscuro
                              ? AppColors.paletaLilasSuave
                              : AppColors.paletaRoxo)
                          : _corSubtitulo,
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),
        _EditorChips(
          titulo: 'Outras condicoes',
          dica: 'Descreva outra condicao...',
          controlador: _novaCondicao,
          itens: _condicoes
              .where((c) => !_condicoesComuns.contains(c))
              .toList(),
          aoAdicionar: (v) => setState(() => _condicoes.add(v)),
          aoRemover: (v) => setState(() => _condicoes.remove(v)),
        ),
      ],
    );
  }

  // ================= Etapa 6: tutorial =================
  Widget _etapaTutorial() {
    const cartoes = [
      ('🍽️', 'Cardapio',
          'Consulte as refeicoes do dia, marque o que ja comeu e acompanhe as calorias em tempo real.'),
      ('💧', 'Hidratacao',
          'Registre seus copos de agua diarios na aba Bem-Estar e mantenha o corpo hidratado.'),
      ('📈', 'Progresso',
          'Registre seu peso, acompanhe os graficos de evolucao e veja o quao perto da meta voce esta.'),
      ('💬', 'Chat com o nutricionista',
          'Tire duvidas e receba feedbacks direto do seu nutricionista pelo chat do app.'),
      ('🛒', 'Lista de compras',
          'O app monta automaticamente a lista de compras com os ingredientes do seu plano semanal.'),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        Text(
          'Bem-vindo(a)!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _corTitulo,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Um tour rapido pelo que voce pode fazer no Meu Virtual Nutri:',
          style: TextStyle(fontSize: 13, color: _corSubtitulo),
        ),
        const SizedBox(height: 16),
        for (final (emoji, titulo, descricao) in cartoes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MvnCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _corTitulo,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          descricao,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _corSubtitulo,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _decoracaoCampo({required String sufixo}) => InputDecoration(
        suffixText: sufixo,
        suffixStyle: TextStyle(color: _corSubtitulo, fontSize: 12),
        isDense: true,
        filled: true,
        fillColor:
            _ehEscuro ? const Color(0xFF0D1117) : AppColors.cinzaCampo,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _corBorda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.verde, width: 1.6),
        ),
      );
}

class _OpcaoSelecionavel extends StatelessWidget {
  const _OpcaoSelecionavel({
    required this.rotulo,
    required this.selecionado,
    required this.aoTocar,
    this.icone,
  });

  final String rotulo;
  final bool selecionado;
  final VoidCallback aoTocar;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final corFundo = selecionado
        ? (escuro
            ? AppColors.verde.withValues(alpha: 0.18)
            : AppColors.paletaVerdeSuave)
        : (escuro ? AppColors.paletaEscuroCard : Colors.white);
    final corTexto = escuro ? AppColors.paletaClaro : AppColors.texto;
    final corSub =
        escuro ? AppColors.fonteSubtituloClaro : AppColors.textoSuave;
    final corBorda = selecionado
        ? AppColors.verde
        : (escuro ? AppColors.bordaEscura : AppColors.borda);

    return Material(
      color: corFundo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: aoTocar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: corBorda,
              width: selecionado ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icone != null) ...[
                Icon(
                  icone,
                  size: 20,
                  color: selecionado ? AppColors.verde : corSub,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
                    color: corTexto,
                  ),
                ),
              ),
              if (selecionado)
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.verde,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorChips extends StatelessWidget {
  const _EditorChips({
    required this.titulo,
    required this.dica,
    required this.controlador,
    required this.itens,
    required this.aoAdicionar,
    required this.aoRemover,
  });

  final String titulo;
  final String dica;
  final TextEditingController controlador;
  final List<String> itens;
  final void Function(String) aoAdicionar;
  final void Function(String) aoRemover;

  void _adicionar() {
    final valor = controlador.text.trim();
    if (valor.isEmpty) return;
    aoAdicionar(valor);
    controlador.clear();
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final corTexto = escuro ? AppColors.paletaClaro : AppColors.texto;
    final corSub =
        escuro ? AppColors.fonteSubtituloClaro : AppColors.textoSuave;
    final corBorda = escuro ? AppColors.bordaEscura : AppColors.borda;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: corTexto,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: itens
              .map(
                (item) => InputChip(
                  label: Text(
                    item,
                    style: TextStyle(fontSize: 12.5, color: corTexto),
                  ),
                  deleteIconColor: corSub,
                  onDeleted: () => aoRemover(item),
                  backgroundColor: escuro
                      ? const Color(0xFF21262D)
                      : AppColors.cinzaSegmento,
                  side: BorderSide(color: corBorda),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controlador,
          style: TextStyle(color: corTexto, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: dica,
            hintStyle: TextStyle(fontSize: 13, color: corSub),
            isDense: true,
            filled: true,
            fillColor: escuro ? AppColors.paletaEscuroCard : Colors.white,
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.verde,
              ),
              onPressed: _adicionar,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: corBorda),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.verde),
            ),
          ),
          onSubmitted: (_) => _adicionar(),
        ),
      ],
    );
  }
}
