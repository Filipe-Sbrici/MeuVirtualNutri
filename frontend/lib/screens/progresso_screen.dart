/// Tela de Progresso (tela 11 do prototipo).
///
/// Layout reproduzido, de cima para baixo:
///   - Cabecalho verde com gradiente e titulo "Progresso".
///   - Alternador "Semanal" / "Mensal" (verde quando ativo).
///   - Cartao de resumo: numero grande verde com seta, rotulo
///     "Perdidos desde o inicio", "Meta: 65kg (3.1kg restantes)" em roxo,
///     "Peso atual: 68.1kg" e a barra de progresso verde.
///   - Botao roxo "+ REGISTRAR PESO".
///   - Cartao "Historico de Peso" com lista rolavel e botao "x".
///   - Barra de navegacao inferior com "Progresso" ativo.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/progresso.dart';
import '../services/api_services.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/common.dart';

class ProgressoScreen extends StatefulWidget {
  const ProgressoScreen({
    super.key,
    required this.progressoService,
    this.aoAbrirEvolucao,
    this.aoSelecionarAba,
    this.exibirBottomNav = false,
  });

  final ProgressoService progressoService;

  /// Abre a tela de Evolucao (graficos).
  final VoidCallback? aoAbrirEvolucao;

  final ValueChanged<AbaNavegacao>? aoSelecionarAba;

  final bool exibirBottomNav;

  @override
  State<ProgressoScreen> createState() => _ProgressoScreenState();
}

class _ProgressoScreenState extends State<ProgressoScreen> {
  Progresso? _progresso;
  bool _carregando = true;
  String? _erro;

  /// Alternador do prototipo. Filtra o historico exibido.
  String _periodo = 'semanal';

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
      final dados = await widget.progressoService.carregar();
      if (!mounted) return;
      setState(() {
        _progresso = dados;
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

  /// Historico filtrado pelo periodo selecionado.
  List<RegistroPeso> get _historicoFiltrado {
    final historico = _progresso?.historico ?? const <RegistroPeso>[];
    final dias = _periodo == 'semanal' ? 7 : 30;
    final limite = DateTime.now().subtract(Duration(days: dias));

    final filtrado = historico
        .where((r) => !r.dataRegistro.isBefore(limite))
        .toList();

    // Com poucos registros no periodo, mostra o historico completo para
    // que a lista nunca apareca vazia sem motivo.
    return filtrado.isEmpty ? historico : filtrado;
  }

  /// Dialogo de registro de peso, acionado pelo botao roxo.
  Future<void> _abrirDialogoRegistro() async {
    final novoPeso = await showDialog<double>(
      context: context,
      builder: (_) => _DialogoRegistroPeso(
        pesoInicial: _progresso?.resumo.pesoAtual,
      ),
    );

    if (novoPeso == null) return;

    try {
      final atualizado = await widget.progressoService.registrarPeso(
        peso: novoPeso,
      );
      if (!mounted) return;
      setState(() => _progresso = atualizado);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Peso de ${novoPeso.toStringAsFixed(1)} kg registrado com sucesso!',
          ),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro.mensagem),
          backgroundColor: AppColors.vermelho,
        ),
      );
    }
  }

  Future<void> _removerRegistro(RegistroPeso registro) async {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) {
        return AlertDialog(
          backgroundColor:
              escuro ? AppColors.paletaEscuroCard : AppColors.branco,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: escuro
                ? const BorderSide(color: AppColors.bordaEscura)
                : BorderSide.none,
          ),
          title: Text(
            'Remover registro',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
            ),
          ),
          content: Text(
            'Remover a pesagem de ${registro.peso.toStringAsFixed(1)} kg '
            'do dia ${registro.dataFormatada}?',
            style: TextStyle(
              fontSize: 14,
              color: escuro
                  ? AppColors.fonteSubtituloClaro
                  : AppColors.fonteSubtitulo,
            ),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.fonteSubtitulo)),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Remover',
                style: TextStyle(
                    color: AppColors.vermelho, fontWeight: FontWeight.w700)),
          ),
        ],
      );
      },
    );

    if (confirmado != true) return;

    try {
      final atualizado = await widget.progressoService.removerPesagem(
        dataRegistro: registro.idProgresso,
      );
      if (!mounted) return;
      setState(() => _progresso = atualizado);
    } on ApiException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro.mensagem),
          backgroundColor: AppColors.vermelho,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: 'Progresso',
            icone: Icons.show_chart_rounded,
            acoes: [
              // Atalho para a tela de Evolucao (graficos).
              if (widget.aoAbrirEvolucao != null)
                IconButton(
                  onPressed: widget.aoAbrirEvolucao,
                  tooltip: 'Ver evolucao',
                  icon: const Icon(Icons.insights_rounded),
                  color: Colors.white,
                  iconSize: 22,
                ),
            ],
          ),
          Expanded(child: _corpo()),
        ],
      ),
      bottomNavigationBar: (widget.exibirBottomNav && widget.aoSelecionarAba != null)
          ? BottomNav(
              abaAtiva: AbaNavegacao.progresso,
              aoSelecionar: widget.aoSelecionarAba,
            )
          : null,
    );
  }

  Widget _corpo() {
    if (_carregando) return const CarregandoView();
    if (_erro != null) return ErroView(mensagem: _erro!, aoTentar: _carregar);

    final progresso = _progresso!;

    return RefreshIndicator(
      color: AppColors.paletaVerde,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.telaPadding),
        children: [
          _AlternadorPeriodo(
            periodo: _periodo,
            aoTrocar: (valor) => setState(() => _periodo = valor),
          ),
          const SizedBox(height: AppSizes.telaPadding),
          _CartaoResumo(resumo: progresso.resumo),
          const SizedBox(height: AppSizes.espacoEntreCards),
          BotaoGradiente(
            texto: 'REGISTRAR PESO',
            icone: Icons.add,
            aoTocar: _abrirDialogoRegistro,
          ),
          const SizedBox(height: AppSizes.espacoEntreCards),
          _CartaoHistorico(
            registros: _historicoFiltrado,
            aoRemover: _removerRegistro,
          ),
          if (widget.aoAbrirEvolucao != null) ...[
            const SizedBox(height: AppSizes.espacoEntreCards),
            _LinkEvolucao(aoTocar: widget.aoAbrirEvolucao!),
          ],
        ],
      ),
    );
  }
}

