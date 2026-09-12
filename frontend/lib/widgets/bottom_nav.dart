/// Barra de navegacao inferior do prototipo.
///
/// Cinco itens: Inicio, Cardapio, Meu Nutri, Progresso, Perfil.
/// O item ativo aparece em verde; os demais em cinza.
///
/// Somente Progresso e Chat existem nesta entrega; os demais itens sao
/// exibidos para manter a fidelidade visual e informam que a tela ainda
/// nao faz parte do escopo quando tocados.
library;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Abas da barra inferior.
enum AbaNavegacao { inicio, cardapio, meuNutri, progresso, perfil }

class ItemNavegacao {
  const ItemNavegacao(this.aba, this.rotulo, this.icone);

  final AbaNavegacao aba;
  final String rotulo;
  final IconData icone;
}

const List<ItemNavegacao> kItensNavegacao = [
  ItemNavegacao(AbaNavegacao.inicio, 'Início', Icons.home_outlined),
  ItemNavegacao(AbaNavegacao.cardapio, 'Cardápio', Icons.calendar_today_outlined),
  ItemNavegacao(AbaNavegacao.meuNutri, 'Meu Nutri', Icons.person_outline),
  ItemNavegacao(AbaNavegacao.progresso, 'Progresso', Icons.trending_up),
  ItemNavegacao(AbaNavegacao.perfil, 'Config', Icons.settings_outlined),
];

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.abaAtiva,
    this.aoSelecionar,
  });

  final AbaNavegacao abaAtiva;

  /// Recebe a aba tocada. Quando nulo, a barra fica apenas decorativa.
  final ValueChanged<AbaNavegacao>? aoSelecionar;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: escuro ? AppColors.paletaEscuroCard : AppColors.branco,
        border: Border(
          top: BorderSide(
            color: escuro ? AppColors.bordaEscura : AppColors.borda,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.alturaNavegacao,
          child: Row(
            children: kItensNavegacao.map((item) {
              final ativo = item.aba == abaAtiva;
              final cor = ativo
                  ? AppColors.paletaVerde
                  : (escuro
                      ? AppColors.fonteSubtituloClaro
                      : AppColors.fontePlaceholder);

              return Expanded(
                child: InkWell(
                  onTap: aoSelecionar == null
                      ? null
                      : () => aoSelecionar!(item.aba),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icone, size: 22, color: cor),
                      const SizedBox(height: 3),
                      Text(
                        item.rotulo,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: cor,
                          fontWeight:
                              ativo ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
