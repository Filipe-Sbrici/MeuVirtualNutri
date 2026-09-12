/// Tela "Meu nutricionista" (4.5.15 do prototipo).
///
/// Tres abas:
///  - Contato: perfil do nutricionista (nome, CRN, especializacao) com
///    acesso ao chat e videochamada.
///  - Orientacoes: feedbacks do nutricionista (positivo/neutro/melhoria).
///  - Agenda: consultas agendadas e historico.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/cardapio.dart';
import '../models/mensagem.dart';
import '../models/usuario.dart';
import '../services/chat_service.dart';
import '../services/mvn_services.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';

class MeuNutriScreen extends StatefulWidget {
  const MeuNutriScreen({
    super.key,
    required this.usuario,
    required this.chatService,
    required this.cardapioService,
  });

  final Usuario usuario;
  final ChatService chatService;
  final CardapioService cardapioService;

  @override
  State<MeuNutriScreen> createState() => _MeuNutriScreenState();
}

class _MeuNutriScreenState extends State<MeuNutriScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _abas = TabController(length: 3, vsync: this);

  Contato? _nutricionista;
  List<Orientacao> _orientacoes = [];
  List<Consulta> _consultas = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      // O contato e OPCIONAL: um paciente que ainda nao escolheu
      // nutricionista recebe 404 aqui, mas as abas de Orientacoes e
      // Agenda continuam validas (a aba Contato mostra o convite para
      // refazer o onboarding).
      Contato? contato;
      try {
        contato = await widget.chatService.carregarContatoPadrao();
      } on ApiException {
        contato = null;
      }

      final orientacoes = await widget.cardapioService.listarOrientacoes();
      final consultas = await widget.cardapioService.listarConsultas();
      if (!mounted) return;
      setState(() {
        _nutricionista = contato;
        _orientacoes = orientacoes;
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
      // Sem este catch um erro de formato deixaria a tela girando.
      if (!mounted) return;
      setState(() {
        _erro = 'Formato inesperado na resposta da API: $erro';
        _carregando = false;
      });
    }
  }

  void _abrirChat() {
    if (_nutricionista == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatService: widget.chatService,
          idUsuario: widget.usuario.uid,
          idContato: _nutricionista!.idUsuario,
          nomeContato: _nutricionista!.nome,
          papelContato: _nutricionista!.papel,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Meu nutricionista',
            icone: Icons.health_and_safety_outlined,
            gradiente: AppColors.gradienteChat,
            aoVoltar: () => Navigator.of(context).maybePop(),
          ),
          Material(
            color: escuro ? AppColors.paletaEscuroCard : Colors.white,
            child: TabBar(
              controller: _abas,
              labelColor: AppColors.verde,
              unselectedLabelColor: AppColors.textoSuave,
              indicatorColor: AppColors.verde,
              labelStyle:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Contato'),
                Tab(text: 'Orientacoes'),
                Tab(text: 'Agenda'),
              ],
            ),
          ),
          Expanded(
            child: _carregando
                ? const CarregandoView()
                : _erro != null
                    ? ErroView(mensagem: _erro!, aoTentar: _carregar)
                    : TabBarView(
                        controller: _abas,
                        children: [
                          _abaContato(),
                          _abaOrientacoes(),
                          _abaAgenda(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _abaContato() {
    final nutri = _nutricionista;
    if (nutri == null) {
      return const Center(
        child: Text(
          'Nenhum nutricionista vinculado.\nRefaca o onboarding para escolher um.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
        ),
      );
    }

    final escuro = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        MvnCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: escuro
                    ? const Color(0xFF21262D)
                    : AppColors.paletaLilasSuave,
                child: Icon(Icons.medical_services,
                    size: 34,
                    color: escuro
                        ? AppColors.paletaLilasSuave
                        : AppColors.paletaRoxo),
              ),
              const SizedBox(height: 12),
              Text(
                nutri.nome,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: escuro ? AppColors.paletaClaro : AppColors.texto,
                ),
              ),
              const SizedBox(height: 4),
              if (nutri.crn != null)
                Text(
                  nutri.crn!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: escuro
                        ? AppColors.paletaLilasSuave
                        : AppColors.paletaRoxo,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (nutri.especializacao != null) ...[
                const SizedBox(height: 2),
                Text(
                  nutri.especializacao!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: escuro
                        ? AppColors.fonteSubtituloClaro
                        : AppColors.textoSuave,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.espacoEntreCards),
        Row(
          children: [
            Expanded(
              child: _BotaoAcao(
                icone: Icons.chat_bubble_outline_rounded,
                rotulo: 'Chat',
                aoTocar: _abrirChat,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BotaoAcao(
                icone: Icons.videocam_outlined,
                rotulo: 'Videochamada',
                aoTocar: () => _mostrarVideochamada(nutri),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tela de videochamada simulada (4.5.17 do prototipo).
  void _mostrarVideochamada(Contato nutri) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VideochamadaScreen(nomeContato: nutri.nome),
      ),
    );
  }

  Widget _abaOrientacoes() {
    if (_orientacoes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma orientação recebida ainda.',
          style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        for (final orientacao in _orientacoes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MvnCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconeCategoria(categoria: orientacao.categoria),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          switch (orientacao.categoria) {
                            'positivo' => 'Feedback Positivo',
                            'melhoria' => 'Ponto de Melhoria',
                            _ => 'Orientação Clínica',
                          },
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.texto,
                          ),
                        ),
                      ),
                      Text(
                        '${orientacao.criadoEm.day.toString().padLeft(2, '0')}/'
                        '${orientacao.criadoEm.month.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textoFraco),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    orientacao.texto,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textoSuave,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (orientacao.confirmada)
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 16, color: AppColors.verde),
                            const SizedBox(width: 6),
                            Text(
                              'Orientação confirmada',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.verdeEscuro,
                              ),
                            ),
                          ],
                        )
                      else
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: AppColors.laranja),
                            SizedBox(width: 6),
                            Text(
                              'Aguardando sua confirmação',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.laranja,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      if (!orientacao.confirmada)
                        ElevatedButton.icon(
                          onPressed: () => _confirmarOrientacao(orientacao),
                          icon: const Icon(Icons.check_rounded, size: 15),
                          label: const Text('Confirmar / Ciente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.paletaVerde,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
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

  Future<void> _confirmarOrientacao(Orientacao orientacao) async {
    try {
      await widget.cardapioService.confirmarOrientacao(orientacao.idOrientacao);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Orientação confirmada! Obrigado pelo feedback.'),
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

  Widget _abaAgenda() {
    final agora = DateTime.now();

    // Horários disponíveis abertos pelo nutricionista
    final disponiveis = _consultas
        .where((c) => c.status == 'disponivel' && c.dataHora.isAfter(agora))
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

    // Consultas do paciente (solicitadas pendentes ou já confirmadas)
    final minhasAgendadas = _consultas
        .where((c) =>
            (c.status == 'confirmada' || c.status == 'pendente') &&
            c.dataHora.isAfter(agora))
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

    // Histórico de consultas passadas ou concluídas
    final historico = _consultas
        .where((c) =>
            c.status == 'concluida' ||
            c.status == 'cancelada' ||
            c.status == 'recusada' ||
            (!c.dataHora.isAfter(agora) && c.status != 'disponivel'))
        .toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    return ListView(
      padding: const EdgeInsets.all(AppSizes.telaPadding),
      children: [
        // -------------------------------------------------------------
        // Seção 1: Horários Disponíveis para Agendamento
        // -------------------------------------------------------------
        Row(
          children: [
            const Icon(Icons.event_available_rounded,
                size: 18, color: AppColors.paletaVerde),
            const SizedBox(width: 8),
            Text(
              'Horários Disponíveis do Nutricionista (${disponiveis.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Escolha um horário abaixo e solicite o agendamento:',
          style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
        ),
        const SizedBox(height: 10),

        if (disponiveis.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF21262D)
                  : AppColors.cinzaSegmento,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.textoSuave),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nenhum horário livre no momento. Peça novas datas pelo chat!',
                    style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
                  ),
                ),
              ],
            ),
          )
        else
          ...disponiveis.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MvnCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.paletaVerdeSuave,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_today_rounded,
                          size: 18, color: AppColors.paletaVerde),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.diaSemanaExtenso} às ${c.horaFormatada}',
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
                              color: AppColors.textoSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _solicitarConsulta(c),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.paletaVerde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Solicitar',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 20),

        // -------------------------------------------------------------
        // Seção 2: Minhas Consultas Agendadas e Pedidos
        // -------------------------------------------------------------
        Row(
          children: [
            const Icon(Icons.assignment_turned_in_rounded,
                size: 18, color: AppColors.paletaRoxo),
            const SizedBox(width: 8),
            Text(
              'Minhas Consultas Agendadas (${minhasAgendadas.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (minhasAgendadas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Você não tem nenhuma consulta agendada no momento.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textoSuave),
            ),
          )
        else
          ...minhasAgendadas.map((c) {
            final pendente = c.status == 'pendente';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MvnCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: pendente
                            ? const Color(0xFFFFFBEB)
                            : AppColors.paletaVerdeSuave,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        pendente
                            ? Icons.pending_actions_rounded
                            : Icons.check_circle_outline_rounded,
                        color: pendente
                            ? const Color(0xFFD97706)
                            : AppColors.verde,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.diaSemanaExtenso} às ${c.horaFormatada}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.dataCompletaExtenso,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textoSuave,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: pendente
                                  ? const Color(0xFFFEF3C7)
                                  : AppColors.paletaVerdeSuave,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pendente
                                  ? 'Aguardando confirmação do nutricionista'
                                  : 'Consulta confirmada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: pendente
                                    ? const Color(0xFF92400E)
                                    : AppColors.verdeEscuro,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

        // -------------------------------------------------------------
        // Seção 3: Histórico de Consultas
        // -------------------------------------------------------------
        if (historico.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 18, color: AppColors.textoFraco),
              const SizedBox(width: 8),
              Text(
                'Histórico Anterior (${historico.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...historico.map((c) {
            final concluida = c.status == 'concluida';
            final recusada = c.status == 'recusada';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: MvnCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      concluida
                          ? Icons.check_circle_outline
                          : (recusada
                              ? Icons.highlight_off_rounded
                              : Icons.cancel_outlined),
                      size: 18,
                      color: concluida
                          ? AppColors.paletaVerde
                          : (recusada
                              ? const Color(0xFFD97706)
                              : AppColors.vermelho),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${c.diaSemanaExtenso} • ${c.dataCompletaExtenso}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    Text(
                      concluida
                          ? 'Concluída'
                          : (recusada ? 'Recusada' : 'Cancelada'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: concluida
                            ? AppColors.paletaVerde
                            : (recusada
                                ? const Color(0xFFD97706)
                                : AppColors.vermelho),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _solicitarConsulta(Consulta consulta) async {
    try {
      await widget.cardapioService.solicitarConsulta(consulta.idConsulta);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solicitação enviada para ${consulta.diaSemanaExtenso} às ${consulta.horaFormatada}! O nutricionista foi notificado.',
          ),
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

class _BotaoAcao extends StatelessWidget {
  const _BotaoAcao({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: escuro ? AppColors.paletaEscuroCard : Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      elevation: escuro ? 0 : 1,
      shadowColor: const Color(0x1A000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                icone,
                color: escuro
                    ? AppColors.paletaLilasSuave
                    : AppColors.paletaRoxo,
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                rotulo,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: escuro ? AppColors.paletaClaro : AppColors.texto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconeCategoria extends StatelessWidget {
  const _IconeCategoria({required this.categoria});

  final String categoria;

  @override
  Widget build(BuildContext context) {
    final (icone, cor) = switch (categoria) {
      'positivo' => (Icons.thumb_up_alt_rounded, AppColors.verde),
      'melhoria' => (Icons.tips_and_updates_outlined, AppColors.laranja),
      _ => (Icons.info_outline_rounded, AppColors.roxoGrafico),
    };

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icone, size: 16, color: cor),
    );
  }
}

/// Interface simulada de videochamada (tela 4.5.17 do prototipo).
class _VideochamadaScreen extends StatefulWidget {
  const _VideochamadaScreen({required this.nomeContato});

  final String nomeContato;

  @override
  State<_VideochamadaScreen> createState() => _VideochamadaScreenState();
}

class _VideochamadaScreenState extends State<_VideochamadaScreen> {
  bool _microfoneAtivo = true;
  bool _cameraAtiva = true;
  final DateTime _inicio = DateTime.now();
  Timer? _cronometro;

  @override
  void initState() {
    super.initState();
    // Sem este timer o cronometro ficaria parado em 00:00, avancando so
    // quando outro setState acontecesse (mic/camera).
    _cronometro = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _cronometro?.cancel();
    super.dispose();
  }

  String get _duracao {
    final segundos = DateTime.now().difference(_inicio).inSeconds;
    final min = (segundos ~/ 60).toString().padLeft(2, '0');
    final seg = (segundos % 60).toString().padLeft(2, '0');
    return '$min:$seg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paletaEscuro,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Consulta com ${widget.nomeContato}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  Text(
                    _duracao,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.paletaRoxo,
                        child:
                            Icon(Icons.person, size: 44, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.nomeContato,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _cameraAtiva ? 'Camera ativa' : 'Camera desligada',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BotaoControle(
                    icone: _microfoneAtivo
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                    ativo: _microfoneAtivo,
                    aoTocar: () =>
                        setState(() => _microfoneAtivo = !_microfoneAtivo),
                  ),
                  const SizedBox(width: 20),
                  _BotaoControle(
                    icone:
                        _cameraAtiva ? Icons.videocam : Icons.videocam_off,
                    ativo: _cameraAtiva,
                    aoTocar: () =>
                        setState(() => _cameraAtiva = !_cameraAtiva),
                  ),
                  const SizedBox(width: 20),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      color: AppColors.vermelho,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.call_end_rounded,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoControle extends StatelessWidget {
  const _BotaoControle({
    required this.icone,
    required this.ativo,
    required this.aoTocar,
  });

  final IconData icone;
  final bool ativo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: ativo
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.vermelho.withValues(alpha: 0.8),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icone, color: Colors.white, size: 24),
        onPressed: aoTocar,
      ),
    );
  }
}
