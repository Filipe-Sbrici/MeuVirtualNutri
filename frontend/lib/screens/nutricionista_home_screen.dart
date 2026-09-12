/// Painel do Nutricionista (telas 4.5.20 a 4.5.28 do prototipo).
///
/// Home com atalhos (Agenda, Novo paciente, Receitas, Relatorios),
/// lista de pacientes com resumo clinico, perfil clinico do paciente,
/// editor de cardapio (wizard 3 passos), biblioteca de receitas,
/// receitas compartilhadas, agenda e relatorios de analise.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/cardapio.dart';
import '../models/usuario.dart';
import '../services/chat_service.dart';
import '../services/api_services.dart';
import '../services/mvn_services.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'configuracoes_screen.dart';
import 'evolucao_screen.dart';

class NutricionistaHomeScreen extends StatefulWidget {
  const NutricionistaHomeScreen({
    super.key,
    required this.usuario,
    required this.nutricionistaService,
    required this.chatService,
    required this.evolucaoService,
    required this.aoFazerLogout,
  });

  final Usuario usuario;
  final NutricionistaService nutricionistaService;
  final ChatService chatService;
  final EvolucaoService evolucaoService;
  final VoidCallback aoFazerLogout;

  @override
  State<NutricionistaHomeScreen> createState() =>
      _NutricionistaHomeScreenState();
}

class _NutricionistaHomeScreenState extends State<NutricionistaHomeScreen> {
  int _indice = 0; // 0=Home, 1=Pacientes, 2=Receitas, 3=Agenda, 4=Config
  late Usuario _usuarioAtual = widget.usuario;

  /// Incrementado a cada vinculo novo, para recarregar PacientesTab.
  int _versaoPacientes = 0;

  // Dados da Home
  List<Consulta> _consultasHoje = [];
  List<Consulta> _pedidosPendentes = [];
  int _receitasPendentes = 0;
  int _totalPacientes = 0;
  bool _carregandoHome = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosHome();
  }

  Future<void> _carregarDadosHome() async {
    try {
      final consultas = await widget.nutricionistaService.listarConsultas();
      final receitas =
          await widget.nutricionistaService.listarReceitasPendentes();
      final pacientes = await widget.nutricionistaService.listarPacientes();

      if (!mounted) return;
      final agora = DateTime.now();
      final hoje = consultas.where((c) {
        return c.dataHora.year == agora.year &&
            c.dataHora.month == agora.month &&
            c.dataHora.day == agora.day &&
            (c.status == 'confirmada' || c.status == 'pendente');
      }).toList();

      final pendentes = consultas.where((c) => c.status == 'pendente').toList();

      setState(() {
        _consultasHoje = hoje;
        _pedidosPendentes = pendentes;
        _receitasPendentes = receitas.length;
        _totalPacientes = pacientes.length;
        _carregandoHome = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carregandoHome = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: _indice == 4
          ? null
          : AppBar(
              backgroundColor:
                  escuro ? AppColors.paletaEscuroCard : AppColors.paletaRoxo,
              elevation: 0,
              title: const Text(
                'Virtual Nutri - Profissional',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Atualizar',
                  onPressed: () {
                    _carregarDadosHome();
                    setState(() => _versaoPacientes++);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Sair da conta',
                  onPressed: () => _confirmarLogout(),
                ),
              ],
            ),
      body: switch (_indice) {
        0 => _abaHome(),
        1 => PacientesTab(
            key: ValueKey('pacientes-$_versaoPacientes'),
            uidLogado: _usuarioAtual.uid,
            nutricionistaService: widget.nutricionistaService,
            chatService: widget.chatService,
            evolucaoService: widget.evolucaoService,
          ),
        2 => ReceitasTab(nutricionistaService: widget.nutricionistaService),
        3 => AgendaTab(nutricionistaService: widget.nutricionistaService),
        4 => ConfiguracoesScreen(
            usuario: _usuarioAtual,
            authService: AuthService(widget.nutricionistaService.api),
            onboardingService:
                OnboardingService(widget.nutricionistaService.api),
            aoAtualizarUsuario: (u) => setState(() => _usuarioAtual = u),
            aoFazerLogout: widget.aoFazerLogout,
          ),
        _ => _abaHome(),
      },
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indice,
        onTap: (i) {
          setState(() => _indice = i);
          if (i == 0) _carregarDadosHome();
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: escuro ? AppColors.paletaEscuroCard : Colors.white,
        selectedItemColor: AppColors.verde,
        unselectedItemColor: AppColors.textoFraco,
        selectedFontSize: 11.5,
        unselectedFontSize: 11.5,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Inicio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded), label: 'Pacientes'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined), label: 'Receitas'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined), label: 'Agenda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Config'),
        ],
      ),
      floatingActionButton: _indice == 1
          ? FloatingActionButton(
              backgroundColor: AppColors.verde,
              child: const Icon(Icons.person_add_alt_1, color: Colors.white),
              onPressed: () => _vincularPacienteDialog(),
            )
          : null,
    );
  }

  void _confirmarLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar Sessao'),
        content: const Text('Deseja realmente sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.aoFazerLogout();
            },
            child:
                const Text('Sair', style: TextStyle(color: AppColors.vermelho)),
          ),
        ],
      ),
    );
  }

  // ---------------- Home ----------------

  Widget _abaHome() {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: AppColors.verde,
      onRefresh: _carregarDadosHome,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.telaPadding),
        children: [
          // Perfil do profissional
          MvnCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: escuro
                      ? const Color(0xFF21262D)
                      : AppColors.paletaLilasSuave,
                  child: Icon(Icons.medical_services,
                      color: escuro
                          ? AppColors.paletaLilasSuave
                          : AppColors.paletaRoxo,
                      size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bem-vindo(a), ${widget.usuario.nome.split(' ').first}!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: escuro ? AppColors.paletaClaro : AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.usuario.crn != null)
                        Text(
                          'CRN: ${widget.usuario.crn}'
                          '${widget.usuario.especializacao != null ? ' • ${widget.usuario.especializacao}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: escuro
                                ? AppColors.fonteSubtituloClaro
                                : AppColors.textoSuave,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.espacoEntreCards),

          // -----------------------------------------------------------------
          // 1. Consultas de Hoje
          // -----------------------------------------------------------------
          MvnCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.paletaVerde.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.paletaVerde),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Consultas de Hoje',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => setState(() => _indice = 3),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.verde,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Ver agenda'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_carregandoHome)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(color: AppColors.verde),
                    ),
                  )
                else if (_consultasHoje.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: escuro
                          ? const Color(0xFF21262D)
                          : AppColors.cinzaSegmento,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded,
                            color: AppColors.paletaVerde, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Nenhuma consulta agendada para hoje.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textoSuave,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._consultasHoje.map((c) {
                    final pendente = c.status == 'pendente';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: escuro
                            ? const Color(0xFF21262D)
                            : (pendente
                                ? const Color(0xFFFFFBEB)
                                : AppColors.paletaVerdeSuave.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: pendente
                              ? const Color(0xFFFDE68A)
                              : AppColors.paletaVerde.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.paletaRoxo,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.horaFormatada,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.nomePaciente ?? 'Paciente MVN',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  pendente
                                      ? '⏳ Pedido de agendamento pendente'
                                      : '✅ Consulta confirmada',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: pendente
                                        ? const Color(0xFFB45309)
                                        : AppColors.verdeEscuro,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14),
                            color: AppColors.textoSuave,
                            onPressed: () => setState(() => _indice = 3),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.espacoEntreCards),

          // -----------------------------------------------------------------
          // 2. Notificações Recentes e Pendências
          // -----------------------------------------------------------------
          MvnCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        size: 20, color: AppColors.paletaRoxo),
                    SizedBox(width: 8),
                    Text(
                      'Notificações Recentes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_pedidosPendentes.isNotEmpty)
                  ..._pedidosPendentes.map((pedido) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pending_actions_rounded,
                                  size: 18, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Solicitação de Agendamento: ${pedido.nomePaciente ?? "Paciente"}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pedido.descricaoCompleta,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78350F),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await widget.nutricionistaService
                                      .recusarConsulta(pedido.idConsulta);
                                  _carregarDadosHome();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.vermelho,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                ),
                                child: const Text('Recusar'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  await widget.nutricionistaService
                                      .aprovarConsulta(pedido.idConsulta);
                                  _carregarDadosHome();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.verde,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Confirmar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                if (_receitasPendentes > 0)
                  InkWell(
                    onTap: () => setState(() => _indice = 2),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: escuro
                            ? const Color(0xFF21262D)
                            : AppColors.paletaLilasSuave.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.restaurant_menu_rounded,
                              size: 20, color: AppColors.paletaRoxo),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_receitasPendentes receita(s) compartilhada(s) aguardando avaliação',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: AppColors.textoSuave),
                        ],
                      ),
                    ),
                  ),
                if (_pedidosPendentes.isEmpty && _receitasPendentes == 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: escuro
                          ? const Color(0xFF21262D)
                          : AppColors.cinzaSegmento,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.verde, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Tudo em dia! Nenhuma pendência no momento.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.espacoEntreCards),

          // -----------------------------------------------------------------
          // 3. Resumo de Pacientes Ativos
          // -----------------------------------------------------------------
          MvnCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paletaVerde.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_alt_rounded,
                      color: AppColors.paletaVerde, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_totalPacientes Pacientes Ativos',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Gerencie planos alimentares e evolução',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _vincularPacienteDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Vincular'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.paletaRoxo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _vincularPacienteDialog() async {
    final controlador = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar paciente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe o e-mail da conta do paciente ja criada no app '
              'para vincula-lo a voce.',
              style: TextStyle(fontSize: 13, color: AppColors.textoSuave),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controlador,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail do paciente',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Vincular',
                style: TextStyle(
                    color: AppColors.verde, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmado != true) return;
    final email = controlador.text.trim();
    controlador.dispose();

    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o e-mail do paciente.')),
      );
      return;
    }

    try {
      await widget.nutricionistaService.vincularPaciente(email);
      if (!mounted) return;
      // Recria a aba de pacientes para a lista refletir o novo vinculo.
      setState(() => _versaoPacientes++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paciente vinculado com sucesso!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }
}

