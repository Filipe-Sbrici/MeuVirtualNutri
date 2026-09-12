/// Widgets compartilhados pelas tres telas.
library;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Cabecalho com gradiente, usado nas telas de Progresso e Evolucao.
///
/// Reproduz o cabecalho verde do prototipo: icone em quadrado
/// translucido + titulo em negrito, sobre gradiente horizontal.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.titulo,
    required this.icone,
    this.gradiente = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [AppColors.paletaRoxo, Color(0xFF6B21A8)],
    ),
    this.subtitulo,
    this.aoVoltar,
    this.acoes,
  });

  final String titulo;
  final IconData icone;
  final Gradient gradiente;
  final String? subtitulo;

  /// Quando informado, exibe o botao circular de voltar (como no Chat).
  final VoidCallback? aoVoltar;

  final List<Widget>? acoes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradiente),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: AppSizes.alturaCabecalho,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (aoVoltar != null)
                _BotaoCircular(icone: Icons.chevron_left, aoTocar: aoVoltar!)
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    // Branco translucido sobre o gradiente, como no prototipo.
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, color: Colors.white, size: 20),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (acoes != null) ...acoes!,
            ],
          ),
        ),
      ),
    );
  }
}

class _BotaoCircular extends StatelessWidget {
  const _BotaoCircular({required this.icone, required this.aoTocar});

  final IconData icone;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: aoTocar,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icone, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Cartao arredondado usado em todos os blocos de conteudo (adaptavel ao tema claro/escuro).
class MvnCard extends StatelessWidget {
  const MvnCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.cardPadding),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: escuro ? AppColors.paletaEscuroCard : AppColors.branco,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: escuro ? Border.all(color: AppColors.bordaEscura, width: 1) : null,
        boxShadow: escuro ? null : kCardShadow,
      ),
      child: child,
    );
  }
}

/// Titulo de cartao com emoji/icone a esquerda ("Historico de Peso").
class TituloCard extends StatelessWidget {
  const TituloCard({super.key, required this.texto, required this.emoji});

  final String texto;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 17)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: escuro ? AppColors.paletaClaro : AppColors.texto,
            ),
          ),
        ),
      ],
    );
  }
}

/// Botao com gradiente ("+ REGISTRAR PESO").
class BotaoGradiente extends StatelessWidget {
  const BotaoGradiente({
    super.key,
    required this.texto,
    required this.aoTocar,
    this.icone,
    this.gradiente = AppColors.gradienteVerde,
    this.carregando = false,
  });

  final String texto;
  final VoidCallback? aoTocar;
  final IconData? icone;
  final Gradient gradiente;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final habilitado = aoTocar != null && !carregando;
    final grad = escuro ? AppColors.gradienteVerde : gradiente;

    return Opacity(
      opacity: habilitado ? 1 : 0.6,
      child: Container(
        height: AppSizes.botaoAltura,
        decoration: BoxDecoration(
          gradient: grad,
          borderRadius: BorderRadius.circular(AppSizes.botaoRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.paletaVerde.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.botaoRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.botaoRadius),
            onTap: habilitado ? aoTocar : null,
            child: Center(
              child: carregando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icone != null) ...[
                          Icon(icone, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          texto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
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

/// Estado de carregamento centralizado.
class CarregandoView extends StatelessWidget {
  const CarregandoView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppColors.paletaVerde),
      );
}

/// Estado de erro com botao de nova tentativa.
class ErroView extends StatelessWidget {
  const ErroView({super.key, required this.mensagem, required this.aoTentar});

  final String mensagem;
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 46, color: AppColors.fontePlaceholder),
            const SizedBox(height: 14),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.fonteSubtitulo, fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: aoTentar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tentar novamente'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.paletaVerde,
                side: const BorderSide(color: AppColors.paletaVerde),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
