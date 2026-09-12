/// Tokens de design extraidos do prototipo Figma.
///
/// As cores foram amostradas pixel a pixel das telas do prototipo,
/// por isso os valores sao exatos e nao aproximados. Centralizar tudo
/// aqui garante que as tres telas compartilhem a mesma identidade
/// visual e que qualquer ajuste seja feito num unico lugar.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ===== Cores Oficiais da Paleta (Paleta do projeto.pdf) =====
  /// Verde destaque da marca (5ed360ff)
  static const Color paletaVerde = Color(0xFF5ED360);

  /// Fundo verde suave (dcf8dcff)
  static const Color paletaVerdeSuave = Color(0xFFDCF8DC);

  /// Roxo primario da marca (43164fff)
  static const Color paletaRoxo = Color(0xFF43164F);

  /// Lilas fundo suave (e9d3efff)
  static const Color paletaLilasSuave = Color(0xFFE9D3EF);

  /// Fundo escuro (0d1117ff)
  static const Color paletaEscuro = Color(0xFF0D1117);

  /// Fundo claro / quase branco (f0f0f0ff)
  static const Color paletaClaro = Color(0xFFF0F0F0);

  /// Fontes: Texto principal escuro (101828ff)
  static const Color fonteTitulo = Color(0xFF101828);

  /// Fontes: Texto secundario / rotulos (444c65ff)
  static const Color fonteSubtitulo = Color(0xFF444C65);

  /// Fontes: Texto neutro / placeholders (848486ff)
  static const Color fontePlaceholder = Color(0xFF848486);

  /// Bordas e divisores 1 (c6ccdaff)
  static const Color bordaClara = Color(0xFFC6CCDA);

  /// Bordas e divisores 2 (c3c3c3ff)
  static const Color bordaCinza = Color(0xFFC3C3C3);

  // ----- Verdes (cabecalho de Progresso, elementos ativos) -----------
  /// Verde inicial do gradiente do cabecalho.
  static const Color verde = Color(0xFF00C950);

  /// Verde final do gradiente do cabecalho (lado direito).
  static const Color verdeEscuro = Color(0xFF00A73E);

  /// Verde de preenchimento da barra de progresso.
  static const Color verdeBarra = Color(0xFF00C14C);

  // ----- Roxos (botao "Registrar Peso", graficos, baloes) ------------
  /// Roxo inicial do gradiente do botao principal.
  static const Color roxo = Color(0xFFAC45FF);

  /// Roxo final do gradiente do botao principal.
  static const Color roxoEscuro = Color(0xFF9916FB);

  /// Roxo das barras "Consumido" e das barras de macronutrientes.
  static const Color roxoGrafico = Color(0xFF8B5CF6);

  // ----- Gradiente do Chat (verde -> roxo) ---------------------------
  static const Color chatGradienteInicio = Color(0xFF00C55A);
  static const Color chatGradienteFim = Color(0xFF9722F8);

  // ----- Neutros -----------------------------------------------------
  /// Fundo geral das telas.
  static const Color fundo = Color(0xFFF9FAFB);

  /// Fundo dos cartoes brancos.
  static const Color branco = Color(0xFFFFFFFF);

  /// Fundo do segmento inativo (Semanal/Mensal).
  static const Color cinzaSegmento = Color(0xFFF3F4F6);

  /// Trilha vazia da barra de progresso e das barras "Meta".
  static const Color cinzaTrilha = Color(0xFFE5E7EB);

  /// Cinza das barras "Meta" no grafico de consumo.
  static const Color cinzaMeta = Color(0xFFD1D5DB);

  /// Texto principal.
  static const Color texto = Color(0xFF111827);

  /// Texto secundario / legendas.
  static const Color textoSuave = Color(0xFF6B7280);

  /// Texto terciario (datas no historico).
  static const Color textoFraco = Color(0xFF9CA3AF);

  /// Vermelho do botao de remover no historico.
  static const Color vermelho = Color(0xFFEF4444);

  /// Laranja usado no rotulo de carboidratos.
  static const Color laranja = Color(0xFFF59E0B);

  /// Borda suave de cartoes e campos.
  static const Color borda = Color(0xFFE5E7EB);

  // ----- Gradientes reutilizaveis ------------------------------------
  /// Gradiente oficial dos botoes de autenticacao (Login e Cadastro: roxo escuro -> verde destaque).
  static const LinearGradient gradienteAuth = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [paletaRoxo, paletaVerde],
  );

  /// Cabecalho da tela de Progresso/Evolucao.
  static const LinearGradient gradienteVerde = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [verde, verdeEscuro],
  );

  /// Botao "+ REGISTRAR PESO".
  static const LinearGradient gradienteRoxo = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [roxo, roxoEscuro],
  );

  /// Cabecalho do Chat, balao enviado e botao de enviar.
  static const LinearGradient gradienteChat = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [chatGradienteInicio, chatGradienteFim],
  );
  // ----- Paleta Escura (Dark Mode) -----------------------------------
  /// Superficie dos cartoes no modo escuro (#161B22)
  static const Color paletaEscuroCard = Color(0xFF161B22);

  /// Borda de cartoes e divisores no modo escuro (#30363D)
  static const Color bordaEscura = Color(0xFF30363D);

  /// Texto secundario claro para modo escuro (#C6CCDA)
  static const Color fonteSubtituloClaro = Color(0xFFC6CCDA);
}

