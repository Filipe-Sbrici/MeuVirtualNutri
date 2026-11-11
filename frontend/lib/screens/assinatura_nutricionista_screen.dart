/// Tela de Plano e Assinatura do Nutricionista (Mercado Pago + Firebase).
///
/// Regras de negocio:
///  - Sem assinatura (Plano Gratuito): limite de ate 15 pacientes ativos.
///  - Com assinatura (Plano Pro): R$ 29,90/mes via Mercado Pago, sem limite
///    de pacientes.
///
/// Relacionamento:
///  - Acessada a partir da [ConfiguracoesScreen] (exclusiva para nutricionistas)
///    ou a partir do alerta de limite de pacientes na [NutricionistaHomeScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/usuario.dart';
import '../services/mvn_services.dart';
import '../widgets/common.dart';

class AssinaturaNutricionistaScreen extends StatefulWidget {
  const AssinaturaNutricionistaScreen({
    super.key,
    required this.usuario,
    required this.nutricionistaService,
    required this.aoAtualizarUsuario,
  });

  final Usuario usuario;
  final NutricionistaService nutricionistaService;
  final void Function(Usuario usuario) aoAtualizarUsuario;

  @override
  State<AssinaturaNutricionistaScreen> createState() =>
      _AssinaturaNutricionistaScreenState();
}

