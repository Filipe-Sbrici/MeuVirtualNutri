/// Tela central do perfil paciente.
///
/// Organizada nas abas de navegacao inferior:
/// Início (Home/Dashboard), Cardápio, Meu Nutri (chat), Progresso e Config.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/cardapio.dart';
import '../models/usuario.dart';
import '../services/api_services.dart';
import '../services/chat_service.dart';
import '../services/mvn_services.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/common.dart';
import 'bem_estar_screen.dart';
import 'configuracoes_screen.dart';
import 'evolucao_screen.dart';
import 'meu_nutri_screen.dart';
import 'progresso_screen.dart';

class PacienteHomeScreen extends StatefulWidget {
  const PacienteHomeScreen({
    super.key,
    required this.usuario,
    required this.authService,
    required this.onboardingService,
    required this.chatService,
    required this.progressoService,
    required this.evolucaoService,
    required this.cardapioService,
    required this.aoAtualizarUsuario,
    required this.aoFazerLogout,
  });

  final Usuario usuario;
  final AuthService authService;
  final OnboardingService onboardingService;
  final ChatService chatService;
  final ProgressoService progressoService;
  final EvolucaoService evolucaoService;
  final CardapioService cardapioService;
  final void Function(Usuario usuario) aoAtualizarUsuario;
  final VoidCallback aoFazerLogout;

  @override
  State<PacienteHomeScreen> createState() => _PacienteHomeScreenState();
}

enum _SubTelaPaciente {
  planoSemanal,
  listaCompras,
  minhasReceitas,
  bemEstar,
  evolucao,
}

class _PacienteHomeScreenState extends State<PacienteHomeScreen> {
  AbaNavegacao _aba = AbaNavegacao.inicio;
  _SubTelaPaciente? _subTela;

  // Cardapio do dia.
  CardapioDoDia? _cardapio;
  bool _carregandoCardapio = true;
  String? _erroCardapio;
  Timer? _timerNaoLidas;

  // Bem-Estar.
  int _coposAgua = 0;
  String? _humorDeHoje;
  int _naoLidas = 0;

  @override
  void initState() {
    super.initState();
    _carregarCardapio();
    _carregarBemEstar();
    _iniciarMonitorNaoLidas();
  }

  @override
  void dispose() {
    _timerNaoLidas?.cancel();
    super.dispose();
  }