/// Espacamentos e raios de canto observados no prototipo.
class AppSizes {
  AppSizes._();

  static const double telaPadding = 16.0;
  static const double cardRadius = 16.0;
  static const double cardPadding = 16.0;
  static const double espacoEntreCards = 12.0;
  static const double botaoRadius = 12.0;
  static const double botaoAltura = 48.0;
  static const double segmentoRadius = 10.0;
  static const double segmentoAltura = 40.0;
  static const double baloesRadius = 16.0;
  static const double alturaCabecalho = 64.0;
  static const double alturaNavegacao = 62.0;
}

/// Sombra discreta dos cartoes brancos.
const List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

/// Tema global do aplicativo (Claro e Escuro).
class AppTheme {
  AppTheme._();

  /// Tema Claro padrao (baseado nas cores oficiais).
  static ThemeData get temaClaro {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fundo,
      cardColor: AppColors.branco,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.paletaVerde,
        secondary: AppColors.paletaRoxo,
        surface: AppColors.branco,
        onSurface: AppColors.fonteTitulo,
        error: AppColors.vermelho,
        surfaceContainerHighest: AppColors.paletaVerdeSuave,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.fonteTitulo,
        displayColor: AppColors.fonteTitulo,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paletaRoxo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.branco,
        selectedItemColor: AppColors.paletaVerde,
        unselectedItemColor: AppColors.textoFraco,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.branco,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.paletaVerde,
        unselectedLabelColor: AppColors.textoSuave,
        indicatorColor: AppColors.paletaVerde,
      ),
      dividerColor: AppColors.borda,
      splashFactory: InkRipple.splashFactory,
    );
  }

  /// Tema Escuro profissional (baseado no #0D1117 da paleta oficial).
  static ThemeData get temaEscuro {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paletaEscuro,
      cardColor: AppColors.paletaEscuroCard,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.paletaVerde,
        secondary: AppColors.paletaLilasSuave,
        surface: AppColors.paletaEscuroCard,
        onSurface: AppColors.paletaClaro,
        error: AppColors.vermelho,
        surfaceContainerHighest: const Color(0xFF21262D),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.paletaClaro,
        displayColor: AppColors.paletaClaro,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paletaEscuroCard,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.paletaEscuroCard,
        selectedItemColor: AppColors.paletaVerde,
        unselectedItemColor: AppColors.fonteSubtituloClaro,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paletaEscuroCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: const BorderSide(color: AppColors.bordaEscura),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.paletaVerde,
        unselectedLabelColor: AppColors.fonteSubtituloClaro,
        indicatorColor: AppColors.paletaVerde,
      ),
      dividerColor: AppColors.bordaEscura,
      splashFactory: InkRipple.splashFactory,
    );
  }

  /// Alias de compatibilidade.
  static ThemeData get tema => temaClaro;
}
