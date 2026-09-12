/// Tela de Aparencia e Acessibilidade do Aplicativo.
///
/// Permite alterar entre Modo Claro e Modo Escuro (utilizando as cores oficiais
/// da paleta do projeto em `frontend/lib/assets/Paleta do projeto.pdf`) e
/// ajustar a escala de tamanho da fonte para melhor leitura.
///
/// Relacionamento:
/// - Acessada a partir da [ConfiguracoesScreen] via botao "Aparência e Acessibilidade".
/// - Notifica [AppSettings.instance], alterando o visual de todas as telas em tempo real.
library;

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AparenciaAcessibilidadeScreen extends StatefulWidget {
  const AparenciaAcessibilidadeScreen({super.key});

  @override
  State<AparenciaAcessibilidadeScreen> createState() =>
      _AparenciaAcessibilidadeScreenState();
}

class _AparenciaAcessibilidadeScreenState
    extends State<AparenciaAcessibilidadeScreen> {
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final settings = AppSettings.instance;

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Aparência e Acessibilidade'),
        backgroundColor:
            escuro ? AppColors.paletaEscuroCard : AppColors.paletaRoxo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.telaPadding),
        children: [
          // Banner informativo
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
                    color: AppColors.paletaVerde,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.palette_outlined,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Escolha o tema que melhor combina com seu uso diário e ajuste o tamanho do texto para maior conforto visual.',
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
          const SizedBox(height: 20),

          // Secao de Tema
          _tituloSecao('Tema do Aplicativo'),
          const SizedBox(height: 8),

          Row(
            children: [
              // Card Modo Claro
              Expanded(
                child: _cardTema(
                  titulo: 'Claro',
                  modo: ThemeMode.light,
                  modoAtual: settings.themeMode,
                  corFundo: AppColors.paletaClaro,
                  corDestaque: AppColors.paletaRoxo,
                  corTexto: AppColors.fonteTitulo,
                  icone: Icons.light_mode_rounded,
                  aoSelecionar: () => settings.definirModoTema(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 10),
              // Card Modo Escuro
              Expanded(
                child: _cardTema(
                  titulo: 'Escuro',
                  modo: ThemeMode.dark,
                  modoAtual: settings.themeMode,
                  corFundo: AppColors.paletaEscuro,
                  corDestaque: AppColors.paletaVerde,
                  corTexto: AppColors.paletaClaro,
                  icone: Icons.dark_mode_rounded,
                  aoSelecionar: () => settings.definirModoTema(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 10),
              // Card Sistema
              Expanded(
                child: _cardTema(
                  titulo: 'Sistema',
                  modo: ThemeMode.system,
                  modoAtual: settings.themeMode,
                  corFundo: escuro
                      ? AppColors.paletaEscuroCard
                      : AppColors.paletaVerdeSuave,
                  corDestaque: AppColors.paletaVerde,
                  corTexto: escuro
                      ? AppColors.fonteSubtituloClaro
                      : AppColors.fonteSubtitulo,
                  icone: Icons.settings_brightness_rounded,
                  aoSelecionar: () => settings.definirModoTema(ThemeMode.system),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Secao de Tamanho da Fonte
          _tituloSecao('Tamanho do Texto e Legibilidade'),
          const SizedBox(height: 8),

          MvnCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_size_rounded,
                        size: 20, color: AppColors.paletaVerde),
                    const SizedBox(width: 8),
                    const Text(
                      'Escala de Leitura',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.paletaVerde.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _rotuloEscala(settings.textScaleFactor),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.verdeEscuro,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Seletor de 3 botoes de escala
                Row(
                  children: [
                    _botaoEscala(
                      rotulo: 'Pequena',
                      escala: 0.9,
                      escalaAtual: settings.textScaleFactor,
                      aoSelecionar: () => settings.definirEscalaFonte(0.9),
                    ),
                    const SizedBox(width: 8),
                    _botaoEscala(
                      rotulo: 'Padrão',
                      escala: 1.0,
                      escalaAtual: settings.textScaleFactor,
                      aoSelecionar: () => settings.definirEscalaFonte(1.0),
                    ),
                    const SizedBox(width: 8),
                    _botaoEscala(
                      rotulo: 'Grande',
                      escala: 1.15,
                      escalaAtual: settings.textScaleFactor,
                      aoSelecionar: () => settings.definirEscalaFonte(1.15),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Caixa de demonstracao / preview de texto
                Text(
                  'Pré-visualização do Texto:',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: escuro
                        ? AppColors.fonteSubtituloClaro
                        : AppColors.fonteSubtitulo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: escuro
                        ? const Color(0xFF0D1117)
                        : AppColors.fundo,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: escuro
                          ? AppColors.bordaEscura
                          : AppColors.borda,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meu Virtual Nutri — Alimentação Saudável',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Este é um exemplo de como os textos e planos alimentares serão exibidos no seu aplicativo.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: escuro
                              ? AppColors.fonteSubtituloClaro
                              : AppColors.fonteSubtitulo,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _rotuloEscala(double escala) {
    if (escala <= 0.95) return '90% (Pequena)';
    if (escala >= 1.1) return '115% (Grande)';
    return '100% (Padrão)';
  }

  Widget _tituloSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
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

  Widget _cardTema({
    required String titulo,
    required ThemeMode modo,
    required ThemeMode modoAtual,
    required Color corFundo,
    required Color corDestaque,
    required Color corTexto,
    required IconData icone,
    required VoidCallback aoSelecionar,
  }) {
    final ativo = modo == modoAtual;

    return InkWell(
      onTap: aoSelecionar,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: corFundo,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: Border.all(
            color: ativo ? AppColors.paletaVerde : Colors.transparent,
            width: ativo ? 2.5 : 1,
          ),
          boxShadow: ativo
              ? [
                  BoxShadow(
                    color: AppColors.paletaVerde.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : kCardShadow,
        ),
        child: Column(
          children: [
            Icon(icone, size: 28, color: corDestaque),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: ativo ? FontWeight.bold : FontWeight.w600,
                color: corTexto,
              ),
            ),
            const SizedBox(height: 4),
            if (ativo)
              const Icon(Icons.check_circle,
                  size: 16, color: AppColors.paletaVerde)
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _botaoEscala({
    required String rotulo,
    required double escala,
    required double escalaAtual,
    required VoidCallback aoSelecionar,
  }) {
    final ativo = (escalaAtual - escala).abs() < 0.05;

    return Expanded(
      child: InkWell(
        onTap: aoSelecionar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ativo
                ? AppColors.paletaVerde
                : AppColors.cinzaSegmento,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            rotulo,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: ativo ? FontWeight.bold : FontWeight.w500,
              color: ativo ? Colors.white : AppColors.fonteTitulo,
            ),
          ),
        ),
      ),
    );
  }
}
