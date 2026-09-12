/// Tela de Preferencias de Notificacoes.
///
/// Permite ao usuario (Nutricionista ou Paciente) personalizar quais alertas
/// e lembretes deseja receber no aplicativo (mensagens de chat, consultas,
/// metas de agua/alimentacao e solicitacoes de atendimento).
///
/// Relacionamento:
/// - Acessada a partir da [ConfiguracoesScreen] via botao "Notificacoes".
/// - Altera os estados no [AppSettings.instance] em tempo de execucao.
library;

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class NotificacoesConfigScreen extends StatefulWidget {
  const NotificacoesConfigScreen({super.key});

  @override
  State<NotificacoesConfigScreen> createState() =>
      _NotificacoesConfigScreenState();
}

class _NotificacoesConfigScreenState extends State<NotificacoesConfigScreen> {
  late bool _chat;
  late bool _consultas;
  late bool _lembretes;
  late bool _solicitacoes;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.instance;
    _chat = s.notificacoesChat;
    _consultas = s.notificacoesConsultas;
    _lembretes = s.notificacoesLembretes;
    _solicitacoes = s.notificacoesSolicitacoes;
  }

  void _atualizar(String tipo, bool valor) {
    setState(() {
      switch (tipo) {
        case 'chat':
          _chat = valor;
          break;
        case 'consultas':
          _consultas = valor;
          break;
        case 'lembretes':
          _lembretes = valor;
          break;
        case 'solicitacoes':
          _solicitacoes = valor;
          break;
      }
    });
    AppSettings.instance.alternarNotificacao(tipo, valor);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notificações e Alertas'),
        backgroundColor:
            escuro ? AppColors.paletaEscuroCard : AppColors.paletaRoxo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.telaPadding),
        children: [
          // Banner explicativo com cores da marca
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: escuro
                  ? const Color(0xFF21262D)
                  : AppColors.paletaLilasSuave.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              border: Border.all(
                color: escuro
                    ? AppColors.bordaEscura
                    : AppColors.paletaRoxo.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.paletaRoxo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_outlined,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Personalize como e quando você deseja ser notificado sobre atividades importantes no MVN.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: escuro
                          ? AppColors.fonteSubtituloClaro
                          : AppColors.fonteSubtitulo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Secao de Comunicacao e Mensagens
          _tituloSecao('Comunicação e Atendimento'),
          _itemSwitch(
            icone: Icons.chat_bubble_outline_rounded,
            titulo: 'Mensagens do Chat',
            subtitulo:
                'Alertas em tempo real quando receber novas mensagens de pacientes ou do nutricionista.',
            valor: _chat,
            onChanged: (v) => _atualizar('chat', v),
            escuro: escuro,
          ),
          const SizedBox(height: 10),
          _itemSwitch(
            icone: Icons.person_add_outlined,
            titulo: 'Solicitações de Atendimento',
            subtitulo:
                'Avisos sobre novos pedidos de vínculo e respostas a solicitações.',
            valor: _solicitacoes,
            onChanged: (v) => _atualizar('solicitacoes', v),
            escuro: escuro,
          ),

          const SizedBox(height: 20),

          // Secao de Agenda e Lembretes Diarios
          _tituloSecao('Agenda e Hábitos Saudáveis'),
          _itemSwitch(
            icone: Icons.calendar_month_outlined,
            titulo: 'Lembretes de Consultas',
            subtitulo:
                'Avisos com 1h e 24h de antecedência para consultas agendadas e confirmadas.',
            valor: _consultas,
            onChanged: (v) => _atualizar('consultas', v),
            escuro: escuro,
          ),
          const SizedBox(height: 10),
          _itemSwitch(
            icone: Icons.water_drop_outlined,
            titulo: 'Lembretes de Água e Refeições',
            subtitulo:
                'Incentivos periódicos para registrar a hidratação diária e marcar refeições no checklist.',
            valor: _lembretes,
            onChanged: (v) => _atualizar('lembretes', v),
            escuro: escuro,
          ),

          const SizedBox(height: 24),

          // Botao de restaurar padroes
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Restaurar padrão'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.paletaVerde,
              ),
              onPressed: () {
                _atualizar('chat', true);
                _atualizar('consultas', true);
                _atualizar('lembretes', true);
                _atualizar('solicitacoes', true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notificações restauradas para o padrão.'),
                    backgroundColor: AppColors.verdeEscuro,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.paletaVerde,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _itemSwitch({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool> onChanged,
    required bool escuro,
  }) {
    return MvnCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: valor
                  ? AppColors.paletaVerde.withValues(alpha: 0.15)
                  : (escuro ? const Color(0xFF21262D) : AppColors.fundo),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icone,
              size: 22,
              color: valor ? AppColors.paletaVerde : AppColors.textoFraco,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: escuro
                        ? AppColors.fonteSubtituloClaro
                        : AppColors.fonteSubtitulo,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: valor,
            activeThumbColor: AppColors.paletaVerde,
            activeTrackColor: AppColors.paletaVerde.withValues(alpha: 0.5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