  void _iniciarMonitorNaoLidas() {
    _timerNaoLidas = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final total = await widget.chatService.contarNaoLidas();
        if (mounted && total != _naoLidas) {
          setState(() => _naoLidas = total);
        }
      } on ApiException {
        // silencioso: banner e secundario
      }
    });
  }

  Future<void> _carregarCardapio() async {
    setState(() {
      _carregandoCardapio = true;
      _erroCardapio = null;
    });
    try {
      final cardapio = await widget.cardapioService.carregarHoje();
      if (!mounted) return;
      setState(() {
        _cardapio = cardapio;
        _carregandoCardapio = false;
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erroCardapio = erro.mensagem;
        _carregandoCardapio = false;
      });
    }
  }

  Future<void> _alternarRefeicao(Refeicao refeicao) async {
    try {
      final resumo = await widget.cardapioService.alternarRefeicao(
        dia: refeicao.dia,
        tipo: refeicao.tipo,
        concluida: !refeicao.concluida,
      );
      if (!mounted) return;
      await _carregarCardapio();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(refeicao.concluida
              ? 'Refeição desmarcada.'
              : '${refeicao.rotuloTipo} concluída! ${resumo.caloriasConcluidas.round()} kcal até agora.'),
          backgroundColor:
              refeicao.concluida ? AppColors.fonteSubtitulo : AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem), backgroundColor: AppColors.vermelho),
      );
    }
  }

  /// Recupera hidratacao e humor ja registrados hoje.
  Future<void> _carregarBemEstar() async {
    try {
      final progresso = await widget.progressoService.carregar();
      if (!mounted) return;
      setState(() {
        _coposAgua = progresso.hoje.coposAgua;
        _humorDeHoje = progresso.hoje.humor;
      });
    } on ApiException {
      // silencioso
    }
  }

  Future<void> _registrarAgua(int copos) async {
    final clampCopos = copos.clamp(0, 20);
    setState(() => _coposAgua = clampCopos);
    try {
      await widget.progressoService.registrarAgua(coposAgua: clampCopos);
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem), backgroundColor: AppColors.vermelho),
      );
    }
  }

  Future<void> _registrarHumor(String humor) async {
    try {
      await widget.progressoService.registrarHumor(humor: humor);
      if (!mounted) return;
      setState(() => _humorDeHoje = humor);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Humor registrado. Tenha um excelente dia!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem), backgroundColor: AppColors.vermelho),
      );
    }
  }

  // ---------------- Navegacao ----------------

  void _abrirMeuNutri() {
    setState(() {
      _aba = AbaNavegacao.meuNutri;
      _subTela = null;
    });
  }

  void _abrirEvolucao() {
    setState(() => _subTela = _SubTelaPaciente.evolucao);
  }

  void _abrirPlanoSemanal() {
    setState(() => _subTela = _SubTelaPaciente.planoSemanal);
  }

  void _abrirListaCompras() {
    setState(() => _subTela = _SubTelaPaciente.listaCompras);
  }

  void _abrirMinhasReceitas() {
    setState(() => _subTela = _SubTelaPaciente.minhasReceitas);
  }

  void _abrirBemEstar() {
    setState(() => _subTela = _SubTelaPaciente.bemEstar);
  }

  void _aoSelecionarAba(AbaNavegacao aba) {
    setState(() {
      _aba = aba;
      _subTela = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _corpo(),
      bottomNavigationBar: BottomNav(
        abaAtiva: _aba,
        aoSelecionar: _aoSelecionarAba,
      ),
    );
  }

  Widget _corpo() {
    if (_subTela != null) {
      switch (_subTela!) {
        case _SubTelaPaciente.planoSemanal:
          return PlanoSemanalScreen(
            cardapioService: widget.cardapioService,
            aoVoltar: () => setState(() => _subTela = null),
          );
        case _SubTelaPaciente.listaCompras:
          return ListaComprasScreen(
            cardapioService: widget.cardapioService,
            aoVoltar: () => setState(() => _subTela = null),
          );
        case _SubTelaPaciente.minhasReceitas:
          return MinhasReceitasScreen(
            cardapioService: widget.cardapioService,
            aoVoltar: () => setState(() => _subTela = null),
          );
        case _SubTelaPaciente.bemEstar:
          return BemEstarScreen(
            coposAgua: _coposAgua,
            humorInicial: _humorDeHoje,
            naoLidas: _naoLidas,
            aoRegistrarAgua: _registrarAgua,
            aoRegistrarHumor: _registrarHumor,
            aoAbrirChat: _abrirMeuNutri,
            aoAbrirListaCompras: _abrirListaCompras,
            aoAbrirMinhasReceitas: _abrirMinhasReceitas,
            aoVoltar: () => setState(() => _subTela = null),
          );
        case _SubTelaPaciente.evolucao:
          return EvolucaoScreen(
            evolucaoService: widget.evolucaoService,
            aoSelecionarAba: _aoSelecionarAba,
            aoVoltar: () => setState(() => _subTela = null),
          );
      }
    }

    switch (_aba) {
      case AbaNavegacao.inicio:
        return _abaInicio();
      case AbaNavegacao.cardapio:
        return _abaCardapio();
      case AbaNavegacao.meuNutri:
        return MeuNutriScreen(
          usuario: widget.usuario,
          chatService: widget.chatService,
          cardapioService: widget.cardapioService,
        );
      case AbaNavegacao.progresso:
        return _abaProgresso();
      case AbaNavegacao.perfil:
        return ConfiguracoesScreen(
          usuario: widget.usuario,
          authService: widget.authService,
          onboardingService: widget.onboardingService,
          aoAtualizarUsuario: widget.aoAtualizarUsuario,
          aoFazerLogout: widget.aoFazerLogout,
        );
    }
  }

  // ---------------- Aba Início (Home Dashboard) ----------------

  Widget _abaInicio() {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final refeicoes = _cardapio?.refeicoes ?? const <Refeicao>[];
    final resumo = _cardapio?.resumo;
    final proximaRefeicao = refeicoes.where((r) => !r.concluida).firstOrNull ??
        refeicoes.firstOrNull;

    return Column(
      children: [
        GradientHeader(
          titulo: 'Olá, ${_primeiroNome(widget.usuario.nome)}!',
          subtitulo: 'Painel do Paciente • Hoje',
          icone: Icons.spa_rounded,
          gradiente: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.paletaRoxo, Color(0xFF6B21A8)],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.paletaVerde,
            onRefresh: () async {
              await Future.wait([_carregarCardapio(), _carregarBemEstar()]);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.telaPadding),
              children: [
                // Banner de Mensagens Não Lidas (se houver)
                if (_naoLidas > 0) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.espacoEntreCards),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.paletaRoxo, Color(0xFF6B21A8)],
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.paletaRoxo.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        onTap: _abrirMeuNutri,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mark_chat_unread_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Mensagem do Nutricionista',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Você tem $_naoLidas mensagem(ns) não lida(s). Toque para responder.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // 1. Resumo Nutricional e Progresso do Dia
                MvnCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.pie_chart_outline_rounded,
                                  size: 18, color: AppColors.paletaVerde),
                              SizedBox(width: 6),
                              Text(
                                'Metas de Hoje',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (resumo != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: escuro
                                    ? const Color(0xFF21262D)
                                    : AppColors.paletaVerdeSuave,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${resumo.concluidas}/${resumo.total} refeições',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: escuro
                                      ? AppColors.paletaVerde
                                      : AppColors.fonteTitulo,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (resumo != null && resumo.totalCalorias > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Calorias Consumidas',
                              style: TextStyle(
                                fontSize: 12,
                                color: escuro
                                    ? AppColors.fonteSubtituloClaro
                                    : AppColors.fonteSubtitulo,
                              ),
                            ),
                            Text(
                              '${resumo.caloriasConcluidas.round()} / ${resumo.totalCalorias.round()} kcal (${resumo.percentual.round()}%)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.paletaVerde,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (resumo.percentual / 100).clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: escuro
                                ? const Color(0xFF21262D)
                                : AppColors.cinzaTrilha,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.paletaVerde),
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Nenhum plano alimentar montado para hoje.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: escuro
                                  ? AppColors.fonteSubtituloClaro
                                  : AppColors.fonteSubtitulo,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.espacoEntreCards),

                // 2. Próxima Refeição em Destaque
                if (proximaRefeicao != null) ...[
                  MvnCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              proximaRefeicao.concluida
                                  ? 'Última Refeição'
                                  : 'Próxima Refeição',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: escuro
                                    ? AppColors.paletaLilasSuave
                                    : AppColors.paletaRoxo,
                              ),
                            ),
                            if (proximaRefeicao.horario != null)
                              Text(
                                proximaRefeicao.horario!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: escuro
                                      ? AppColors.fonteSubtituloClaro
                                      : AppColors.fontePlaceholder,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _alternarRefeicao(proximaRefeicao),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: proximaRefeicao.concluida
                                      ? AppColors.paletaVerde
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: proximaRefeicao.concluida
                                        ? AppColors.paletaVerde
                                        : AppColors.bordaCinza,
                                    width: 2,
                                  ),
                                ),
                                child: proximaRefeicao.concluida
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 20)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    proximaRefeicao.rotuloTipo,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.paletaVerde,
                                    ),
                                  ),
                                  Text(
                                    proximaRefeicao.nomeReceita.isEmpty
                                        ? 'A definir'
                                        : proximaRefeicao.nomeReceita,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: escuro
                                          ? AppColors.paletaClaro
                                          : AppColors.fonteTitulo,
                                      decoration: proximaRefeicao.concluida
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  Text(
                                    '${proximaRefeicao.calorias.round()} kcal • '
                                    'P ${proximaRefeicao.proteinas.round()}g • '
                                    'C ${proximaRefeicao.carboidratos.round()}g • '
                                    'G ${proximaRefeicao.gorduras.round()}g',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: escuro
                                          ? AppColors.fonteSubtituloClaro
                                          : AppColors.fontePlaceholder,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _aba = AbaNavegacao.cardapio),
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 16),
                            label: const Text('Ver cardápio completo'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.paletaVerde,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.espacoEntreCards),
                ],

                // 3. Hidratação Rápida (Água)
                MvnCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.water_drop_rounded,
                                  size: 18, color: Color(0xFF60A5FA)),
                              SizedBox(width: 6),
                              Text(
                                'Hidratação Diária',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$_coposAgua / 8 copos (${_coposAgua * 250} ml)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF60A5FA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _coposAgua > 0
                                ? () => _registrarAgua(_coposAgua - 1)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.vermelho, size: 24),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: (_coposAgua / 8).clamp(0.0, 1.0),
                                minHeight: 12,
                                backgroundColor: escuro
                                    ? const Color(0xFF21262D)
                                    : AppColors.cinzaTrilha,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF60A5FA)),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _registrarAgua(_coposAgua + 1),
                            icon: const Icon(Icons.add_circle,
                                color: Color(0xFF60A5FA), size: 26),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.espacoEntreCards),

                // 4. Humor do Dia
                MvnCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('😊', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 6),
                          Text(
                            'Como você está hoje?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ('otimo', '😄', 'Ótimo'),
                          ('bom', '🙂', 'Bom'),
                          ('regular', '😐', 'Regular'),
                          ('ruim', '😞', 'Ruim'),
                        ].map((h) {
                          final selecionado = _humorDeHoje == h.$1;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Material(
                                color: selecionado
                                    ? AppColors.paletaVerde
                                    : (escuro
                                        ? const Color(0xFF21262D)
                                        : AppColors.cinzaSegmento),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _registrarHumor(h.$1),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      children: [
                                        Text(h.$2,
                                            style:
                                                const TextStyle(fontSize: 20)),
                                        const SizedBox(height: 2),
                                        Text(
                                          h.$3,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: selecionado
                                                ? Colors.white
                                                : (escuro
                                                    ? AppColors
                                                        .fonteSubtituloClaro
                                                    : AppColors.fonteSubtitulo),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.espacoEntreCards),

                // 5. Atalhos Rápidos
                Row(
                  children: [
                    Expanded(
                      child: _CardAtalho(
                        icone: Icons.calendar_view_week_rounded,
                        titulo: 'Plano Semanal',
                        subtitulo: 'Cardápio dos 7 dias',
                        corIcone: AppColors.paletaVerde,
                        aoTocar: _abrirPlanoSemanal,
                      ),
                    ),
                    const SizedBox(width: AppSizes.espacoEntreCards),
                    Expanded(
                      child: _CardAtalho(
                        icone: Icons.shopping_cart_outlined,
                        titulo: 'Lista Compras',
                        subtitulo: 'Ingredientes da semana',
                        corIcone: const Color(0xFF60A5FA),
                        aoTocar: _abrirListaCompras,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),
                Row(
                  children: [
                    Expanded(
                      child: _CardAtalho(
                        icone: Icons.menu_book_rounded,
                        titulo: 'Minhas Receitas',
                        subtitulo: 'Receitas compartilhadas',
                        corIcone: const Color(0xFFF59E0B),
                        aoTocar: _abrirMinhasReceitas,
                      ),
                    ),
                    const SizedBox(width: AppSizes.espacoEntreCards),
                    Expanded(
                      child: _CardAtalho(
                        icone: Icons.insights_rounded,
                        titulo: 'Evolução',
                        subtitulo: 'Gráficos e histórico',
                        corIcone: AppColors.paletaRoxo,
                        aoTocar: _abrirEvolucao,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),
                BotaoGradiente(
                  texto: 'BEM-ESTAR DO DIA',
                  icone: Icons.favorite_rounded,
                  aoTocar: _abrirBemEstar,
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Aba Progresso ----------------

  Widget _abaProgresso() {
    return ProgressoScreen(
      progressoService: widget.progressoService,
      aoAbrirEvolucao: _abrirEvolucao,
      aoSelecionarAba: _aoSelecionarAba,
      exibirBottomNav: false,
    );
  }

  // ---------------- Aba Cardapio ----------------

  Widget _abaCardapio() {
    return Column(
      children: [
        GradientHeader(
          titulo: 'Olá, ${_primeiroNome(widget.usuario.nome)}!',
          subtitulo: _cardapio?.nomePlano ?? 'Seu cardápio de hoje',
          icone: Icons.restaurant_menu_rounded,
          gradiente: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.paletaRoxo, Color(0xFF6B21A8)],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.paletaVerde,
            onRefresh: _carregarCardapio,
            child: _conteudoCardapio(),
          ),
        ),
      ],
    );
  }

  Widget _conteudoCardapio() {
    if (_carregandoCardapio) return const CarregandoView();
    if (_erroCardapio != null) {
      return ErroView(mensagem: _erroCardapio!, aoTentar: _carregarCardapio);
    }

    final refeicoes = _cardapio?.refeicoes ?? const <Refeicao>[];
    final resumo = _cardapio?.resumo;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        if (resumo != null && resumo.total > 0) ...[
          MvnCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Progresso de hoje',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${resumo.concluidas}/${resumo.total} refeições',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.fonteSubtitulo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (resumo.percentual / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: AppColors.cinzaTrilha,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.paletaVerde),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${resumo.caloriasConcluidas.round()} / ${resumo.totalCalorias.round()} kcal',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.fonteSubtitulo,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.espacoEntreCards),
        ],

        if (refeicoes.isEmpty)
          const MvnCard(
            padding: EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            child: Column(
              children: [
                Icon(Icons.no_meals_outlined,
                    size: 40, color: AppColors.fontePlaceholder),
                SizedBox(height: 10),
                Text(
                  'Nenhuma refeição planejada para hoje.\nSeu nutricionista ainda não montou este dia do plano.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.fonteSubtitulo),
                ),
              ],
            ),
          )
        else
          for (final refeicao in refeicoes) ...[
            _CartaoRefeicao(
              refeicao: refeicao,
              aoAlternar: () => _alternarRefeicao(refeicao),
            ),
            const SizedBox(height: AppSizes.espacoEntreCards),
          ],

        BotaoGradiente(
          texto: 'VER PLANO SEMANAL',
          icone: Icons.calendar_view_week_rounded,
          gradiente: AppColors.gradienteAuth,
          aoTocar: _abrirPlanoSemanal,
        ),
        const SizedBox(height: AppSizes.espacoEntreCards),
        BotaoGradiente(
          texto: 'BEM-ESTAR DO DIA',
          icone: Icons.favorite_rounded,
          aoTocar: _abrirBemEstar,
        ),
        const SizedBox(height: AppSizes.espacoEntreCards),
      ],
    );
  }

  static String _primeiroNome(String nome) =>
      nome.split(' ').firstOrNull ?? nome;
}

class _CardAtalho extends StatelessWidget {
  const _CardAtalho({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.corIcone,
    required this.aoTocar,
  });

  final IconData icone;
  final String titulo;
  final String subtitulo;
  final Color corIcone;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: escuro ? AppColors.paletaEscuroCard : AppColors.branco,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      elevation: escuro ? 0 : 1,
      shadowColor: const Color(0x1A000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        onTap: aoTocar,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: escuro
                ? Border.all(color: AppColors.bordaEscura, width: 1)
                : Border.all(color: AppColors.bordaClara.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: corIcone.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, color: corIcone, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: TextStyle(
                  fontSize: 11,
                  color: escuro
                      ? AppColors.fonteSubtituloClaro
                      : AppColors.fontePlaceholder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartao de refeicao do checklist vertical (tela 4.5.12).
class _CartaoRefeicao extends StatelessWidget {
  const _CartaoRefeicao({required this.refeicao, required this.aoAlternar});

  final Refeicao refeicao;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    final concluida = refeicao.concluida;
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return MvnCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: aoAlternar,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: concluida ? AppColors.paletaVerde : Colors.transparent,
                border: Border.all(
                  color: concluida ? AppColors.paletaVerde : AppColors.bordaCinza,
                  width: 2,
                ),
              ),
              child: concluida
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 20)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      refeicao.rotuloTipo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: escuro
                            ? AppColors.paletaLilasSuave
                            : AppColors.paletaRoxo,
                      ),
                    ),
                    if (refeicao.horario != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        refeicao.horario!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: escuro
                              ? AppColors.fonteSubtituloClaro
                              : AppColors.fontePlaceholder,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  refeicao.nomeReceita.isEmpty
                      ? 'A definir'
                      : refeicao.nomeReceita,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
                    decoration:
                        concluida ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${refeicao.calorias.round()} kcal • '
                  'P ${refeicao.proteinas.round()}g • '
                  'C ${refeicao.carboidratos.round()}g • '
                  'G ${refeicao.gorduras.round()}g',
                  style: TextStyle(
                    fontSize: 11,
                    color: escuro
                        ? AppColors.fonteSubtituloClaro
                        : AppColors.fontePlaceholder,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//  Plano semanal (tela 4.5.13)
// =====================================================================

class PlanoSemanalScreen extends StatefulWidget {
  const PlanoSemanalScreen({
    super.key,
    required this.cardapioService,
    this.aoVoltar,
  });

  final CardapioService cardapioService;
  final VoidCallback? aoVoltar;

  @override
  State<PlanoSemanalScreen> createState() => _PlanoSemanalScreenState();
}

class _PlanoSemanalScreenState extends State<PlanoSemanalScreen> {
  PlanoSemanal? _plano;
  bool _carregando = true;
  String? _erro;
  String _diaSelecionado = 'segunda';

  static const _ordemDias = [
    'segunda',
    'terca',
    'quarta',
    'quinta',
    'sexta',
    'sabado',
    'domingo',
  ];

  static const _rotulos = {
    'segunda': 'Seg',
    'terca': 'Ter',
    'quarta': 'Qua',
    'quinta': 'Qui',
    'sexta': 'Sex',
    'sabado': 'Sab',
    'domingo': 'Dom',
  };

  @override
  void initState() {
    super.initState();
    const mapa = ['', 'segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo'];
    _diaSelecionado = mapa[DateTime.now().weekday];
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final plano = await widget.cardapioService.carregarSemanal();
      if (!mounted) return;
      setState(() {
        _plano = plano;
        _carregando = false;
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = 'Formato inesperado na resposta da API: $erro';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final dia = _plano?.dias
        .where((d) => d.dia == _diaSelecionado)
        .firstOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: _plano?.nomePlano ?? 'Plano semanal',
            subtitulo: _plano != null
                ? '${_plano!.preenchidas} de ${_plano!.total} refeições montadas'
                : null,
            icone: Icons.calendar_view_week_rounded,
            gradiente: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.paletaRoxo, Color(0xFF6B21A8)],
            ),
            aoVoltar: widget.aoVoltar ?? () => Navigator.of(context).maybePop(),
          ),
          SizedBox(
            height: 54,
            child: Row(
              children: _ordemDias
                  .map(
                    (d) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 8),
                        child: Material(
                          color: d == _diaSelecionado
                              ? AppColors.paletaVerde
                              : (escuro
                                  ? const Color(0xFF21262D)
                                  : AppColors.cinzaSegmento),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _diaSelecionado = d),
                            child: Center(
                              child: Text(
                                _rotulos[d]!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: d == _diaSelecionado
                                      ? Colors.white
                                      : (escuro
                                          ? AppColors.fonteSubtituloClaro
                                          : AppColors.fonteSubtitulo),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: _carregando
                ? const CarregandoView()
                : _erro != null
                    ? ErroView(mensagem: _erro!, aoTentar: _carregar)
                    : ListView(
                        padding: const EdgeInsets.all(AppSizes.telaPadding),
                        children: [
                          if (dia == null || dia.refeicoes.isEmpty)
                            MvnCard(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 26, horizontal: 16),
                              child: Text(
                                'Nenhuma refeição planejada para este dia.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: escuro
                                      ? AppColors.fonteSubtituloClaro
                                      : AppColors.fonteSubtitulo,
                                ),
                              ),
                            )
                          else
                            for (final refeicao in dia.refeicoes) ...[
                              _CartaoRefeicaoExpandida(refeicao: refeicao),
                              const SizedBox(height: AppSizes.espacoEntreCards),
                            ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _CartaoRefeicaoExpandida extends StatelessWidget {
  const _CartaoRefeicaoExpandida({required this.refeicao});

  final Refeicao refeicao;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return MvnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  refeicao.rotuloTipo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: escuro
                        ? AppColors.paletaLilasSuave
                        : AppColors.paletaRoxo,
                  ),
                ),
              ),
              if (refeicao.horario != null)
                Text(
                  refeicao.horario!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: escuro
                        ? AppColors.fonteSubtituloClaro
                        : AppColors.fontePlaceholder,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            refeicao.nomeReceita.isEmpty ? 'A definir' : refeicao.nomeReceita,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${refeicao.calorias.round()} kcal • '
            'P ${refeicao.proteinas.round()}g • '
            'C ${refeicao.carboidratos.round()}g • '
            'G ${refeicao.gorduras.round()}g',
            style: TextStyle(
              fontSize: 11.5,
              color: escuro
                  ? AppColors.fonteSubtituloClaro
                  : AppColors.fontePlaceholder,
            ),
          ),
          if (refeicao.ingredientes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ingredientes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
              ),
            ),
            const SizedBox(height: 4),
            for (final ing in refeicao.ingredientes)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• ${ing.nome} - ${ing.quantidadeG.round()}${ing.unidade}',
                  style: TextStyle(
                    fontSize: 12,
                    color: escuro
                        ? AppColors.fonteSubtituloClaro
                        : AppColors.fonteSubtitulo,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
//  Lista de compras (tela 4.5.18) com inclusão de itens manuais
// =====================================================================

class ListaComprasScreen extends StatefulWidget {
  const ListaComprasScreen({
    super.key,
    required this.cardapioService,
    this.aoVoltar,
  });

  final CardapioService cardapioService;
  final VoidCallback? aoVoltar;

  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {
  List<ItemCompra> _itens = [];
  final Set<String> _comprados = {};
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final itens = await widget.cardapioService.carregarListaCompras();
      if (!mounted) return;
      setState(() {
        _itens = itens;
        _comprados.clear();
        for (final item in itens) {
          if (item.comprado) {
            _comprados.add(item.nome);
          }
        }
        _carregando = false;
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = 'Formato inesperado na resposta da API: $erro';
        _carregando = false;
      });
    }
  }

  Future<void> _alternarItem(ItemCompra item) async {
    final novoStatus = !_comprados.contains(item.nome);
    setState(() {
      if (novoStatus) {
        _comprados.add(item.nome);
      } else {
        _comprados.remove(item.nome);
      }
    });

    try {
      await widget.cardapioService.alternarItemListaCompras(
        item.id ?? item.nome,
        novoStatus,
      );
    } catch (_) {
      // Reverter se der erro
    }
  }

  Future<void> _removerItem(ItemCompra item) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Item'),
        content: Text('Deseja remover "${item.nome}" da lista de compras?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover', style: TextStyle(color: AppColors.vermelho)),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await widget.cardapioService.removerItemListaCompras(item.id ?? item.nome);
      await _carregar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _adicionarItemDialog() async {
    final nomeController = TextEditingController();
    final qtdController = TextEditingController(text: '100');
    String categoria = 'Hortifrúti';

    final categoriasDisponiveis = [
      'Hortifrúti',
      'Mercearia',
      'Carnes e Peixes',
      'Laticínios e Ovos',
      'Bebidas',
      'Outros',
    ];

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_shopping_cart_rounded, color: AppColors.paletaVerde),
              SizedBox(width: 8),
              Text('Adicionar Item', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Item *',
                  hintText: 'Ex: Maçã Gala, Azeite...',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtdController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantidade aproximada (g ou ml)',
                  hintText: 'Ex: 250',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Categoria:', style: TextStyle(fontSize: 12, color: AppColors.textoSuave)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: categoria,
                decoration: const InputDecoration(isDense: true),
                items: categoriasDisponiveis
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => categoria = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.paletaVerde,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (nomeController.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true) {
      nomeController.dispose();
      qtdController.dispose();
      return;
    }

    final nome = nomeController.text.trim();
    final qtd = double.tryParse(qtdController.text.replaceAll(',', '.').trim()) ?? 100.0;
    nomeController.dispose();
    qtdController.dispose();

    try {
      await widget.cardapioService.adicionarItemListaCompras(
        nome: nome,
        quantidade: qtd,
        categoria: categoria,
      );
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item "$nome" adicionado à lista de compras!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final categorias = <String, List<ItemCompra>>{};
    for (final item in _itens) {
      categorias.putIfAbsent(item.categoria, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.paletaVerde,
        onPressed: _adicionarItemDialog,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text(
          'Adicionar Item',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Lista de compras',
            subtitulo: 'Gerada do plano alimentar + seus itens personalizados',
            icone: Icons.shopping_cart_outlined,
            gradiente: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.paletaRoxo, Color(0xFF6B21A8)],
            ),
            aoVoltar: widget.aoVoltar ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: _carregando
                ? const CarregandoView()
                : _erro != null
                    ? ErroView(mensagem: _erro!, aoTentar: _carregar)
                    : _itens.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Sua lista de compras está vazia.\nUse o botão abaixo para adicionar novos itens.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: escuro
                                      ? AppColors.fonteSubtituloClaro
                                      : AppColors.fonteSubtitulo,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              AppSizes.telaPadding,
                              AppSizes.telaPadding,
                              AppSizes.telaPadding,
                              80,
                            ),
                            children: [
                              for (final categoria in categorias.keys) ...[
                                Text(
                                  categoria,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: escuro
                                        ? AppColors.paletaLilasSuave
                                        : AppColors.paletaRoxo,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final item in categorias[categoria]!)
                                  _ItemCompra(
                                    item: item,
                                    comprado: _comprados.contains(item.nome),
                                    aoAlternar: () => _alternarItem(item),
                                    aoExcluir: item.manual ? () => _removerItem(item) : null,
                                  ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _ItemCompra extends StatelessWidget {
  const _ItemCompra({
    required this.item,
    required this.comprado,
    required this.aoAlternar,
    this.aoExcluir,
  });

  final ItemCompra item;
  final bool comprado;
  final VoidCallback aoAlternar;
  final VoidCallback? aoExcluir;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: escuro ? AppColors.paletaEscuroCard : AppColors.branco,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: escuro ? AppColors.bordaEscura : AppColors.bordaClara.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: aoAlternar,
            child: Icon(
              comprado
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: comprado
                  ? AppColors.paletaVerde
                  : (escuro
                      ? AppColors.fonteSubtituloClaro
                      : AppColors.fontePlaceholder),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nome,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
                    decoration: comprado ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.manual)
                  const Text(
                    'Item personalizado',
                    style: TextStyle(fontSize: 10.5, color: AppColors.paletaRoxo, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          Text(
            item.quantidadeG >= 1000
                ? '${(item.quantidadeG / 1000).toStringAsFixed(1)} kg'
                : '${item.quantidadeG.round()} g',
            style: TextStyle(
              fontSize: 12.5,
              color: escuro
                  ? AppColors.fonteSubtituloClaro
                  : AppColors.fonteSubtitulo,
            ),
          ),
          if (aoExcluir != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.vermelho),
              onPressed: aoExcluir,
              tooltip: 'Remover item',
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
//  Minhas Receitas do paciente
// =====================================================================

class MinhasReceitasScreen extends StatefulWidget {
  const MinhasReceitasScreen({
    super.key,
    required this.cardapioService,
    this.aoVoltar,
  });

  final CardapioService cardapioService;
  final VoidCallback? aoVoltar;

  @override
  State<MinhasReceitasScreen> createState() => _MinhasReceitasScreenState();
}

class _MinhasReceitasScreenState extends State<MinhasReceitasScreen> {
  List<Receita> _receitas = [];
  List<Alimento> _alimentos = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final receitas = await widget.cardapioService.minhasReceitas();
      List<Alimento> alimentos;
      try {
        alimentos = await widget.cardapioService.listarAlimentos();
      } on ApiException {
        alimentos = const [];
      }
      if (!mounted) return;
      setState(() {
        _receitas = receitas;
        _alimentos = alimentos;
        _carregando = false;
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = 'Formato inesperado na resposta da API: $erro';
        _carregando = false;
      });
    }
  }

  Future<void> _compartilhar() async {
    if (_alimentos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Base de alimentos indisponível agora. '
              'Tente novamente em instantes.'),
        ),
      );
      return;
    }
    final enviou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompartilharReceitaScreen(
          cardapioService: widget.cardapioService,
          alimentos: _alimentos,
        ),
      ),
    );
    if (enviou == true) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _carregando || _erro != null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.paletaVerde,
              onPressed: _compartilhar,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Compartilhar receita',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Minhas receitas',
            subtitulo: 'Receitas que você compartilhou',
            icone: Icons.menu_book_rounded,
            gradiente: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.paletaRoxo, Color(0xFF6B21A8)],
            ),
            aoVoltar: widget.aoVoltar ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: _carregando
                ? const CarregandoView()
                : _erro != null
                    ? ErroView(mensagem: _erro!, aoTentar: _carregar)
                    : _receitas.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Você ainda não compartilhou receitas.\n'
                                'Toque em "Compartilhar receita" para enviar '
                                'uma sugestão ao seu nutricionista.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: escuro
                                      ? AppColors.fonteSubtituloClaro
                                      : AppColors.fonteSubtitulo,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.paletaVerde,
                            onRefresh: _carregar,
                            child: ListView(
                              padding:
                                  const EdgeInsets.all(AppSizes.telaPadding),
                              children: [
                                for (final receita in _receitas)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: MvnCard(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  receita.nome,
                                                  style: TextStyle(
                                                    fontSize: 14.5,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: escuro
                                                        ? AppColors.paletaClaro
                                                        : AppColors.fonteTitulo,
                                                  ),
                                                ),
                                              ),
                                              _SeloStatus(
                                                  status: receita.status),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${receita.calorias.round()} kcal • '
                                            'P ${receita.proteinas.round()}g • '
                                            'C ${receita.carboidratos.round()}g • '
                                            'G ${receita.gorduras.round()}g',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: escuro
                                                  ? AppColors.fonteSubtituloClaro
                                                  : AppColors.fontePlaceholder,
                                            ),
                                          ),
                                          if (receita.status == 'recusada' &&
                                              receita.justificativa !=
                                                  null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Justificativa: ${receita.justificativa}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.vermelho,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//  Compartilhar uma receita com o nutricionista (tela 4.5.25)
// =====================================================================

class CompartilharReceitaScreen extends StatefulWidget {
  const CompartilharReceitaScreen({
    super.key,
    required this.cardapioService,
    required this.alimentos,
  });

  final CardapioService cardapioService;
  final List<Alimento> alimentos;

  @override
  State<CompartilharReceitaScreen> createState() =>
      _CompartilharReceitaScreenState();
}

class _CompartilharReceitaScreenState
    extends State<CompartilharReceitaScreen> {
  final _nomeController = TextEditingController();
  final _modoController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _buscaController = TextEditingController();

  final List<Ingrediente> _ingredientes = [];
  Alimento? _selecionado;
  bool _enviando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _modoController.dispose();
    _quantidadeController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  List<Alimento> get _filtrados {
    final busca = _buscaController.text.trim().toLowerCase();
    if (busca.isEmpty) return widget.alimentos;
    return widget.alimentos
        .where((a) => a.nome.toLowerCase().contains(busca))
        .toList();
  }

  double get _caloriasTotais =>
      _ingredientes.fold(0, (soma, i) => soma + i.caloriasNaPorcao);

  void _adicionar() {
    final alimento = _selecionado;
    final quantidade =
        double.tryParse(_quantidadeController.text.replaceAll(',', '.').trim());
    if (alimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha um alimento da lista.')),
      );
      return;
    }
    if (quantidade == null || quantidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a quantidade em gramas.')),
      );
      return;
    }
    setState(() {
      _ingredientes.add(Ingrediente.doAlimento(alimento, quantidade));
      _selecionado = null;
      _quantidadeController.clear();
      _buscaController.clear();
    });
  }

  Future<void> _enviar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty || _ingredientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o nome e pelo menos um ingrediente.'),
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await widget.cardapioService.compartilharReceita(
        nome: nome,
        modoPreparo: _modoController.text.trim(),
        ingredientes: _ingredientes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receita enviada para aprovação do nutricionista!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(erro.mensagem),
            backgroundColor: AppColors.vermelho),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Compartilhar receita',
            subtitulo: 'Envie uma sugestão para aprovação',
            icone: Icons.menu_book_rounded,
            gradiente: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.paletaRoxo, Color(0xFF6B21A8)],
            ),
            aoVoltar: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.telaPadding),
              children: [
                MvnCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloCard(texto: 'Receita', emoji: '🍽️'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da receita',
                          hintText: 'Ex.: Panqueca de aveia',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _modoController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Modo de preparo (opcional)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),
                MvnCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloCard(texto: 'Ingredientes', emoji: '🥗'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _buscaController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Buscar alimento',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 132,
                        child: _filtrados.isEmpty
                            ? Center(
                                child: Text(
                                  'Nenhum alimento encontrado.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: escuro
                                        ? AppColors.fonteSubtituloClaro
                                        : AppColors.fonteSubtitulo,
                                  ),
                                ),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: ListView.builder(
                                  itemCount: _filtrados.length,
                                  itemBuilder: (_, i) {
                                    final alimento = _filtrados[i];
                                    final marcado = _selecionado?.idAlimento ==
                                        alimento.idAlimento;
                                    return ListTile(
                                      dense: true,
                                      selected: marcado,
                                      selectedTileColor: escuro
                                          ? const Color(0xFF21262D)
                                          : AppColors.paletaVerdeSuave,
                                      title: Text(
                                        alimento.nome,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: escuro
                                              ? AppColors.paletaClaro
                                              : AppColors.fonteTitulo,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${alimento.calorias.round()} kcal /100g',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: escuro
                                              ? AppColors.fonteSubtituloClaro
                                              : AppColors.fontePlaceholder,
                                        ),
                                      ),
                                      trailing: marcado
                                          ? const Icon(Icons.check_rounded,
                                              color: AppColors.paletaVerde, size: 18)
                                          : null,
                                      onTap: () => setState(
                                          () => _selecionado = alimento),
                                    );
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quantidadeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Quantidade (g)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: _adicionar,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Adicionar'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.paletaVerde,
                            ),
                          ),
                        ],
                      ),
                      if (_ingredientes.isNotEmpty) ...[
                        const Divider(height: 22),
                        for (var i = 0; i < _ingredientes.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_ingredientes[i].nome} — '
                                    '${_ingredientes[i].quantidadeG.round()}g '
                                    '(${_ingredientes[i].caloriasNaPorcao.round()} kcal)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: escuro
                                          ? AppColors.paletaClaro
                                          : AppColors.fonteTitulo,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      setState(() => _ingredientes.removeAt(i)),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 16, color: AppColors.vermelho),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'Total estimado: ${_caloriasTotais.round()} kcal',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: escuro
                                ? AppColors.paletaLilasSuave
                                : AppColors.paletaRoxo,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),
                BotaoGradiente(
                  texto: _enviando ? 'ENVIANDO...' : 'ENVIAR PARA APROVACAO',
                  icone: Icons.send_rounded,
                  gradiente: AppColors.gradienteAuth,
                  aoTocar: _enviando ? null : _enviar,
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeloStatus extends StatelessWidget {
  const _SeloStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (cor, rotulo) = switch (status) {
      'aprovada' => (AppColors.paletaVerde, 'Aprovada'),
      'pendente' => (AppColors.laranja, 'Pendente'),
      _ => (AppColors.vermelho, 'Recusada'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        rotulo,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cor,
        ),
      ),
    );
  }
}