// =====================================================================
//  Aba Pacientes + perfil clinico (4.5.22)
// =====================================================================

class PacientesTab extends StatefulWidget {
  const PacientesTab({
    super.key,
    required this.uidLogado,
    required this.nutricionistaService,
    required this.chatService,
    required this.evolucaoService,
  });

  final String uidLogado;
  final NutricionistaService nutricionistaService;
  final ChatService chatService;
  final EvolucaoService evolucaoService;

  @override
  State<PacientesTab> createState() => _PacientesTabState();
}

class _PacientesTabState extends State<PacientesTab>
    with AutomaticKeepAliveClientMixin {
  List<PacienteResumo> _pacientes = [];
  List<PacienteResumo> _solicitacoes = [];
  int _subAba = 0; // 0 = Meus Pacientes, 1 = Solicitacoes
  bool _carregando = true;
  String? _erro;

  @override
  bool get wantKeepAlive => true;

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
      final pacientes = await widget.nutricionistaService.listarPacientes();
      List<PacienteResumo> solicitacoes = [];
      try {
        solicitacoes = await widget.nutricionistaService.listarSolicitacoes();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _pacientes = pacientes;
        _solicitacoes = solicitacoes;
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

  Future<void> _aceitarSolicitacao(PacienteResumo paciente) async {
    try {
      await widget.nutricionistaService.aceitarSolicitacao(paciente.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Atendimento de ${paciente.nome} aceito com sucesso!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
      await _carregar();
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  Future<void> _recusarSolicitacao(PacienteResumo paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recusar Solicitação'),
        content: Text(
          'Deseja recusar o pedido de atendimento de ${paciente.nome}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Recusar',
              style: TextStyle(
                  color: AppColors.vermelho, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await widget.nutricionistaService.recusarSolicitacao(paciente.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação de atendimento recusada.')),
      );
      await _carregar();
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    if (_carregando) return const CarregandoView();
    if (_erro != null) return ErroView(mensagem: _erro!, aoTentar: _carregar);

    return RefreshIndicator(
      color: AppColors.verde,
      onRefresh: _carregar,
      child: Column(
        children: [
          // Seletor superior de sub-abas
          Container(
            color: escuro ? AppColors.paletaEscuroCard : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _subAba = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _subAba == 0
                            ? AppColors.paletaVerde
                            : (escuro
                                ? const Color(0xFF21262D)
                                : AppColors.cinzaSegmento),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Meus Pacientes (${_pacientes.length})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              _subAba == 0 ? FontWeight.bold : FontWeight.w500,
                          color: _subAba == 0
                              ? Colors.white
                              : (escuro
                                  ? AppColors.paletaClaro
                                  : AppColors.fonteTitulo),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _subAba = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _subAba == 1
                            ? AppColors.paletaVerde
                            : (escuro
                                ? const Color(0xFF21262D)
                                : AppColors.cinzaSegmento),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Solicitações',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _subAba == 1
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _subAba == 1
                                  ? Colors.white
                                  : (escuro
                                      ? AppColors.paletaClaro
                                      : AppColors.fonteTitulo),
                            ),
                          ),
                          if (_solicitacoes.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _subAba == 1
                                    ? AppColors.paletaRoxo
                                    : AppColors.vermelho,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_solicitacoes.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Conteudo da sub-aba
          Expanded(
            child:
                _subAba == 0 ? _conteudoPacientes() : _conteudoSolicitacoes(),
          ),
        ],
      ),
    );
  }

  Widget _conteudoPacientes() {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    if (_pacientes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded,
                size: 44, color: AppColors.textoFraco),
            SizedBox(height: 10),
            Text(
              'Nenhum paciente vinculado ainda.\nUse o botão + para adicionar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      itemCount: _pacientes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final paciente = _pacientes[i];
        return MvnCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: escuro
                        ? const Color(0xFF21262D)
                        : AppColors.paletaVerdeSuave,
                    child: Text(
                      paciente.nome.isNotEmpty
                          ? paciente.nome[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: escuro
                            ? AppColors.paletaLilasSuave
                            : AppColors.paletaRoxo,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paciente.nome,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: escuro
                                ? AppColors.paletaClaro
                                : AppColors.texto,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${paciente.objetivo ?? 'Sem objetivo'}'
                          '${paciente.pesoAtual != null ? ' • ${paciente.pesoAtual!.toStringAsFixed(1)} kg' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: escuro
                                ? AppColors.fonteSubtituloClaro
                                : AppColors.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (paciente.restricoes.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.vermelho.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⚠ ${paciente.restricoes.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.vermelho,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _abrirPerfilClinico(paciente),
                      icon: const Icon(Icons.folder_shared_outlined, size: 17),
                      label: const Text('Perfil clínico'),
                      style: TextButton.styleFrom(
                          foregroundColor: escuro
                              ? AppColors.paletaVerde
                              : AppColors.paletaRoxo),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _abrirChat(paciente),
                      icon: const Icon(Icons.chat_bubble_outline, size: 17),
                      label: const Text('Chat'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.verde),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _conteudoSolicitacoes() {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    if (_solicitacoes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: AppColors.textoFraco),
            SizedBox(height: 10),
            Text(
              'Nenhuma solicitação de atendimento pendente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      itemCount: _solicitacoes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = _solicitacoes[i];
        return MvnCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: escuro
                        ? const Color(0xFF21262D)
                        : AppColors.paletaLilasSuave,
                    child: Text(
                      p.nome.isNotEmpty ? p.nome[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: escuro
                            ? AppColors.paletaLilasSuave
                            : AppColors.paletaRoxo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nome,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: escuro
                          ? const Color(0xFF21262D)
                          : AppColors.paletaLilasSuave,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Pendente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: escuro
                            ? AppColors.paletaLilasSuave
                            : AppColors.paletaRoxo,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (p.objetivo != null && p.objetivo!.isNotEmpty) ...[
                Text(
                  'Objetivo: ${p.objetivo}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
              ],
              if (p.restricoes.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: p.restricoes.map((r) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.vermelho.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.vermelho.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '⚠ $r',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.vermelho,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Botoes Aceitar e Recusar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _recusarSolicitacao(p),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Recusar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.vermelho,
                        side: BorderSide(
                            color: AppColors.vermelho.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _aceitarSolicitacao(p),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Aceitar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.paletaVerde,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirPerfilClinico(PacienteResumo paciente) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilClinicoScreen(
          uidLogado: widget.uidLogado,
          paciente: paciente,
          nutricionistaService: widget.nutricionistaService,
          evolucaoService: widget.evolucaoService,
          chatService: widget.chatService,
        ),
      ),
    );
  }

  void _abrirChat(PacienteResumo paciente) async {
    try {
      final contato = await widget.chatService
          .carregarContatoPadrao(uidPaciente: paciente.uid);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatService: widget.chatService,
            idUsuario: widget.uidLogado,
            idContato: contato.idUsuario,
            nomeContato: contato.nome,
            papelContato: contato.papel,
          ),
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.mensagem)));
    }
  }
}

/// Perfil clinico do paciente (4.5.22): dados, evolucao, orientacoes,
/// atalhos para chat e editor de cardapio.
class PerfilClinicoScreen extends StatefulWidget {
  const PerfilClinicoScreen({
    super.key,
    required this.uidLogado,
    required this.paciente,
    required this.nutricionistaService,
    required this.evolucaoService,
    required this.chatService,
  });

  final String uidLogado;
  final PacienteResumo paciente;
  final NutricionistaService nutricionistaService;
  final EvolucaoService evolucaoService;
  final ChatService chatService;

  @override
  State<PerfilClinicoScreen> createState() => _PerfilClinicoScreenState();
}

class _PerfilClinicoScreenState extends State<PerfilClinicoScreen> {
  @override
  Widget build(BuildContext context) {
    final p = widget.paciente;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: p.nome,
            subtitulo: p.email,
            icone: Icons.folder_shared_outlined,
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
                      const TituloCard(texto: 'Dados clínicos', emoji: '📋'),
                      const SizedBox(height: 12),
                      _linha('Idade', p.idade != null ? '${p.idade} anos' : null),
                      _linha('Peso atual', p.pesoAtual != null ? '${p.pesoAtual!.toStringAsFixed(1)} kg' : null),
                      _linha('Peso-meta', p.pesoMeta != null ? '${p.pesoMeta!.toStringAsFixed(1)} kg' : null),
                      _linha('Altura', p.altura != null ? '${p.altura!.toStringAsFixed(2)} m' : null),
                      if (p.pesoAtual != null && p.altura != null && p.altura! > 0)
                        _linha('IMC estimado', '${(p.pesoAtual! / (p.altura! * p.altura!)).toStringAsFixed(1)} kg/m²'),
                      _linha('Objetivo', p.objetivo),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),

                // 🛡️ Segurança Alimentar (Alergias, Condições e Alertas)
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
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Segurança Alimentar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.vermelho,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (p.restricoes.isNotEmpty)
                        _linha('Alergias / Restrições', p.restricoes.join(', ')),
                      if (p.condicoesMedicas.isNotEmpty)
                        _linha('Condições Médicas', p.condicoesMedicas.join(', ')),
                      if (p.observacoesSeguranca.isNotEmpty)
                        _linha('Observações de Segurança', p.observacoesSeguranca),
                      if (p.restricoes.isEmpty &&
                          p.condicoesMedicas.isEmpty &&
                          p.observacoesSeguranca.isEmpty)
                        const Text(
                          'Nenhuma restrição alimentar ou condição clínica informada pelo paciente.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textoSuave,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),

                // 🍽️ Preferências Alimentares (Gostos e Hábitos)
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
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Preferências Alimentares',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _linha('Tipo de Dieta', p.tipoDieta ?? 'Não informado'),
                      if (p.alimentosFavoritos.isNotEmpty)
                        _linha('Alimentos Favoritos', p.alimentosFavoritos.join(', ')),
                      if (p.alimentosRejeitados.isNotEmpty)
                        _linha('Alimentos Evitados', p.alimentosRejeitados.join(', ')),
                      if (p.alimentosFavoritos.isEmpty && p.alimentosRejeitados.isEmpty)
                        const Text(
                          'Nenhuma preferência específica cadastrada.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textoSuave,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),

                // Card de Compartilhamento / Privacidade do Paciente
                MvnCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloCard(texto: 'Privacidade & Compartilhamento', emoji: '🔒'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            p.compartilharListaCompras
                                ? Icons.check_circle_rounded
                                : Icons.lock_outline_rounded,
                            size: 18,
                            color: p.compartilharListaCompras
                                ? AppColors.verde
                                : AppColors.textoFraco,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.compartilharListaCompras
                                  ? 'Lista de compras compartilhada com você'
                                  : 'Lista de compras privada (não compartilhada)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: p.compartilharListaCompras
                                    ? AppColors.verdeEscuro
                                    : AppColors.textoSuave,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            p.compartilharHumor
                                ? Icons.check_circle_rounded
                                : Icons.lock_outline_rounded,
                            size: 18,
                            color: p.compartilharHumor
                                ? AppColors.verde
                                : AppColors.textoFraco,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.compartilharHumor
                                  ? 'Humor e bem-estar compartilhados'
                                  : 'Humor e bem-estar privados (não compartilhados)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: p.compartilharHumor
                                    ? AppColors.verdeEscuro
                                    : AppColors.textoSuave,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),

                Row(
                  children: [
                    Expanded(
                      child: BotaoGradiente(
                        texto: 'EVOLUÇÃO',
                        icone: Icons.insights_rounded,
                        aoTocar: _abrirEvolucao,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BotaoGradiente(
                        texto: 'CARDÁPIO',
                        icone: Icons.restaurant_menu_rounded,
                        gradiente: AppColors.gradienteVerde,
                        aoTocar: _abrirEditorCardapio,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _abrirListaComprasPaciente,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: const Text('Ver Lista de Compras do Paciente'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.paletaRoxo,
                    side: const BorderSide(color: AppColors.paletaRoxo),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),
                BotaoGradiente(
                  texto: 'ENVIAR ORIENTAÇÃO',
                  icone: Icons.tips_and_updates_outlined,
                  aoTocar: _enviarOrientacao,
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),
                OutlinedButton.icon(
                  onPressed: _abrirChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Conversar no chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.verde,
                    side: const BorderSide(color: AppColors.verde),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirListaComprasPaciente() async {
    if (!widget.paciente.compartilharListaCompras) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.textoFraco),
              SizedBox(width: 8),
              Text('Lista Privada', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'O paciente optou por não compartilhar sua lista de compras no momento.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // Carregar itens da lista de compras
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalListaComprasPaciente(
        uidPaciente: widget.paciente.uid,
        nomePaciente: widget.paciente.nome,
        nutricionistaService: widget.nutricionistaService,
      ),
    );
  }

  Widget _linha(String rotulo, String? valor) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: 12.5,
                color: escuro
                    ? AppColors.fonteSubtituloClaro
                    : AppColors.textoSuave,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor ?? '--',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: escuro ? AppColors.paletaClaro : AppColors.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirEvolucao() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvolucaoScreen(
          evolucaoService: widget.evolucaoService,
          uidPaciente: widget.paciente.uid,
          nomePaciente: widget.paciente.nome,
        ),
      ),
    );
  }

  void _abrirEditorCardapio() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorCardapioScreen(
          uidPaciente: widget.paciente.uid,
          nomePaciente: widget.paciente.nome,
          nutricionistaService: widget.nutricionistaService,
        ),
      ),
    );
  }

  void _abrirChat() async {
    try {
      final contato = await widget.chatService
          .carregarContatoPadrao(uidPaciente: widget.paciente.uid);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatService: widget.chatService,
            idUsuario: widget.uidLogado,
            idContato: contato.idUsuario,
            nomeContato: contato.nome,
            papelContato: contato.papel,
          ),
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.mensagem)));
    }
  }

  Future<void> _enviarOrientacao() async {
    final textoController = TextEditingController();
    String categoria = 'positivo';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setEstado) => AlertDialog(
          title: const Text('Enviar orientação'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  children: ['positivo', 'neutro', 'melhoria']
                      .map(
                        (c) => ChoiceChip(
                          label: Text(switch (c) {
                            'positivo' => 'Positivo',
                            'melhoria' => 'Melhoria',
                            _ => 'Neutro',
                          }),
                          selected: categoria == c,
                          onSelected: (_) => setEstado(() => categoria = c),
                          selectedColor: AppColors.paletaVerdeSuave,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Escreva a orientação para o paciente...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verde,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true) {
      return;
    }
    final texto = textoController.text.trim();

    if (texto.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva o texto da orientação.')),
      );
      return;
    }

    try {
      await widget.nutricionistaService.enviarOrientacao(
        uidPaciente: widget.paciente.uid,
        categoria: categoria,
        texto: texto,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Orientação enviada com sucesso!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.mensagem)));
    }
  }
}

class _ModalListaComprasPaciente extends StatefulWidget {
  const _ModalListaComprasPaciente({
    required this.uidPaciente,
    required this.nomePaciente,
    required this.nutricionistaService,
  });

  final String uidPaciente;
  final String nomePaciente;
  final NutricionistaService nutricionistaService;

  @override
  State<_ModalListaComprasPaciente> createState() =>
      _ModalListaComprasPacienteState();
}

class _ModalListaComprasPacienteState
    extends State<_ModalListaComprasPaciente> {
  List<ItemCompra> _itens = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = await widget.nutricionistaService
          .obterListaComprasPaciente(widget.uidPaciente);
      final rawItens = (dados['itens'] as List? ?? []);
      final itens = rawItens
          .map((e) => ItemCompra.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _itens = itens;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Erro ao carregar lista de compras: $e';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final categorias = <String, List<ItemCompra>>{};
    for (final item in _itens) {
      categorias.putIfAbsent(item.categoria, () => []).add(item);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: escuro ? AppColors.paletaEscuroCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lista de Compras',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Paciente: ${widget.nomePaciente}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textoSuave,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_erro!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.vermelho)),
                        ),
                      )
                    : _itens.isEmpty
                        ? const Center(
                            child: Text(
                              'A lista de compras do paciente está vazia.',
                              style: TextStyle(color: AppColors.textoSuave),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              for (final cat in categorias.keys) ...[
                                Text(
                                  cat,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.paletaRoxo,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                for (final item in categorias[cat]!)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.manual
                                              ? Icons.edit_note_rounded
                                              : Icons.check_box_outline_blank,
                                          size: 18,
                                          color: AppColors.textoSuave,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.nome,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        Text(
                                          item.quantidadeG >= 1000
                                              ? '${(item.quantidadeG / 1000).toStringAsFixed(1)} kg'
                                              : '${item.quantidadeG.round()} g',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textoSuave),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//  Editor de cardapio (4.5.23) - wizard 3 passos
// =====================================================================

class EditorCardapioScreen extends StatefulWidget {
  const EditorCardapioScreen({
    super.key,
    required this.uidPaciente,
    required this.nomePaciente,
    required this.nutricionistaService,
  });

  final String uidPaciente;
  final String nomePaciente;
  final NutricionistaService nutricionistaService;

  @override
  State<EditorCardapioScreen> createState() => _EditorCardapioScreenState();
}

class _EditorCardapioScreenState extends State<EditorCardapioScreen> {
  static const _ordemDias = [
    'segunda',
    'terca',
    'quarta',
    'quinta',
    'sexta',
    'sabado',
    'domingo',
  ];
  static const _rotulosDia = {
    'segunda': 'Segunda',
    'terca': 'Terca',
    'quarta': 'Quarta',
    'quinta': 'Quinta',
    'sexta': 'Sexta',
    'sabado': 'Sabado',
    'domingo': 'Domingo',
  };
  static const _tipos = [
    ('cafeManha', 'Cafe da Manha', '07:30'),
    ('lancheManha', 'Lanche da Manha', '10:00'),
    ('almoco', 'Almoco', '12:30'),
    ('lancheTarde', 'Lanche da Tarde', '16:00'),
    ('jantar', 'Jantar', '19:30'),
    ('ceia', 'Ceia', '21:30'),
  ];

  Map<String, Map<String, dynamic>> _refeicoes = {};
  bool _carregando = true;
  String? _erro;
  String _dia = 'segunda';

  // Wizard.
  int _passo = 0;
  String? _tipoSelecionado;
  Receita? _receitaSelecionada;
  List<Receita> _receitas = [];
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    // Recarregas disparados apos uma mutacao (avaliar receita, concluir
    // consulta...) podem chegar com a aba ja descartada.
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados =
          await widget.nutricionistaService.carregarPlano(widget.uidPaciente);
      final lista = await widget.nutricionistaService.listarReceitas();
      if (!mounted) return;

      final refeicoes = <String, Map<String, dynamic>>{};
      for (final r in (dados['refeicoes'] as List? ?? const [])) {
        final mapa = r as Map<String, dynamic>;
        final dia = (mapa['dia'] ?? '').toString();
        final tipo = (mapa['tipo'] ?? '').toString();
        // Ignora documentos sem dia/tipo: eles nao correspondem a uma
        // das 42 refeicoes e inflariam a barra de montagem.
        if (dia.isEmpty || tipo.isEmpty) continue;
        refeicoes['${dia}_$tipo'] = mapa;
      }

      setState(() {
        _refeicoes = refeicoes;
        // Somente receitas aprovadas podem ser prescritas.
        _receitas = lista.where((r) => r.status == 'aprovada').toList();
        _carregando = false;
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _carregando = false;
      });
    } catch (erro) {
      // Sem este catch um erro de formato deixaria a tela girando.
      if (!mounted) return;
      setState(() {
        _erro = 'Formato inesperado na resposta da API: $erro';
        _carregando = false;
      });
    }
  }

  /// Refeicoes realmente prescritas (com receita), igual ao criterio
  /// usado nos cartoes: contar documentos inflaria a barra.
  int get _preenchidas => _refeicoes.values
      .where((r) => (r['nomeReceita'] as String?)?.isNotEmpty == true)
      .length;
  static const int _totalRefeicoes = 42; // 7 dias x 6 refeicoes

  Future<void> _salvarRefeicao() async {
    if (_receitaSelecionada == null || _tipoSelecionado == null) return;
    final nomeReceita = _receitaSelecionada!.nome;
    setState(() => _salvando = true);
    try {
      final horario = _tipos.firstWhere((t) => t.$1 == _tipoSelecionado).$3;
      await widget.nutricionistaService.definirRefeicao(
        uidPaciente: widget.uidPaciente,
        dia: _dia,
        tipo: _tipoSelecionado!,
        idReceita: _receitaSelecionada!.idReceita,
        horario: horario,
      );
      if (!mounted) return;
      setState(() {
        _refeicoes['$_dia' '_$_tipoSelecionado'] = {
          'dia': _dia,
          'tipo': _tipoSelecionado,
          'nomeReceita': nomeReceita,
        };
        _passo = 0;
        _tipoSelecionado = null;
        _receitaSelecionada = null;
        _salvando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refeicao definida: $nomeReceita'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.mensagem)));
    }
  }

  Future<void> _removerRefeicao(String tipo) async {
    try {
      await widget.nutricionistaService.removerRefeicao(
        uidPaciente: widget.uidPaciente,
        dia: _dia,
        tipo: tipo,
      );
      if (!mounted) return;
      setState(() => _refeicoes.remove('$_dia' '_$tipo'));
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Cardapio - ${widget.nomePaciente}',
            subtitulo: '$_preenchidas/$_totalRefeicoes refeicoes montadas',
            icone: Icons.restaurant_menu_rounded,
            aoVoltar: () => Navigator.of(context).maybePop(),
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
                          color: d == _dia
                              ? AppColors.paletaRoxo
                              : AppColors.cinzaSegmento,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() {
                              _dia = d;
                              _passo = 0;
                              _tipoSelecionado = null;
                              _receitaSelecionada = null;
                            }),
                            child: Center(
                              child: Text(
                                _rotulosDia[d]!.substring(0, 3),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: d == _dia
                                      ? Colors.white
                                      : AppColors.textoSuave,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _preenchidas / _totalRefeicoes,
                minHeight: 8,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF21262D)
                    : AppColors.cinzaTrilha,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.paletaLilasSuave
                        : AppColors.paletaRoxo),
              ),
            ),
          ),
          Expanded(
            child: _carregando
                ? const CarregandoView()
                : _erro != null
                    ? ErroView(mensagem: _erro!, aoTentar: _carregar)
                    : _conteudo(),
          ),
        ],
      ),
    );
  }

  Widget _conteudo() {
    if (_passo == 2) return _passoReceita();
    return _passoDia();
  }

  /// Passo 1: lista de refeicoes do dia selecionado. Tocar em uma
  /// refeicao ja escolhe o tipo e leva direto a escolha da receita.
  Widget _passoDia() {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        for (final (tipo, rotulo, _) in _tipos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(builder: (context) {
              final dados = _refeicoes['$_dia' '_$tipo'];
              final definida =
                  (dados?['nomeReceita'] as String?)?.isNotEmpty == true;
              return _CartaoRefeicaoEditor(
                rotulo: rotulo,
                definida: definida ? dados!['nomeReceita'] as String : '',
                aoEditar: () => setState(() {
                  _tipoSelecionado = tipo;
                  // Pre-seleciona a receita ja prescrita neste horario
                  // (e limpa a escolha anterior de outro horario).
                  final idAtual = dados?['idReceita'] as String?;
                  _receitaSelecionada = idAtual == null
                      ? null
                      : _receitas
                          .where((r) => r.idReceita == idAtual)
                          .firstOrNull;
                  _passo = 2;
                }),
                aoRemover: definida ? () => _removerRefeicao(tipo) : null,
              );
            }),
          ),
      ],
    );
  }

  /// Passo 2: escolher a receita da biblioteca.
  Widget _passoReceita() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.telaPadding),
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _passo = 0;
                  _receitaSelecionada = null;
                }),
                child: const Text('Cancelar'),
              ),
              const Spacer(),
              Text(
                _tipos
                    .firstWhere((t) => t.$1 == _tipoSelecionado,
                        orElse: () => _tipos.first)
                    .$2,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Expanded(
          child: _receitas.isEmpty
              ? const Center(
                  child: Text(
                    'Sua biblioteca de receitas esta vazia.\nCrie receitas na aba Receitas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.telaPadding),
                  children: [
                    for (final receita in _receitas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OpcaoEditor(
                          rotulo: receita.nome,
                          subtitulo:
                              '${receita.calorias.round()} kcal • P ${receita.proteinas.round()}g • C ${receita.carboidratos.round()}g • G ${receita.gorduras.round()}g',
                          selecionado: _receitaSelecionada?.idReceita ==
                              receita.idReceita,
                          aoTocar: () =>
                              setState(() => _receitaSelecionada = receita),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
          child: BotaoGradiente(
            texto: 'DEFINIR REFEICAO',
            icone: Icons.check_rounded,
            aoTocar: _salvando || _receitaSelecionada == null
                ? null
                : _salvarRefeicao,
            carregando: _salvando,
          ),
        ),
      ],
    );
  }
}

class _CartaoRefeicaoEditor extends StatelessWidget {
  const _CartaoRefeicaoEditor({
    required this.rotulo,
    required this.definida,
    required this.aoEditar,
    this.aoRemover,
  });

  final String rotulo;
  final String definida;
  final VoidCallback aoEditar;
  final VoidCallback? aoRemover;

  @override
  Widget build(BuildContext context) {
    return MvnCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.paletaLilasSuave
                        : AppColors.paletaRoxo,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  definida.isEmpty ? '+ Adicionar receita' : definida,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: definida.isEmpty
                        ? AppColors.textoFraco
                        : (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.paletaClaro
                            : AppColors.texto),
                  ),
                ),
              ],
            ),
          ),
          if (aoRemover != null)
            IconButton(
              onPressed: aoRemover,
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.vermelho, size: 18),
              tooltip: 'Remover',
            ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: aoEditar,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.paletaVerde,
              side: const BorderSide(color: AppColors.paletaVerde),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(definida.isEmpty ? 'Add' : 'Editar',
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _OpcaoEditor extends StatelessWidget {
  const _OpcaoEditor({
    required this.rotulo,
    required this.selecionado,
    required this.aoTocar,
    this.subtitulo,
  });

  final String rotulo;
  final String? subtitulo;
  final bool selecionado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: selecionado
          ? (escuro ? const Color(0xFF1E3A2F) : AppColors.paletaVerdeSuave)
          : (escuro ? AppColors.paletaEscuroCard : Colors.white),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: aoTocar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selecionado
                  ? AppColors.verde
                  : (escuro ? AppColors.bordaEscura : AppColors.borda),
              width: selecionado ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rotulo,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color:
                              escuro ? AppColors.paletaClaro : AppColors.texto,
                        )),
                    if (subtitulo != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitulo!,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: escuro
                                  ? AppColors.fonteSubtituloClaro
                                  : AppColors.textoFraco)),
                    ],
                  ],
                ),
              ),
              Icon(
                selecionado
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_off_rounded,
                color: selecionado ? AppColors.verde : AppColors.textoFraco,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  Aba Receitas: biblioteca (4.5.24) + compartilhadas (4.5.25)
// =====================================================================

class ReceitasTab extends StatefulWidget {
  const ReceitasTab({super.key, required this.nutricionistaService});

  final NutricionistaService nutricionistaService;

  @override
  State<ReceitasTab> createState() => _ReceitasTabState();
}

class _ReceitasTabState extends State<ReceitasTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _abas = TabController(length: 2, vsync: this);

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Material(
          color: escuro ? AppColors.paletaEscuroCard : Colors.white,
          child: TabBar(
            controller: _abas,
            labelColor: AppColors.verde,
            unselectedLabelColor: AppColors.textoSuave,
            indicatorColor: AppColors.verde,
            tabs: const [
              Tab(text: 'Minhas receitas'),
              Tab(text: 'Compartilhadas'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _abas,
            children: [
              _BibliotecaReceitas(
                  nutricionistaService: widget.nutricionistaService),
              _ReceitasCompartilhadas(
                  nutricionistaService: widget.nutricionistaService),
            ],
          ),
        ),
      ],
    );
  }
}

