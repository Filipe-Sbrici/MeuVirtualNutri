/// Bem-Estar do dia (aba descrita na tela 4.5.12 do prototipo).
///
/// Controle de hidratacao diaria com registro de copos de agua,
/// termometro emocional para registro do humor, banner de mensagens
/// nao lidas do nutricionista e atalhos para lista de compras e
/// minhas receitas.
library;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';

class BemEstarScreen extends StatefulWidget {
  const BemEstarScreen({
    super.key,
    required this.coposAgua,
    required this.naoLidas,
    required this.aoRegistrarAgua,
    required this.aoRegistrarHumor,
    required this.aoAbrirChat,
    required this.aoAbrirListaCompras,
    required this.aoAbrirMinhasReceitas,
    this.humorInicial,
    this.aoVoltar,
  });

  final int coposAgua;
  final int naoLidas;

  /// Humor ja registrado hoje ('otimo'|'bom'|'regular'|'ruim').
  final String? humorInicial;

  /// Recebe o TOTAL de copos do dia (nao o incremento).
  final Future<void> Function(int copos) aoRegistrarAgua;
  final Future<void> Function(String humor) aoRegistrarHumor;
  final VoidCallback aoAbrirChat;
  final VoidCallback aoAbrirListaCompras;
  final VoidCallback aoAbrirMinhasReceitas;
  final VoidCallback? aoVoltar;

  @override
  State<BemEstarScreen> createState() => _BemEstarScreenState();
}

class _BemEstarScreenState extends State<BemEstarScreen> {
  late int _copos;
  String? _humor;

  static const int _metaCopos = 8;

  static const _humores = [
    ('otimo', '😄', 'Otimo'),
    ('bom', '🙂', 'Bom'),
    ('regular', '😐', 'Regular'),
    ('ruim', '😞', 'Ruim'),
  ];

  @override
  void initState() {
    super.initState();
    _copos = widget.coposAgua;
    _humor = widget.humorInicial;
  }

  Future<void> _contarCopo() async {
    final novo = (_copos + 1).clamp(0, _metaCopos + 4);
    setState(() => _copos = novo);
    await widget.aoRegistrarAgua(novo);
  }

  /// A confirmacao (ou o erro) e exibida por quem faz a chamada a API,
  /// para nao mostrar "Humor registrado!" quando o POST falha.
  Future<void> _marcarHumor(String humor) async {
    setState(() => _humor = humor);
    await widget.aoRegistrarHumor(humor);
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Bem-Estar',
            subtitulo: 'Hidratação, humor e utilidades do dia',
            icone: Icons.favorite_rounded,
            aoVoltar: widget.aoVoltar ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.telaPadding),
              children: [
                // Banner de mensagens nao lidas (tela 4.5.12).
                if (widget.naoLidas > 0) ...[
                  Material(
                    color: escuro
                        ? const Color(0xFF21262D)
                        : AppColors.paletaLilasSuave,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.aoAbrirChat,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.mark_chat_unread_rounded,
                              color: escuro
                                  ? AppColors.paletaVerde
                                  : AppColors.paletaRoxo,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Voce tem ${widget.naoLidas} mensagem(ns) '
                                'nao lida(s) do seu nutricionista.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: escuro
                                      ? AppColors.paletaClaro
                                      : AppColors.paletaRoxo,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.paletaRoxo),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.espacoEntreCards),
                ],

                // Hidratacao (contador tatil de copos).
                MvnCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const TituloCard(texto: 'Hidratacao', emoji: '💧'),
                      const SizedBox(height: 12),
                      Text(
                        '$_copos/$_metaCopos copos',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: escuro
                              ? AppColors.paletaLilasSuave
                              : AppColors.paletaRoxo,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (_copos / _metaCopos).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: escuro
                              ? const Color(0xFF21262D)
                              : AppColors.cinzaTrilha,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              escuro ? AppColors.paletaLilasSuave : AppColors.paletaRoxo),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 46,
                        child: Row(
                          children: [
                            for (var i = 0; i < _metaCopos; i++)
                              Expanded(
                                child: GestureDetector(
                                  onTap: _contarCopo,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    child: Icon(
                                      Icons.water_drop_rounded,
                                      size: 26,
                                      color: i < _copos
                                          ? (escuro
                                              ? AppColors.paletaLilasSuave
                                              : AppColors.paletaRoxo)
                                          : (escuro
                                              ? const Color(0xFF30363D)
                                              : AppColors.cinzaTrilha),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _copos == 0
                            ? null
                            : () async {
                                setState(() => _copos = 0);
                                await widget.aoRegistrarAgua(0);
                              },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Zerar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),

                // Termometro emocional.
                MvnCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const TituloCard(
                          texto: 'Como voce esta hoje?', emoji: '🌡️'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _humores
                            .map(
                              (h) => GestureDetector(
                                onTap: () => _marcarHumor(h.$1),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _humor == h.$1
                                            ? (escuro
                                                ? const Color(0xFF21262D)
                                                : AppColors.paletaVerdeSuave)
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        h.$2,
                                        style: const TextStyle(fontSize: 26),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      h.$3,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: _humor == h.$1
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: _humor == h.$1
                                            ? AppColors.paletaVerde
                                            : (escuro
                                                ? AppColors.fonteSubtituloClaro
                                                : AppColors.fonteSubtitulo),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.espacoEntreCards),

                // Atalhos: lista de compras e minhas receitas.
                Row(
                  children: [
                    Expanded(
                      child: _AtalhoBemEstar(
                        icone: Icons.shopping_cart_outlined,
                        rotulo: 'Lista de compras',
                        aoTocar: widget.aoAbrirListaCompras,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AtalhoBemEstar(
                        icone: Icons.menu_book_rounded,
                        rotulo: 'Minhas receitas',
                        aoTocar: widget.aoAbrirMinhasReceitas,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AtalhoBemEstar extends StatelessWidget {
  const _AtalhoBemEstar({
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
      color: escuro ? AppColors.paletaEscuroCard : AppColors.branco,
      borderRadius: BorderRadius.circular(12),
      elevation: escuro ? 0 : 1,
      shadowColor: const Color(0x1A000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(
                icone,
                color: escuro ? AppColors.paletaVerde : AppColors.paletaRoxo,
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                rotulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
