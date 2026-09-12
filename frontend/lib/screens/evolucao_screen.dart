/// Tela de Evolucao (secao de graficos da tela 11 do prototipo).
///
/// Reproduz os tres cartoes, na mesma ordem do prototipo:
///   1. "Evolucao de Peso"             - grafico de linha verde
///   2. "Consumo Calorico Semanal"     - barras Consumido (roxo) x Meta (cinza)
///   3. "Macronutrientes (Media Semanal)" - barras de proteina/carbo/gordura
///
/// O prototipo (React) usa Recharts; aqui o equivalente e o fl_chart.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/evolucao.dart';
import '../services/api_services.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/common.dart';

class EvolucaoScreen extends StatefulWidget {
  const EvolucaoScreen({
    super.key,
    required this.evolucaoService,
    this.uidPaciente,
    this.nomePaciente,
    this.aoSelecionarAba,
    this.aoVoltar,
  });

  final EvolucaoService evolucaoService;

  /// Vazio = paciente logado; preenchido = paciente do nutricionista.
  final String? uidPaciente;
  final String? nomePaciente;
  final ValueChanged<AbaNavegacao>? aoSelecionarAba;
  final VoidCallback? aoVoltar;

  @override
  State<EvolucaoScreen> createState() => _EvolucaoScreenState();
}