class _AssinaturaNutricionistaScreenState
    extends State<AssinaturaNutricionistaScreen> {
  late Usuario _usuario = widget.usuario;
  StatusAssinaturaNutricionista? _status;
  bool _carregando = true;
  bool _processando = false;
  String? _erro;
  String _metodoSelecionado = 'pix'; // 'pix' | 'cartao' | 'checkout_mp'

  @override
  void initState() {
    super.initState();
    _metodoSelecionado = _usuario.metodoPagamentoAssinatura ?? 'pix';
    _carregarStatus();
  }

  Future<void> _carregarStatus() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final status =
          await widget.nutricionistaService.obterStatusAssinatura();
      if (!mounted) return;
      setState(() {
        _status = status;
        _usuario = _usuario.copiarCom({
          'planoAssinatura': status.planoAssinatura,
          'statusAssinatura': status.statusAssinatura,
          'ehAssinante': status.ehAssinante,
          'limitePacientes': status.limitePacientes,
          'precoAssinatura': status.precoMensal,
          'assinaturaValidaAte': status.assinaturaValidaAte,
          'idAssinaturaMp': status.idAssinaturaMp,
          'metodoPagamentoAssinatura': status.metodoPagamento,
        });
        _carregando = false;
      });
      widget.aoAtualizarUsuario(_usuario);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Fallback com dados locais do usuario caso a rota falhe em ambiente offline/mock
      setState(() {
        _status = StatusAssinaturaNutricionista(
          planoAssinatura: _usuario.planoAssinatura,
          statusAssinatura: _usuario.statusAssinatura,
          ehAssinante: _usuario.ehAssinante,
          precoMensal: _usuario.precoAssinatura,
          limitePacientes: _usuario.limitePacientes,
          limitePlanoGratuito: 15,
          totalPacientesAtivos: 0,
          restantesGratuito: _usuario.ehAssinante ? null : 15,
          limiteAtingido: false,
          assinaturaValidaAte: _usuario.assinaturaValidaAte,
          idAssinaturaMp: _usuario.idAssinaturaMp,
          metodoPagamento: _usuario.metodoPagamentoAssinatura ?? 'pix',
        );
        _carregando = false;
      });
    }
  }

  Future<void> _iniciarCheckoutMercadoPago() async {
    if (_processando) return;
    setState(() => _processando = true);

    try {
      // Inicia a pre-aprovacao no Mercado Pago (R$ 29,90/mes)
      final (novoStatus, perfilAtualizado) =
          await widget.nutricionistaService.assinarPlanoPro(
        metodoPagamento: _metodoSelecionado,
        confirmarImediatamente: false,
      );

      if (!mounted) return;
      setState(() {
        _status = novoStatus;
        if (perfilAtualizado != null) _usuario = perfilAtualizado;
        _processando = false;
      });

      final confirmado = await _abrirModalPagamentoMercadoPago(novoStatus);
      if (confirmado == true && mounted) {
        await _confirmarPagamentoMercadoPago();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.mensagem),
          backgroundColor: AppColors.vermelho,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível iniciar o pagamento no Mercado Pago.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
    }
  }

  Future<void> _confirmarPagamentoMercadoPago() async {
    if (_processando) return;
    setState(() => _processando = true);

    try {
      final (statusConfirmado, perfilAtualizado) =
          await widget.nutricionistaService.sincronizarAssinatura();

      if (!mounted) return;
      final novoUsuario = perfilAtualizado ??
          _usuario.copiarCom({
            'planoAssinatura': statusConfirmado.planoAssinatura,
            'statusAssinatura': statusConfirmado.statusAssinatura,
            'ehAssinante': statusConfirmado.ehAssinante,
            'limitePacientes': statusConfirmado.limitePacientes,
            'assinaturaValidaAte': statusConfirmado.assinaturaValidaAte,
            'idAssinaturaMp': statusConfirmado.idAssinaturaMp,
            'metodoPagamentoAssinatura': _metodoSelecionado,
          });

      setState(() {
        _status = statusConfirmado;
        _usuario = novoUsuario;
        _processando = false;
      });
      widget.aoAtualizarUsuario(novoUsuario);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assinatura Pro ativada via Mercado Pago! Pacientes ilimitados liberados.',
          ),
          backgroundColor: AppColors.verdeEscuro,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.mensagem),
          backgroundColor: AppColors.vermelho,
        ),
      );
    }
  }

  Future<void> _confirmarCancelamento() async {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: escuro ? AppColors.paletaEscuroCard : AppColors.branco,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.vermelho),
            SizedBox(width: 8),
            Expanded(child: Text('Cancelar Assinatura Pro')),
          ],
        ),
        content: const Text(
          'Ao cancelar sua assinatura no Mercado Pago, sua conta voltará ao Plano Gratuito com limite máximo de 15 pacientes ativos.\n\nDeseja realmente cancelar?',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Manter Plano Pro'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Confirmar Cancelamento',
              style: TextStyle(
                color: AppColors.vermelho,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _processando = true);
    try {
      final (statusCancelado, perfilAtualizado) =
          await widget.nutricionistaService.cancelarAssinatura();
      if (!mounted) return;

      final novoUsuario = perfilAtualizado ??
          _usuario.copiarCom({
            'planoAssinatura': 'gratuito',
            'statusAssinatura': 'cancelada',
            'ehAssinante': false,
            'limitePacientes': 15,
            'assinaturaValidaAte': null,
          });

      setState(() {
        _status = statusCancelado;
        _usuario = novoUsuario;
        _processando = false;
      });
      widget.aoAtualizarUsuario(novoUsuario);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assinatura cancelada. Sua conta voltou ao Plano Gratuito (limite de 15 pacientes).',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.mensagem),
          backgroundColor: AppColors.vermelho,
        ),
      );
    }
  }

  Future<bool?> _abrirModalPagamentoMercadoPago(
    StatusAssinaturaNutricionista status,
  ) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final checkoutUrl = status.checkoutUrl ??
        'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_id=${status.idAssinaturaMp ?? "mvn_pro"}';
    final codigoPixSimulado =
        '00020126580014BR.GOV.BCB.PIX0136mercadopago-mvn-pro-${status.idAssinaturaMp ?? "2990"}520400005303986540529.905802BR5917MEU VIRTUAL NUTRI6009SAO PAULO62070503***6304ABCD';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: escuro ? AppColors.paletaEscuroCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF009EE3).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF009EE3),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mercado Pago • Assinatura Mensal',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Plano Pro MVN • R\$ 29,90 / mês',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF009EE3),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                if (_metodoSelecionado == 'pix') ...[
                  const Text(
                    'Pague com Pix via Mercado Pago:',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Copie o código Pix abaixo ou confirme o pagamento para liberar pacientes ilimitados na sua conta.',
                    style: TextStyle(
                      fontSize: 12,
                      color: escuro
                          ? AppColors.fonteSubtituloClaro
                          : AppColors.textoSuave,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: escuro ? const Color(0xFF0D1117) : AppColors.fundo,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: escuro ? AppColors.bordaEscura : AppColors.borda,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 96,
                          color: Color(0xFF009EE3),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          codigoPixSimulado,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: codigoPixSimulado),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Código Pix Copia e Cola copiado!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copiar Pix Copia e Cola'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    _metodoSelecionado == 'cartao'
                        ? 'Assinatura Recorrente no Cartão (Mercado Pago)'
                        : 'Checkout Oficial Mercado Pago',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: escuro ? const Color(0xFF0D1117) : AppColors.fundo,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: escuro ? AppColors.bordaEscura : AppColors.borda,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.link_rounded,
                                size: 18, color: Color(0xFF009EE3)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Link de Assinatura Gerado:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          checkoutUrl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF009EE3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: checkoutUrl),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Link do Checkout Mercado Pago copiado!',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copiar Link do Checkout'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.botaoAltura,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.paletaVerde,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.botaoRadius),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'Confirmar Pagamento (R\$ 29,90)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final ehAssinante = _status?.ehAssinante ?? _usuario.ehAssinante;
    final totalPacientes = _status?.totalPacientesAtivos ?? 0;
    final limiteGratuito = _status?.limitePlanoGratuito ?? 15;
    final proporcaoUso =
        (totalPacientes / limiteGratuito).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Plano e Assinatura'),
        backgroundColor:
            escuro ? AppColors.paletaEscuroCard : AppColors.paletaRoxo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar status',
            onPressed: _carregando ? null : _carregarStatus,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _carregando
          ? const CarregandoView()
          : _erro != null
              ? ErroView(mensagem: _erro!, aoTentar: _carregarStatus)
              : ListView(
                  padding: const EdgeInsets.all(AppSizes.telaPadding),
                  children: [
                    // -------------------------------------------------------
                    // 1. Card de Status Atual da Assinatura
                    // -------------------------------------------------------
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: ehAssinante
                              ? const [
                                  AppColors.paletaVerde,
                                  Color(0xFF15803D),
                                ]
                              : const [
                                  AppColors.paletaRoxo,
                                  Color(0xFF6B21A8),
                                ],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppSizes.cardRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  ehAssinante
                                      ? Icons.workspace_premium_rounded
                                      : Icons.card_membership_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ehAssinante
                                          ? 'Plano Pro Ativo'
                                          : 'Plano Gratuito',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ehAssinante
                                          ? 'Assinatura Mercado Pago • Pacientes ilimitados'
                                          : 'Limite de até $limiteGratuito pacientes ativos',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  ehAssinante ? 'PRO' : 'GRÁTIS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: ehAssinante
                                        ? AppColors.verdeEscuro
                                        : AppColors.paletaRoxo,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (ehAssinante &&
                              _status?.idAssinaturaMp != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'ID Mercado Pago: ${_status!.idAssinaturaMp}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------
                    // 2. Card de Uso de Pacientes (X / 15 ou Ilimitado)
                    // -------------------------------------------------------
                    MvnCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 20,
                                    color: AppColors.paletaVerde,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Capacidade de Pacientes',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                ehAssinante
                                    ? '$totalPacientes / Ilimitado'
                                    : '$totalPacientes / $limiteGratuito pacientes',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: (!ehAssinante &&
                                          totalPacientes >= limiteGratuito)
                                      ? AppColors.vermelho
                                      : AppColors.paletaVerde,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (!ehAssinante) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: proporcaoUso,
                                minHeight: 9,
                                backgroundColor: escuro
                                    ? const Color(0xFF21262D)
                                    : AppColors.cinzaTrilha,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  totalPacientes >= limiteGratuito
                                      ? AppColors.vermelho
                                      : AppColors.paletaVerde,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              totalPacientes >= limiteGratuito
                                  ? 'Você atingiu o limite máximo de $limiteGratuito pacientes do Plano Gratuito. Assine o Plano Pro abaixo para liberar novos pacientes.'
                                  : 'Você ainda pode vincular mais ${limiteGratuito - totalPacientes} paciente(s) gratuitamente.',
                              style: TextStyle(
                                fontSize: 12,
                                color: totalPacientes >= limiteGratuito
                                    ? AppColors.vermelho
                                    : (escuro
                                        ? AppColors.fonteSubtituloClaro
                                        : AppColors.textoSuave),
                              ),
                            ),
                          ] else
                            Text(
                              'Sua assinatura Pro está ativa! Você pode vincular e atender quantos pacientes quiser sem qualquer bloqueio.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: escuro
                                    ? AppColors.fonteSubtituloClaro
                                    : AppColors.textoSuave,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------
                    // 3. Detalhes e Beneficios do Plano Pro (R$ 29,90/mes)
                    // -------------------------------------------------------
                    MvnCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Plano Profissional MVN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Pagamento seguro via Mercado Pago',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF009EE3),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.paletaVerde
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'R\$ 29,90',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.verdeEscuro,
                                      ),
                                    ),
                                    Text(
                                      'por mês',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textoSuave,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _itemBeneficio(
                            'Pacientes ilimitados (sem a trava de 15 pacientes)',
                          ),
                          _itemBeneficio(
                            'Editor completo de planos alimentares e receitas com macros',
                          ),
                          _itemBeneficio(
                            'Relatórios de evolução, adesão e chat em tempo real',
                          ),
                          _itemBeneficio(
                            'Renovação mensal via Mercado Pago • Cancele quando quiser',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------
                    // 4. Selecao de Forma de Pagamento (Mercado Pago)
                    // -------------------------------------------------------
                    if (!ehAssinante) ...[
                      MvnCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.payment_rounded,
                                  size: 20,
                                  color: Color(0xFF009EE3),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Forma de Pagamento (Mercado Pago)',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _opcaoMetodoPagamento(
                              id: 'pix',
                              titulo: 'Pix Mercado Pago',
                              subtitulo:
                                  'Liberação imediata via QR Code ou Pix Copia e Cola',
                              icone: Icons.qr_code_rounded,
                              escuro: escuro,
                            ),
                            const SizedBox(height: 8),
                            _opcaoMetodoPagamento(
                              id: 'cartao',
                              titulo: 'Cartão de Crédito',
                              subtitulo:
                                  'Cobrança mensal automática de R\$ 29,90 no cartão',
                              icone: Icons.credit_card_rounded,
                              escuro: escuro,
                            ),
                            const SizedBox(height: 8),
                            _opcaoMetodoPagamento(
                              id: 'checkout_mp',
                              titulo: 'Checkout Pro Mercado Pago',
                              subtitulo:
                                  'Pague com saldo da conta Mercado Pago ou boleto',
                              icone: Icons.account_balance_wallet_outlined,
                              escuro: escuro,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: AppSizes.botaoAltura,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.paletaVerde,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.botaoRadius),
                            ),
                            elevation: 0,
                          ),
                          onPressed:
                              _processando ? null : _iniciarCheckoutMercadoPago,
                          icon: _processando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.rocket_launch_rounded),
                          label: const Text(
                            'Assinar Plano Pro • R\$ 29,90/mês',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_status?.statusAssinatura == 'pendente') ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _processando
                              ? null
                              : _confirmarPagamentoMercadoPago,
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: const Text(
                            'Já realizei o pagamento • Sincronizar Status',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF009EE3),
                            side: const BorderSide(color: Color(0xFF009EE3)),
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Nutricionista ja e assinante Pro: botao para gerenciar/cancelar
                      OutlinedButton.icon(
                        onPressed: _processando ? null : _confirmarCancelamento,
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: AppColors.vermelho,
                        ),
                        label: const Text(
                          'Cancelar Assinatura Pro',
                          style: TextStyle(
                            color: AppColors.vermelho,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.vermelho.withValues(alpha: 0.5),
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.botaoRadius),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _itemBeneficio(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.paletaVerde,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _opcaoMetodoPagamento({
    required String id,
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required bool escuro,
  }) {
    final selecionado = _metodoSelecionado == id;
    return InkWell(
      onTap: () => setState(() => _metodoSelecionado = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selecionado
              ? (escuro
                  ? const Color(0xFF1E3A2F)
                  : AppColors.paletaVerdeSuave.withValues(alpha: 0.5))
              : (escuro ? const Color(0xFF0D1117) : AppColors.fundo),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selecionado
                ? AppColors.paletaVerde
                : (escuro ? AppColors.bordaEscura : AppColors.borda),
            width: selecionado ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icone,
              color: selecionado
                  ? AppColors.paletaVerde
                  : const Color(0xFF009EE3),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
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
            Icon(
              selecionado
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color:
                  selecionado ? AppColors.paletaVerde : AppColors.textoFraco,
            ),
          ],
        ),
      ),
    );
  }
}