class _BibliotecaReceitas extends StatefulWidget {
  const _BibliotecaReceitas({required this.nutricionistaService});

  final NutricionistaService nutricionistaService;

  @override
  State<_BibliotecaReceitas> createState() => _BibliotecaReceitasState();
}

class _BibliotecaReceitasState extends State<_BibliotecaReceitas>
    with AutomaticKeepAliveClientMixin {
  List<Receita> _receitas = [];
  List<Alimento> _alimentos = [];
  bool _carregando = true;
  String? _erro;

  /// Mensagem quando a base de alimentos falhou ao carregar (diferente
  /// de a base estar realmente vazia).
  String? _erroAlimentos;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    // Recarregas disparados apos uma mutacao (avaliar receita, concluir
    // consulta...) podem chegar com a aba ja descartada.
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final receitas = await widget.nutricionistaService.listarReceitas();
      // Uma falha ao carregar alimentos nao impede ver a biblioteca, mas
      // e sinalizada: sem isso o editor diria "base vazia, rode o seed"
      // para um erro de rede.
      List<Alimento> alimentos;
      String? avisoAlimentos;
      try {
        alimentos = await widget.nutricionistaService.listarAlimentos();
      } on ApiException catch (erro) {
        alimentos = const [];
        avisoAlimentos = erro.mensagem;
      }
      if (!mounted) return;
      setState(() {
        // A biblioteca mostra apenas receitas APROVADAS: as enviadas por
        // pacientes ficam na aba "Compartilhadas" ate serem avaliadas
        // (editar uma pendente aqui a aprovaria por tabela).
        _receitas = receitas.where((r) => r.status == 'aprovada').toList();
        _alimentos = alimentos;
        _erroAlimentos = avisoAlimentos;
        _carregando = false;
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _carregando = false;
      });
    } catch (erro) {
      // Sem este catch um erro de formato deixaria a tela girando.
      if (!mounted) return;
      setState(() {
        _erro = 'Formato inesperado na resposta da API: $erro';
        _carregando = false;
      });
    }
  }

  Future<void> _abrirEditorReceita([Receita? existente]) async {
    final criada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditorReceitaScreen(
          nutricionistaService: widget.nutricionistaService,
          alimentos: _alimentos,
          erroAlimentos: _erroAlimentos,
          receita: existente,
        ),
      ),
    );
    if (criada == true) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    if (_carregando) return const CarregandoView();
    if (_erro != null) return ErroView(mensagem: _erro!, aoTentar: _carregar);

    return Stack(
      children: [
        if (_receitas.isEmpty)
          const Center(
            child: Text(
              'Nenhuma receita criada ainda.\nUse o botao + para criar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
            ),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: _receitas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = _receitas[i];
              return MvnCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.nome,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: escuro
                                  ? AppColors.paletaClaro
                                  : AppColors.texto,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 18,
                              color: escuro
                                  ? AppColors.paletaVerde
                                  : AppColors.paletaRoxo),
                          onPressed: () => _abrirEditorReceita(r),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.calorias.round()} kcal • '
                      'P ${r.proteinas.round()}g • '
                      'C ${r.carboidratos.round()}g • '
                      'G ${r.gorduras.round()}g',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textoFraco),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.ingredientes.length} ingredientes',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textoSuave),
                    ),
                  ],
                ),
              );
            },
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: AppColors.verde,
            onPressed: () => _abrirEditorReceita(),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Editor de receita pratico e moderno (Página 2 do documento de requisitos).