class _EvolucaoScreenState extends State<EvolucaoScreen> {
  Evolucao? _evolucao;
  bool _carregando = true;
  String? _erro;
  String _periodo = 'mensal';

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
      final dados = await widget.evolucaoService.carregar(
        uidPaciente: widget.uidPaciente,
        periodo: _periodo,
      );
      if (!mounted) return;
      setState(() {
        _evolucao = dados;
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

  void _trocarPeriodo(String periodo) {
    if (periodo == _periodo) return;
    setState(() => _periodo = periodo);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: widget.nomePaciente != null
                ? 'Evolução - ${widget.nomePaciente}'
                : 'Evolução',
            icone: Icons.insights_rounded,
            aoVoltar: widget.aoVoltar ??
                (Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null),
          ),
          Expanded(child: _corpo()),
        ],
      ),
      // Evolucao pertence ao modulo de Progresso no prototipo. Quando
      // aberta pelo painel do nutricionista, sem barra inferior.
      bottomNavigationBar: widget.aoSelecionarAba == null
          ? null
          : BottomNav(
              abaAtiva: AbaNavegacao.progresso,
              aoSelecionar: widget.aoSelecionarAba,
            ),
    );
  }

  Widget _corpo() {
    if (_carregando) return const CarregandoView();
    if (_erro != null) return ErroView(mensagem: _erro!, aoTentar: _carregar);

    final evolucao = _evolucao!;

    return RefreshIndicator(
      color: AppColors.paletaVerde,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.telaPadding),
        children: [
          _AlternadorPeriodoEvolucao(
            periodo: _periodo,
            aoTrocar: _trocarPeriodo,
          ),
          const SizedBox(height: AppSizes.telaPadding),
          _CartaoEvolucaoPeso(dados: evolucao.evolucaoPeso),
          const SizedBox(height: AppSizes.espacoEntreCards),
          _CartaoConsumoCalorico(dados: evolucao.consumoSemanal),
          const SizedBox(height: AppSizes.espacoEntreCards),
          _CartaoMacronutrientes(dados: evolucao.macronutrientes),
          if (evolucao.nomePlano != null) ...[
            const SizedBox(height: AppSizes.espacoEntreCards),
            Text(
              'Metas do plano: ${evolucao.nomePlano}'
              '${evolucao.metaCalorica != null ? ' - ${evolucao.metaCalorica!.round()} kcal/dia' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.fonteSubtituloClaro
                    : AppColors.fontePlaceholder,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Alternador "Semanal"/"Mensal" (afeta o grafico de peso).
class _AlternadorPeriodoEvolucao extends StatelessWidget {
  const _AlternadorPeriodoEvolucao({
    required this.periodo,
    required this.aoTrocar,
  });

  final String periodo;
  final ValueChanged<String> aoTrocar;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    Widget segmento(String texto, String valor) {
      final ativo = periodo == valor;
      return Expanded(
        child: Material(
          color: ativo
              ? AppColors.paletaVerde
              : (escuro ? const Color(0xFF21262D) : AppColors.cinzaSegmento),
          borderRadius: BorderRadius.circular(AppSizes.segmentoRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.segmentoRadius),
            onTap: () => aoTrocar(valor),
            child: SizedBox(
              height: AppSizes.segmentoAltura,
              child: Center(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ativo
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
      );
    }

    return Row(
      children: [
        segmento('Semanal', 'semanal'),
        const SizedBox(width: 10),
        segmento('Mensal', 'mensal'),
      ],
    );
  }
}

// =====================================================================
//  Cartao 1 - Evolucao de Peso (grafico de linha)
// =====================================================================
class _CartaoEvolucaoPeso extends StatelessWidget {
  const _CartaoEvolucaoPeso({required this.dados});

  final EvolucaoPeso dados;

  @override
  Widget build(BuildContext context) {
    return MvnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TituloCard(texto: 'Evolucao de Peso', emoji: '📉'),
          const SizedBox(height: 16),
          // Uma linha exige ao menos dois pontos para fazer sentido.
          if (dados.pontos.length < 2)
            const _GraficoVazio(
              mensagem: 'Registre pelo menos duas pesagens\n'
                  'para visualizar a evolucao.',
            )
          else
            SizedBox(height: 165, child: _grafico()),
        ],
      ),
    );
  }

  Widget _grafico() {
    final pontos = dados.pontos;

    // Intervalo do eixo Y com folga, evitando linha colada na borda.
    final pesos = pontos.map((p) => p.peso).toList();
    final minimo = dados.minimo ?? (pesos.reduce((a, b) => a < b ? a : b) - 0.5);
    final maximo = dados.maximo ?? (pesos.reduce((a, b) => a > b ? a : b) + 0.5);
    final intervaloY = ((maximo - minimo) / 2).clamp(0.1, double.infinity);

    return LineChart(
      LineChartData(
        minY: minimo,
        maxY: maximo,
        minX: 0,
        maxX: (pontos.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: intervaloY,
          verticalInterval: 1,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.cinzaTrilha,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
          getDrawingVerticalLine: (_) => const FlLine(
            color: AppColors.cinzaTrilha,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: AppColors.cinzaTrilha),
            bottom: BorderSide(color: AppColors.cinzaTrilha),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: intervaloY,
              getTitlesWidget: (valor, meta) => Text(
                valor.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textoFraco,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (valor, meta) {
                final indice = valor.round();
                if (indice < 0 || indice >= pontos.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    pontos[indice].rotulo,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textoFraco,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.texto,
            getTooltipItems: (pontosTocados) => pontosTocados.map((ponto) {
              final registro = pontos[ponto.x.round()];
              return LineTooltipItem(
                '${registro.peso.toStringAsFixed(1)} kg\n${registro.rotulo}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < pontos.length; i++)
                FlSpot(i.toDouble(), pontos[i].peso),
            ],
            isCurved: false,
            color: AppColors.paletaVerde,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: AppColors.paletaVerde,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//  Cartao 2 - Consumo Calorico Semanal (barras agrupadas)
// =====================================================================
class _CartaoConsumoCalorico extends StatelessWidget {
  const _CartaoConsumoCalorico({required this.dados});

  final ConsumoSemanal dados;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return MvnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TituloCard(texto: 'Consumo Calorico Semanal', emoji: '🔥'),
          const SizedBox(height: 16),
          SizedBox(height: 175, child: _grafico(escuro)),
          const SizedBox(height: 12),
          // Legenda "Consumido" / "Meta", como no prototipo.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendaItem(
                cor: escuro ? AppColors.paletaLilasSuave : AppColors.roxoGrafico,
                texto: 'Consumido',
                corTexto: escuro
                    ? AppColors.paletaLilasSuave
                    : AppColors.roxoGrafico,
              ),
              const SizedBox(width: 20),
              const _LegendaItem(
                cor: AppColors.cinzaMeta,
                texto: 'Meta',
                corTexto: AppColors.textoFraco,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _grafico(bool escuro) {
    final barras = dados.barras;
    final maximo = dados.maximoEixo <= 0 ? 2200.0 : dados.maximoEixo;
    final intervalo = maximo / 4;

    return BarChart(
      BarChartData(
        maxY: maximo,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.texto,
            getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
              final item = barras[indiceGrupo];
              final rotulo = indiceBarra == 0 ? 'Consumido' : 'Meta';
              return BarTooltipItem(
                '${item.rotulo}\n$rotulo: ${barra.toY.round()} kcal',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: intervalo,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.cinzaTrilha,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: AppColors.cinzaTrilha),
            bottom: BorderSide(color: AppColors.cinzaTrilha),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: intervalo,
              getTitlesWidget: (valor, meta) => Text(
                valor.round().toString(),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textoFraco,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (valor, meta) {
                final indice = valor.round();
                if (indice < 0 || indice >= barras.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    barras[indice].rotulo,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textoFraco,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < barras.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                // Consumido (roxo claro no dark / roxo escuro no light)
                BarChartRodData(
                  toY: barras[i].consumido,
                  color: escuro
                      ? AppColors.paletaLilasSuave
                      : AppColors.roxoGrafico,
                  width: 8,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(2),
                  ),
                ),
                // Meta (cinza)
                BarChartRodData(
                  toY: barras[i].meta ?? 0,
                  color: AppColors.cinzaMeta,
                  width: 8,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendaItem extends StatelessWidget {
  const _LegendaItem({
    required this.cor,
    required this.texto,
    required this.corTexto,
  });

  final Color cor;
  final String texto;
  final Color corTexto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(fontSize: 12, color: corTexto),
        ),
      ],
    );
  }
}

// =====================================================================
//  Cartao 3 - Macronutrientes (Media Semanal)
// =====================================================================
class _CartaoMacronutrientes extends StatelessWidget {
  const _CartaoMacronutrientes({required this.dados});

  final Macronutrientes dados;

  /// Cor do valor a direita, seguindo o prototipo:
  /// proteina em roxo claro (dark) / roxo escuro (light), carboidrato em laranja, gordura em verde.
  static Color _corDoValor(String chave, bool escuro) {
    switch (chave) {
      case 'proteinas':
        return escuro ? AppColors.paletaLilasSuave : AppColors.roxoGrafico;
      case 'carboidratos':
        return AppColors.laranja;
      default:
        return AppColors.verde;
    }
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return MvnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TituloCard(
            texto: 'Macronutrientes (Media Semanal)',
            emoji: '🥗',
          ),
          const SizedBox(height: 16),
          for (final item in dados.itens) ...[
            _BarraMacro(item: item, cor: _corDoValor(item.chave, escuro)),
            const SizedBox(height: 14),
          ],
          if (dados.aderenciaMedia != null)
            Text(
              'Adesao media ao plano: '
              '${dados.aderenciaMedia!.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textoFraco),
            ),
        ],
      ),
    );
  }
}

class _BarraMacro extends StatelessWidget {
  const _BarraMacro({required this.item, required this.cor});

  final ItemMacro item;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final valor = ((item.percentual ?? 0) / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.rotulo,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.texto,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              item.textoValores,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: valor,
            minHeight: 9,
            backgroundColor: AppColors.cinzaTrilha,
            valueColor: AlwaysStoppedAnimation<Color>(cor),
          ),
        ),
      ],
    );
  }
}

/// Placeholder para graficos sem dados suficientes.
class _GraficoVazio extends StatelessWidget {
  const _GraficoVazio({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textoSuave),
        ),
      ),
    );
  }
}