/// Dialogo "Registrar peso".
///
/// Widget proprio (e nao um `showDialog` inline) para que o
/// `TextEditingController` viva exatamente enquanto o dialogo existe:
/// descarta-lo logo apos o `pop` derrubava a animacao de saida com
/// "A TextEditingController was used after being disposed".
class _DialogoRegistroPeso extends StatefulWidget {
  const _DialogoRegistroPeso({this.pesoInicial});

  final double? pesoInicial;

  @override
  State<_DialogoRegistroPeso> createState() => _DialogoRegistroPesoState();
}

class _DialogoRegistroPesoState extends State<_DialogoRegistroPeso> {
  final GlobalKey<FormState> _chaveForm = GlobalKey<FormState>();
  late final TextEditingController _campo = TextEditingController(
    text: widget.pesoInicial != null
        ? widget.pesoInicial!.toStringAsFixed(1)
        : '',
  );

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_chaveForm.currentState?.validate() != true) return;
    final texto = _campo.text.replaceAll(',', '.').trim();
    Navigator.of(context).pop(double.parse(texto));
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor:
          escuro ? AppColors.paletaEscuroCard : AppColors.branco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: escuro
            ? const BorderSide(color: AppColors.bordaEscura)
            : BorderSide.none,
      ),
      title: Text(
        'Registrar peso',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
        ),
      ),
      content: Form(
        key: _chaveForm,
        child: TextFormField(
          controller: _campo,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _salvar(),
          decoration: const InputDecoration(
            labelText: 'Peso (kg)',
            suffixText: 'kg',
          ),
          validator: (valor) {
            // Aceita virgula ou ponto como separador decimal.
            final texto = (valor ?? '').replaceAll(',', '.').trim();
            final numero = double.tryParse(texto);
            if (numero == null) return 'Informe um numero valido.';
            if (numero < 20 || numero > 400) {
              return 'O peso deve estar entre 20 e 400 kg.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.fonteSubtitulo)),
        ),
        TextButton(
          onPressed: _salvar,
          child: Text('Salvar',
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.paletaLilasSuave
                      : AppColors.paletaRoxo,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Alternador "Semanal" / "Mensal".
class _AlternadorPeriodo extends StatelessWidget {
  const _AlternadorPeriodo({required this.periodo, required this.aoTrocar});

  final String periodo;
  final ValueChanged<String> aoTrocar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Segmento(
            texto: 'Semanal',
            ativo: periodo == 'semanal',
            aoTocar: () => aoTrocar('semanal'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Segmento(
            texto: 'Mensal',
            ativo: periodo == 'mensal',
            aoTocar: () => aoTrocar('mensal'),
          ),
        ),
      ],
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento({
    required this.texto,
    required this.ativo,
    required this.aoTocar,
  });

  final String texto;
  final bool ativo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: ativo
          ? AppColors.paletaVerde
          : (escuro ? const Color(0xFF21262D) : AppColors.cinzaSegmento),
      borderRadius: BorderRadius.circular(AppSizes.segmentoRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.segmentoRadius),
        onTap: aoTocar,
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
    );
  }
}

/// Cartao de resumo com o numero grande e a barra de progresso.
class _CartaoResumo extends StatelessWidget {
  const _CartaoResumo({required this.resumo});

  final ResumoProgresso resumo;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    // Verde para perda de peso, lilas/roxo para ganho (paleta do prototipo).
    final cor = resumo.ehGanho
        ? (escuro ? AppColors.paletaLilasSuave : AppColors.paletaRoxo)
        : AppColors.paletaVerde;

    return MvnCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        children: [
          // Numero grande + seta de direcao.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${resumo.diferenca.toStringAsFixed(1)}kg',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: cor,
                  height: 1.1,
                ),
              ),
              if (resumo.sentido != 'estavel')
                Icon(
                  resumo.ehPerda
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: cor,
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            resumo.rotuloDiferenca,
            style: TextStyle(
              fontSize: 13,
              color: escuro
                  ? AppColors.fonteSubtituloClaro
                  : AppColors.fonteSubtitulo,
            ),
          ),
          const SizedBox(height: 10),

          // "Meta: 65kg (3.1kg restantes)" em roxo.
          if (resumo.pesoMeta != null)
            Text(
              'Meta: ${_semZeroInutil(resumo.pesoMeta!)}kg'
              '${resumo.restantesParaMeta != null ? ' (${resumo.restantesParaMeta!.toStringAsFixed(1)}kg restantes)' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: escuro
                    ? AppColors.paletaLilasSuave
                    : AppColors.paletaRoxo,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Peso atual: ${resumo.pesoAtual.toStringAsFixed(1)}kg',
            style: TextStyle(
              fontSize: 12.5,
              color: escuro
                  ? AppColors.fonteSubtituloClaro
                  : AppColors.fonteSubtitulo,
            ),
          ),

          // Barra de progresso rumo a meta.
          if (resumo.percentualMeta != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (resumo.percentualMeta! / 100).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: AppColors.cinzaTrilha,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.paletaVerde),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 65.0 -> "65" | 64.5 -> "64.5" (como no prototipo).
  static String _semZeroInutil(double valor) =>
      valor == valor.roundToDouble()
          ? valor.toStringAsFixed(0)
          : valor.toStringAsFixed(1);
}

/// Cartao "Historico de Peso" com lista rolavel interna.
class _CartaoHistorico extends StatefulWidget {
  const _CartaoHistorico({required this.registros, required this.aoRemover});

  final List<RegistroPeso> registros;
  final ValueChanged<RegistroPeso> aoRemover;

  @override
  State<_CartaoHistorico> createState() => _CartaoHistoricoState();
}

class _CartaoHistoricoState extends State<_CartaoHistorico> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registros = widget.registros;

    return MvnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TituloCard(texto: 'Historico de Peso', emoji: '📋'),
          const SizedBox(height: 12),
          if (registros.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Nenhuma pesagem registrada ainda.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.fontePlaceholder),
                ),
              ),
            )
          else
            // Altura fixa com scroll interno, como no prototipo.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _scroll,
                  padding: EdgeInsets.zero,
                  itemCount: registros.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, indice) => _ItemHistorico(
                    registro: registros[indice],
                    aoRemover: () => widget.aoRemover(registros[indice]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemHistorico extends StatelessWidget {
  const _ItemHistorico({required this.registro, required this.aoRemover});

  final RegistroPeso registro;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: escuro
            ? const Color(0xFF21262D)
            : AppColors.paletaVerdeSuave.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
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
                  '${registro.peso.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color:
                        escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
                  ),
                ),
                Text(
                  registro.dataFormatada,
                  style: TextStyle(
                    fontSize: 12,
                    color: escuro
                        ? AppColors.fonteSubtituloClaro
                        : AppColors.fonteSubtitulo,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: aoRemover,
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.vermelho),
            padding: EdgeInsets.zero,
            tooltip: 'Remover',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

/// Acesso a tela de Evolucao a partir do Progresso.
class _LinkEvolucao extends StatelessWidget {
  const _LinkEvolucao({required this.aoTocar});

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              const Text('📈', style: TextStyle(fontSize: 17)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ver evolucao completa',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color:
                        escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: escuro
                      ? AppColors.fonteSubtituloClaro
                      : AppColors.fontePlaceholder),
            ],
          ),
        ),
      ),
    );
  }
}