///
/// Permite busca instantanea de alimentos, selecao rapida por categoria,
/// adicao de porcoes com 1 clique (+50g, +100g, etc.) e painel de resumo
/// de macros nutricionais calculado em tempo real.
class EditorReceitaScreen extends StatefulWidget {
  const EditorReceitaScreen({
    super.key,
    required this.nutricionistaService,
    required this.alimentos,
    this.erroAlimentos,
    this.receita,
  });

  final NutricionistaService nutricionistaService;
  final List<Alimento> alimentos;
  final String? erroAlimentos;
  final Receita? receita;

  @override
  State<EditorReceitaScreen> createState() => _EditorReceitaScreenState();
}

class _EditorReceitaScreenState extends State<EditorReceitaScreen> {
  late final TextEditingController _nome =
      TextEditingController(text: widget.receita?.nome ?? '');
  late final TextEditingController _modo =
      TextEditingController(text: widget.receita?.modoPreparo ?? '');
  final TextEditingController _buscaAlimento = TextEditingController();

  final List<Ingrediente> _ingredientes = [];
  String _categoriaSelecionada = 'Todas';
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _ingredientes.addAll(widget.receita?.ingredientes ?? const []);
  }

  @override
  void dispose() {
    _nome.dispose();
    _modo.dispose();
    _buscaAlimento.dispose();
    super.dispose();
  }

  // Calculo de macros em tempo real
  double get _caloriasTotais =>
      _ingredientes.fold(0.0, (s, i) => s + i.caloriasNaPorcao);
  double get _proteinasTotais => _ingredientes.fold(
      0.0, (s, i) => s + (i.proteinas * i.quantidadeG / 100));
  double get _carbsTotais => _ingredientes.fold(
      0.0, (s, i) => s + (i.carboidratos * i.quantidadeG / 100));
  double get _gordurasTotais =>
      _ingredientes.fold(0.0, (s, i) => s + (i.gorduras * i.quantidadeG / 100));

  List<String> get _categorias {
    final set = <String>{'Todas'};
    for (final a in widget.alimentos) {
      if (a.categoria.isNotEmpty) set.add(a.categoria);
    }
    return set.toList();
  }

  List<Alimento> get _alimentosFiltrados {
    final busca = _buscaAlimento.text.trim().toLowerCase();
    return widget.alimentos.where((a) {
      final matchBusca = busca.isEmpty ||
          a.nome.toLowerCase().contains(busca) ||
          a.categoria.toLowerCase().contains(busca);
      final matchCat = _categoriaSelecionada == 'Todas' ||
          a.categoria.toLowerCase() == _categoriaSelecionada.toLowerCase();
      return matchBusca && matchCat;
    }).toList();
  }

  void _adicionarIngredienteRapido(Alimento a, double qtd) {
    setState(() {
      final indexExistente =
          _ingredientes.indexWhere((i) => i.idAlimento == a.idAlimento);
      if (indexExistente >= 0) {
        final atual = _ingredientes[indexExistente];
        _ingredientes[indexExistente] = Ingrediente.doAlimento(
          a,
          atual.quantidadeG + qtd,
        );
      } else {
        _ingredientes.add(Ingrediente.doAlimento(a, qtd));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('+${qtd.round()}g de ${a.nome} adicionado!'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.paletaVerde,
      ),
    );
  }

  void _ajustarQuantidade(int index, double delta) {
    setState(() {
      final item = _ingredientes[index];
      final novaQtd = item.quantidadeG + delta;
      if (novaQtd <= 0) {
        _ingredientes.removeAt(index);
      } else {
        final alimentoBase = widget.alimentos.firstWhere(
          (a) => a.idAlimento == item.idAlimento,
          orElse: () => Alimento(
            idAlimento: item.idAlimento ?? '',
            nome: item.nome,
            categoria: '',
            calorias: item.calorias,
            proteinas: item.proteinas,
            carboidratos: item.carboidratos,
            gorduras: item.gorduras,
          ),
        );
        _ingredientes[index] = Ingrediente.doAlimento(alimentoBase, novaQtd);
      }
    });
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty || _ingredientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Informe o nome da receita e pelo menos um ingrediente.'),
        ),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      await widget.nutricionistaService.salvarReceita(
        idReceita: widget.receita?.idReceita,
        nome: nome,
        modoPreparo: _modo.text.trim(),
        ingredientes: _ingredientes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receita salva com sucesso!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            escuro ? AppColors.paletaEscuroCard : AppColors.paletaRoxo,
        title: Text(
          widget.receita == null ? 'Nova Receita Prática' : 'Editar Receita',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Salvar receita',
            onPressed: _salvando ? null : _salvar,
            icon: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, color: Colors.white),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.telaPadding),
        children: [
          // -------------------------------------------------------------
          // Painel de Macros em Tempo Real
          // -------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.paletaRoxo, Color(0xFF6B21A8)],
              ),
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Resumo Nutricional da Receita',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.paletaVerde,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_caloriasTotais.round()} kcal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _cardMacro(
                      rotulo: 'Proteínas',
                      valor: '${_proteinasTotais.toStringAsFixed(1)}g',
                      cor: AppColors.paletaVerde,
                    ),
                    const SizedBox(width: 8),
                    _cardMacro(
                      rotulo: 'Carboidratos',
                      valor: '${_carbsTotais.toStringAsFixed(1)}g',
                      cor: const Color(0xFF60A5FA),
                    ),
                    const SizedBox(width: 8),
                    _cardMacro(
                      rotulo: 'Gorduras',
                      valor: '${_gordurasTotais.toStringAsFixed(1)}g',
                      cor: const Color(0xFFFBBF24),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // -------------------------------------------------------------
          // Dados basicos: Nome e Modo de Preparo
          // -------------------------------------------------------------
          MvnCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nome da Receita',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nome,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Frango Grelhado com Batata Doce',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Modo de Preparo / Orientações',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _modo,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Instruções simples de preparo ou dicas...',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // -------------------------------------------------------------
          // Seletor Rapido de Ingredientes
          // -------------------------------------------------------------
          MvnCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_shopping_cart_rounded,
                        size: 20, color: AppColors.paletaVerde),
                    SizedBox(width: 8),
                    Text(
                      'Adicionar Ingredientes',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Campo de Busca Instantanea
                TextField(
                  controller: _buscaAlimento,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar alimento (ex: frango, arroz, ovo)...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    suffixIcon: _buscaAlimento.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () =>
                                setState(() => _buscaAlimento.clear()),
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 10),

                // Chips de Categoria
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categorias.map((cat) {
                      final sel = _categoriaSelecionada == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: sel,
                          selectedColor: AppColors.paletaVerde,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                            color: sel ? Colors.white : AppColors.fonteTitulo,
                          ),
                          onSelected: (_) =>
                              setState(() => _categoriaSelecionada = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 10),

                // Lista de alimentos sugeridos com adicao em 1 toque
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: escuro ? const Color(0xFF0D1117) : AppColors.fundo,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: escuro ? AppColors.bordaEscura : AppColors.borda,
                    ),
                  ),
                  child: _alimentosFiltrados.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Nenhum alimento encontrado com este termo.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textoSuave),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _alimentosFiltrados.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final a = _alimentosFiltrados[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                a.nome,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: escuro
                                      ? AppColors.paletaClaro
                                      : AppColors.texto,
                                ),
                              ),
                              subtitle: Text(
                                '${a.calorias.round()} kcal/100g • ${a.categoria}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: escuro
                                      ? AppColors.fonteSubtituloClaro
                                      : AppColors.textoFraco,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _chipPorcaoRapida('+50g',
                                      () => _adicionarIngredienteRapido(a, 50)),
                                  const SizedBox(width: 4),
                                  _chipPorcaoRapida(
                                      '+100g',
                                      () =>
                                          _adicionarIngredienteRapido(a, 100)),
                                  const SizedBox(width: 4),
                                  _chipPorcaoRapida(
                                      '+200g',
                                      () =>
                                          _adicionarIngredienteRapido(a, 200)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // -------------------------------------------------------------
          // Lista de Ingredientes ja Selecionados
          // -------------------------------------------------------------
          MvnCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ingredientes da Receita (${_ingredientes.length})',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    if (_ingredientes.isNotEmpty)
                      Text(
                        'Total: ${_caloriasTotais.round()} kcal',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.paletaVerde,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_ingredientes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Nenhum ingrediente adicionado ainda.\nSelecione acima para adicionar à receita.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textoSuave),
                      ),
                    ),
                  )
                else
                  for (final (i, ing) in _ingredientes.indexed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: escuro
                            ? const Color(0xFF0D1117)
                            : AppColors.paletaVerdeSuave.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: escuro
                              ? AppColors.bordaEscura
                              : AppColors.paletaVerde.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ing.nome,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: escuro
                                        ? AppColors.paletaClaro
                                        : AppColors.texto,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${ing.quantidadeG.round()}g • ${ing.caloriasNaPorcao.round()} kcal',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: escuro
                                        ? AppColors.fonteSubtituloClaro
                                        : AppColors.textoSuave,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Botoes rapidos -25g e +25g
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline,
                                size: 20,
                                color: escuro
                                    ? AppColors.paletaVerde
                                    : AppColors.paletaRoxo),
                            onPressed: () => _ajustarQuantidade(i, -25),
                          ),
                          Text(
                            '${ing.quantidadeG.round()}g',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: escuro
                                  ? AppColors.paletaClaro
                                  : AppColors.texto,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                size: 20, color: AppColors.paletaVerde),
                            onPressed: () => _ajustarQuantidade(i, 25),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.vermelho),
                            onPressed: () =>
                                setState(() => _ingredientes.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Botao Salvar no rodape
          SizedBox(
            height: AppSizes.botaoAltura,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.paletaVerde,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.botaoRadius),
                ),
                elevation: 0,
              ),
              onPressed: _salvando ? null : _salvar,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                widget.receita == null
                    ? 'Criar e Salvar Receita'
                    : 'Atualizar Receita',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipPorcaoRapida(String rotulo, VoidCallback aoTocar) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: escuro
              ? const Color(0xFF1E3A2F)
              : AppColors.paletaVerde.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: escuro ? AppColors.paletaVerde : AppColors.verdeEscuro,
          ),
        ),
      ),
    );
  }

  Widget _cardMacro({
    required String rotulo,
    required String valor,
    required Color cor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              rotulo,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
            const SizedBox(height: 2),
            Text(
              valor,
              style: TextStyle(
                color: cor,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceitasCompartilhadas extends StatefulWidget {
  const _ReceitasCompartilhadas({required this.nutricionistaService});

  final NutricionistaService nutricionistaService;

  @override
  State<_ReceitasCompartilhadas> createState() =>
      _ReceitasCompartilhadasState();
}

class _ReceitasCompartilhadasState extends State<_ReceitasCompartilhadas>
    with AutomaticKeepAliveClientMixin {
  List<Receita> _pendentes = [];
  bool _carregando = true;
  String? _erro;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    // Recarregas disparados apos uma mutacao (avaliar receita, concluir
    // consulta...) podem chegar com a aba ja descartada.
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final pendentes =
          await widget.nutricionistaService.listarReceitasPendentes();
      if (!mounted) return;
      setState(() {
        _pendentes = pendentes;
        _carregando = false;
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _carregando = false;
      });
    } catch (erro) {
      // Sem este catch um erro de formato deixaria a tela girando.
      if (!mounted) return;
      setState(() {
        _erro = 'Formato inesperado na resposta da API: $erro';
        _carregando = false;
      });
    }
  }

  Future<void> _avaliar(Receita receita, String status) async {
    String justificativa = '';
    if (status == 'recusada') {
      // null = cancelou o dialogo; '' = confirmou sem escrever nada.
      final informada = await _pedirJustificativa(receita);
      if (informada == null) return;
      if (informada.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escreva a justificativa para recusar a receita.'),
          ),
        );
        return;
      }
      justificativa = informada;
    }
    try {
      await widget.nutricionistaService.avaliarReceita(
        idReceita: receita.idReceita,
        status: status,
        justificativa: justificativa,
      );
      await _carregar();
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.mensagem)));
    }
  }

  Future<String?> _pedirJustificativa(Receita receita) async {
    final controller = TextEditingController();
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Recusar "${receita.nome}"'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration:
              const InputDecoration(hintText: 'Justificativa (obrigatoria)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Recusar',
                style: TextStyle(color: AppColors.vermelho)),
          ),
        ],
      ),
    );
    controller.dispose();
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    if (_carregando) return const CarregandoView();
    if (_erro != null) return ErroView(mensagem: _erro!, aoTentar: _carregar);

    if (_pendentes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma receita aguardando avaliacao.',
          style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        for (final receita in _pendentes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MvnCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receita.nome,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: escuro ? AppColors.paletaClaro : AppColors.texto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${receita.ingredientes.length} ingredientes • '
                    '${receita.calorias.round()} kcal',
                    style: TextStyle(
                      fontSize: 12,
                      color: escuro
                          ? AppColors.fonteSubtituloClaro
                          : AppColors.textoSuave,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _avaliar(receita, 'aprovada'),
                          icon: const Icon(Icons.check_rounded, size: 17),
                          label: const Text('Aprovar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.verde,
                            side: const BorderSide(color: AppColors.verde),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _avaliar(receita, 'recusada'),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text('Recusar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.vermelho,
                            side: const BorderSide(color: AppColors.vermelho),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// =====================================================================
// =====================================================================
//  Aba Agenda (Página 2 do documento de requisitos)
//  Com 2 subtelas:
//   1. Configurar Horários (rápido + lote)
//   2. Consultas & Pedidos
// =====================================================================

class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key, required this.nutricionistaService});

  final NutricionistaService nutricionistaService;

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab>
    with AutomaticKeepAliveClientMixin {
  int _subAba = 0; // 0 = Configurar Horarios, 1 = Consultas & Pedidos, 2 = Histórico
  List<Consulta> _consultas = [];
  bool _carregando = true;
  String? _erro;

  // Data selecionada para configuracao rapida
  DateTime _dataSelecionada = DateTime.now().add(const Duration(days: 1));

  @override
  bool get wantKeepAlive => true;

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
      final consultas = await widget.nutricionistaService.listarConsultas();
      if (!mounted) return;
      setState(() {
        _consultas = consultas;
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

  List<Consulta> get _horariosLivres =>
      _consultas.where((c) => c.status == 'disponivel').toList();

  List<Consulta> get _pedidosPendentes =>
      _consultas.where((c) => c.status == 'pendente').toList();

  List<Consulta> get _consultasConfirmadas =>
      _consultas.where((c) => c.status == 'confirmada').toList();

  List<Consulta> get _historico =>
      _consultas.where((c) => c.status == 'concluida').toList();

  Future<void> _adicionarHorarioRapido(int hora, int minuto) async {
    final dataHora = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      _dataSelecionada.day,
      hora,
      minuto,
    );

    // Evita duplicar se ja existir esse horario
    final jaExiste = _consultas.any((c) =>
        c.dataHora.year == dataHora.year &&
        c.dataHora.month == dataHora.month &&
        c.dataHora.day == dataHora.day &&
        c.dataHora.hour == dataHora.hour &&
        c.dataHora.minute == dataHora.minute &&
        c.status != 'cancelada');

    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'O horário ${_formatarHora(dataHora)} já está cadastrado nesta data.',
          ),
        ),
      );
      return;
    }

    try {
      await widget.nutricionistaService.criarConsulta(dataHora: dataHora);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Horário ${_formatarHora(dataHora)} disponibilizado para ${_formatarDataSimples(_dataSelecionada)}!',
          ),
          backgroundColor: AppColors.verdeEscuro,
          duration: const Duration(seconds: 2),
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  Future<void> _gerarLoteHorariosDialog() async {
    int horaInicio = 8;
    int horaFim = 12;
    int intervaloMin = 60;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.paletaVerde),
              SizedBox(width: 8),
              Text('Gerar Horários em Lote', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data: ${_formatarDataSimples(_dataSelecionada)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              const Text('Período sugerido:',
                  style: TextStyle(fontSize: 12, color: AppColors.textoSuave)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Manhã (08h às 12h)'),
                    selected: horaInicio == 8 && horaFim == 12,
                    onSelected: (_) => setDialogState(() {
                      horaInicio = 8;
                      horaFim = 12;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Tarde (14h às 18h)'),
                    selected: horaInicio == 14 && horaFim == 18,
                    onSelected: (_) => setDialogState(() {
                      horaInicio = 14;
                      horaFim = 18;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Dia Todo (08h às 17h)'),
                    selected: horaInicio == 8 && horaFim == 17,
                    onSelected: (_) => setDialogState(() {
                      horaInicio = 8;
                      horaFim = 17;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Intervalo entre consultas:',
                  style: TextStyle(fontSize: 12, color: AppColors.textoSuave)),
              const SizedBox(height: 6),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('30 min'),
                    selected: intervaloMin == 30,
                    onSelected: (_) => setDialogState(() => intervaloMin = 30),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('60 min (1h)'),
                    selected: intervaloMin == 60,
                    onSelected: (_) => setDialogState(() => intervaloMin = 60),
                  ),
                ],
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
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Gerar Horários'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true) return;

    final listaDatas = <DateTime>[];
    DateTime cursor = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      _dataSelecionada.day,
      horaInicio,
      0,
    );
    final limite = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      _dataSelecionada.day,
      horaFim,
      0,
    );

    while (cursor.isBefore(limite) || cursor.isAtSameMomentAs(limite)) {
      listaDatas.add(cursor);
      cursor = cursor.add(Duration(minutes: intervaloMin));
    }

    try {
      await widget.nutricionistaService.criarHorariosLote(horarios: listaDatas);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${listaDatas.length} horários criados com sucesso!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  Future<void> _abrirDatePicker() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida != null && mounted) {
      setState(() => _dataSelecionada = escolhida);
    }
  }

  Future<void> _aprovar(Consulta consulta) async {
    try {
      await widget.nutricionistaService.aprovarConsulta(consulta.idConsulta);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consulta confirmada com sucesso!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  Future<void> _recusar(Consulta consulta) async {
    try {
      await widget.nutricionistaService.recusarConsulta(consulta.idConsulta);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitação recusada.'),
          backgroundColor: AppColors.fonteSubtitulo,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  Future<void> _concluir(Consulta consulta) async {
    try {
      await widget.nutricionistaService.concluirConsulta(consulta.idConsulta);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consulta marcada como concluída!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  Future<void> _cancelar(Consulta consulta) async {
    final livre = consulta.status == 'disponivel';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(livre ? 'Remover horário' : 'Cancelar consulta'),
        content: Text(
          livre
              ? 'O horário deixará de aparecer na agenda. Continuar?'
              : 'A consulta será cancelada para você e para o paciente. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              livre ? 'Remover' : 'Cancelar consulta',
              style: const TextStyle(color: AppColors.vermelho),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await widget.nutricionistaService.cancelarConsulta(consulta.idConsulta);
      await _carregar();
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  Future<void> _editarConsultaDialog(Consulta consulta) async {
    DateTime novaData = consulta.dataHora;
    TimeOfDay novoHorario = TimeOfDay(hour: consulta.dataHora.hour, minute: consulta.dataHora.minute);
    final obsController = TextEditingController(text: consulta.observacoes);

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: AppColors.paletaRoxo),
              SizedBox(width: 8),
              Text('Editar Consulta', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (consulta.nomePaciente != null)
                Text(
                  'Paciente: ${consulta.nomePaciente}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: AppColors.paletaVerde),
                title: const Text('Data', style: TextStyle(fontSize: 12, color: AppColors.textoSuave)),
                subtitle: Text(
                  _formatarDataCompleta(novaData),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final escolhida = await showDatePicker(
                      context: context,
                      initialDate: novaData,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (escolhida != null) {
                      setDialogState(() => novaData = escolhida);
                    }
                  },
                  child: const Text('Alterar'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: AppColors.paletaVerde),
                title: const Text('Horário', style: TextStyle(fontSize: 12, color: AppColors.textoSuave)),
                subtitle: Text(
                  '${novoHorario.hour.toString().padLeft(2, '0')}:${novoHorario.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final escolhido = await showTimePicker(
                      context: context,
                      initialTime: novoHorario,
                    );
                    if (escolhido != null) {
                      setDialogState(() => novoHorario = escolhido);
                    }
                  },
                  child: const Text('Alterar'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: obsController,
                decoration: const InputDecoration(
                  labelText: 'Observações / Motivo',
                  hintText: 'Ex: Consulta de retorno nutricional',
                  isDense: true,
                ),
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
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true) {
      obsController.dispose();
      return;
    }

    final dataHoraFinal = DateTime(
      novaData.year,
      novaData.month,
      novaData.day,
      novoHorario.hour,
      novoHorario.minute,
    );

    try {
      await widget.nutricionistaService.editarConsulta(
        consulta.idConsulta,
        dataHora: dataHoraFinal,
        observacoes: obsController.text.trim(),
      );
      obsController.dispose();
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consulta atualizada com sucesso!'),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      obsController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.mensagem)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    if (_carregando) return const CarregandoView();
    if (_erro != null) return ErroView(mensagem: _erro!, aoTentar: _carregar);

    return RefreshIndicator(
      color: AppColors.verde,
      onRefresh: _carregar,
      child: Column(
        children: [
          // -------------------------------------------------------------
          // Seletor Superior de Sub-abas da Agenda (3 Abas)
          // -------------------------------------------------------------
          Container(
            color: escuro ? AppColors.paletaEscuroCard : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _botaoAbaAgenda(
                    indice: 0,
                    rotulo: 'Configurar Horários',
                    contador: _horariosLivres.length,
                    escuro: escuro,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _botaoAbaAgenda(
                    indice: 1,
                    rotulo: 'Consultas',
                    contador: _consultasConfirmadas.length + _pedidosPendentes.length,
                    escuro: escuro,
                    alerta: _pedidosPendentes.isNotEmpty,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _botaoAbaAgenda(
                    indice: 2,
                    rotulo: 'Histórico',
                    contador: _historico.length,
                    escuro: escuro,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Conteudo da subtela ativa
          Expanded(
            child: _subAba == 0
                ? _conteudoConfigurarHorarios()
                : _subAba == 1
                    ? _conteudoConsultasPedidos()
                    : _conteudoHistorico(),
          ),
        ],
      ),
    );
  }

  Widget _botaoAbaAgenda({
    required int indice,
    required String rotulo,
    required int contador,
    required bool escuro,
    bool alerta = false,
  }) {
    final ativo = _subAba == indice;
    return InkWell(
      onTap: () => setState(() => _subAba = indice),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativo
              ? AppColors.paletaVerde
              : (escuro
                  ? const Color(0xFF21262D)
                  : AppColors.cinzaSegmento),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: ativo ? FontWeight.bold : FontWeight.w500,
                  color: ativo
                      ? Colors.white
                      : (escuro ? AppColors.paletaClaro : AppColors.fonteTitulo),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: alerta && !ativo
                    ? const Color(0xFFD97706)
                    : (ativo ? Colors.white.withValues(alpha: 0.25) : Colors.black12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$contador',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: alerta && !ativo ? Colors.white : (ativo ? Colors.white : AppColors.textoSuave),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Subtela 1: Configurar Horários (Rápido e em Lote)
  // -----------------------------------------------------------------
  Widget _conteudoConfigurarHorarios() {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final livres = _horariosLivres;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        // Card de selecao de data
        MvnCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Data Selecionada',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _abrirDatePicker,
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('Trocar Data'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          escuro ? AppColors.paletaVerde : AppColors.paletaRoxo,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: escuro
                      ? const Color(0xFF21262D)
                      : AppColors.paletaVerdeSuave.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event,
                        size: 20, color: AppColors.paletaVerde),
                    const SizedBox(width: 8),
                    Text(
                      _formatarDataCompleta(_dataSelecionada),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: escuro
                            ? AppColors.paletaLilasSuave
                            : AppColors.paletaRoxo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Atalhos rapidos de horarios
              const Text(
                'Clique para abrir horário com 1 toque:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textoSuave),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chipHorarioRapido(8, 0, '08:00'),
                  _chipHorarioRapido(9, 0, '09:00'),
                  _chipHorarioRapido(10, 0, '10:00'),
                  _chipHorarioRapido(11, 0, '11:00'),
                  _chipHorarioRapido(14, 0, '14:00'),
                  _chipHorarioRapido(15, 0, '15:00'),
                  _chipHorarioRapido(16, 0, '16:00'),
                  _chipHorarioRapido(17, 0, '17:00'),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Botao Gerar em Lote
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _gerarLoteHorariosDialog,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Gerar Múltiplos Horários em Lote'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        escuro ? AppColors.paletaVerde : AppColors.paletaRoxo,
                    side: BorderSide(
                        color: escuro
                            ? AppColors.paletaVerde
                            : AppColors.paletaRoxo),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Lista de Horarios Livres Disponiveis
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Horários Disponíveis na Agenda (${livres.length})',
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (livres.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Nenhum horário livre aberto na agenda.\nUse os botões acima para disponibilizar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textoSuave),
              ),
            ),
          )
        else
          ...livres.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MvnCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.paletaVerdeSuave,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.schedule,
                          color: AppColors.paletaVerde, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.diaSemanaExtenso} • ${c.horaFormatada}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.dataCompletaExtenso,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.paletaVerde,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remover este horário',
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.vermelho),
                      onPressed: () => _cancelar(c),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // -----------------------------------------------------------------
  // Subtela 2: Consultas & Pedidos (Agendadas e Pedidos de Pacientes)
  // -----------------------------------------------------------------
  Widget _conteudoConsultasPedidos() {
    final pedidos = _pedidosPendentes;
    final confirmadas = _consultasConfirmadas;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        // Seção: Pedidos de Agendamento Pendentes
        if (pedidos.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded,
                  size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Text(
                'Solicitações de Agendamento (${pedidos.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pedidos.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFFDE68A),
                        child: Icon(Icons.person, size: 18, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nomePaciente ?? 'Paciente',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF78350F),
                              ),
                            ),
                            Text(
                              '${p.diaSemanaExtenso} às ${p.horaFormatada}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.dataCompletaExtenso,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _recusar(p),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Recusar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.vermelho,
                          side: const BorderSide(color: AppColors.vermelho),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _aprovar(p),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Confirmar Consulta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.verde,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
        ],

        // Secao: Consultas Confirmadas
        Row(
          children: [
            const Icon(Icons.event_available,
                size: 18, color: AppColors.paletaVerde),
            const SizedBox(width: 6),
            Text(
              'Consultas Agendadas (${confirmadas.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (confirmadas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Nenhuma consulta agendada no momento.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textoSuave),
              ),
            ),
          )
        else
          ...confirmadas.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MvnCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.paletaVerdeSuave,
                          child:
                              Icon(Icons.person, color: AppColors.paletaRoxo),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.nomePaciente != null
                                    ? '${c.nomePaciente} • ${c.diaSemanaExtenso}'
                                    : c.diaSemanaExtenso,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.horaFormatada} (${c.dataCompletaExtenso})',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.verdeEscuro,
                                    fontWeight: FontWeight.w600),
                              ),
                              if (c.observacoes.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  c.observacoes,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textoSuave),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _editarConsultaDialog(c),
                            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                            label: const Text('Editar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.paletaRoxo,
                              side: const BorderSide(color: AppColors.paletaRoxo),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelar(c),
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Cancelar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.vermelho,
                              side: BorderSide(
                                  color: AppColors.vermelho
                                      .withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _concluir(c),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Concluir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.paletaVerde,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // -----------------------------------------------------------------
  // Subtela 3: Histórico de Consultas (Apenas comparecidas/concluídas)
  // -----------------------------------------------------------------
  Widget _conteudoHistorico() {
    final historico = _historico;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        Row(
          children: [
            const Icon(Icons.history_edu_rounded,
                size: 20, color: AppColors.paletaVerde),
            const SizedBox(width: 8),
            Text(
              'Histórico de Atendimentos Realizados (${historico.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Exibindo apenas consultas em que os pacientes compareceram.',
          style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
        ),
        const SizedBox(height: 12),

        if (historico.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Nenhuma consulta concluída no histórico ainda.',
                style: TextStyle(fontSize: 13, color: AppColors.textoSuave),
              ),
            ),
          )
        else
          ...historico.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MvnCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.paletaVerdeSuave,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppColors.paletaVerde,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.nomePaciente != null
                                ? '${c.nomePaciente} • ${c.diaSemanaExtenso}'
                                : c.diaSemanaExtenso,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c.horaFormatada} • ${c.dataCompletaExtenso}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textoSuave,
                            ),
                          ),
                          if (c.observacoes.isNotEmpty)
                            Text(
                              c.observacoes,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.fontePlaceholder,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.paletaVerdeSuave,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Compareceu',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.verdeEscuro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _chipHorarioRapido(int hora, int minuto, String texto) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return ActionChip(
      avatar: Icon(Icons.add,
          size: 14,
          color: escuro ? AppColors.paletaVerde : AppColors.paletaRoxo),
      label: Text(texto),
      backgroundColor:
          escuro ? const Color(0xFF1E3A2F) : AppColors.paletaLilasSuave,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: escuro ? AppColors.paletaVerde : AppColors.paletaRoxo,
      ),
      onPressed: () => _adicionarHorarioRapido(hora, minuto),
    );
  }

  static String _formatarHora(DateTime data) {
    return '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  static String _formatarDataSimples(DateTime data) {
    const meses = [
      '',
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
      '07',
      '08',
      '09',
      '10',
      '11',
      '12'
    ];
    return '${data.day.toString().padLeft(2, '0')}/${meses[data.month]}/${data.year}';
  }

  static String _formatarDataCompleta(DateTime data) {
    const dias = [
      '',
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    const meses = [
      '',
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    return '${dias[data.weekday]}, ${data.day} de ${meses[data.month]}';
  }
}

// =====================================================================
//  Relatorios (4.5.27)
// =====================================================================

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key, required this.nutricionistaService});

  final NutricionistaService nutricionistaService;

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  List<RelatorioPaciente> _relatorios = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    // Recarregas disparados apos uma mutacao (avaliar receita, concluir
    // consulta...) podem chegar com a aba ja descartada.
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final relatorios = await widget.nutricionistaService.carregarRelatorios();
      if (!mounted) return;
      setState(() {
        _relatorios = relatorios;
        _carregando = false;
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _carregando = false;
      });
    } catch (erro) {
      // Sem este catch um erro de formato deixaria a tela girando.
      if (!mounted) return;
      setState(() {
        _erro = 'Formato inesperado na resposta da API: $erro';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Relatorios e analise',
            subtitulo: 'Ultimos 30 dias',
            icone: Icons.insights_outlined,
            aoVoltar: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: _carregando
                ? const CarregandoView()
                : _erro != null
                    ? ErroView(mensagem: _erro!, aoTentar: _carregar)
                    : _relatorios.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum paciente com dados no periodo.',
                              style: TextStyle(
                                  color: AppColors.textoSuave, fontSize: 13),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(AppSizes.telaPadding),
                            children: [
                              for (final r in _relatorios)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: MvnCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                r.nome,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              r.pesoAtual != null
                                                  ? '${r.pesoAtual!.toStringAsFixed(1)} kg'
                                                  : '--',
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.verde,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Variacao 30d: ${_variacao(r)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textoSuave),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Aderencia media: '
                                          '${r.aderenciaMedia != null ? '${r.aderenciaMedia!.toStringAsFixed(0)}%' : '--'}'
                                          ' • Registros: ${r.frequenciaRegistros}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textoSuave),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  /// Variacao de peso do periodo com sinal explicito.
  /// A API devolve positivo quando o paciente PERDEU peso.
  static String _variacao(RelatorioPaciente r) {
    if (r.evolucaoPeso.length < 2) return 'sem dados suficientes';
    final valor = r.variacao30d;
    if (valor == 0) return 'estavel';
    final sinal = valor > 0 ? '-' : '+';
    return '$sinal${valor.abs().toStringAsFixed(1)} kg';
  }
}
