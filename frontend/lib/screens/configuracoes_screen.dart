/// Tela Principal de Configuracoes (Página 1 do documento de requisitos).
///
/// Apresenta o cabecalho do usuario com avatar e anel das cores da marca
/// (#5ED360 e #43164F) e os 5 botoes de acao principais:
///  1. Dados Profissionais / Dados Pessoais (visualizar e editar)
///  2. Notificacoes (mensagens, consultas e personalizacao)
///  3. Aparencia e Acessibilidade (tema claro/escuro e tamanho da fonte)
///  4. Sair da conta (logout)
///  5. Excluir conta (remocao permanente)
///
/// Relacionamento:
/// - Exibida ao clicar no icone de engrenagem na barra inferior tanto do
///   Nutricionista ([NutricionistaHomeScreen]) quanto do Paciente ([PacienteHomeScreen]).
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/usuario.dart';
import '../services/api_services.dart';
import '../services/mvn_services.dart';
import '../widgets/common.dart';
import 'aparencia_acessibilidade_screen.dart';
import 'dados_perfil_screen.dart';
import 'notificacoes_config_screen.dart';
import 'perfil_screen.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({
    super.key,
    required this.usuario,
    required this.authService,
    required this.onboardingService,
    required this.aoAtualizarUsuario,
    required this.aoFazerLogout,
  });

  final Usuario usuario;
  final AuthService authService;
  final OnboardingService onboardingService;
  final void Function(Usuario usuario) aoAtualizarUsuario;
  final VoidCallback aoFazerLogout;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final ehNutri = usuario.ehNutricionista;

    // Titulo formatado com Dr(a). para nutricionista
    final nomeFormatado = ehNutri
        ? (usuario.nome.toLowerCase().startsWith('dr')
            ? usuario.nome
            : 'Dr(a). ${usuario.nome}')
        : usuario.nome;

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor:
            escuro ? AppColors.paletaEscuroCard : AppColors.paletaRoxo,
        foregroundColor: Colors.white,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                tooltip: 'Voltar',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.telaPadding),
        children: [
          // -------------------------------------------------------------
          // Header com Foto/Avatar e Nome do Usuario
          // -------------------------------------------------------------
          MvnCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                // Avatar com anel de destaque nas cores oficiais da marca
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.paletaVerde,
                        AppColors.paletaRoxo,
                      ],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor:
                        escuro ? const Color(0xFF21262D) : AppColors.paletaVerdeSuave,
                    child: Text(
                      usuario.nome.isNotEmpty
                          ? usuario.nome.trim()[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: escuro
                            ? AppColors.paletaLilasSuave
                            : AppColors.paletaRoxo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Nome e identificacao
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeFormatado,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ehNutri
                            ? (usuario.crn != null && usuario.crn!.isNotEmpty
                                ? '${usuario.crn} • Nutricionista'
                                : 'Nutricionista')
                            : 'Paciente Virtual Nutri',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.paletaVerde,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        usuario.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: escuro
                              ? AppColors.fonteSubtituloClaro
                              : AppColors.fonteSubtitulo,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -------------------------------------------------------------
          // 1. Dados Profissionais / Dados Pessoais
          // -------------------------------------------------------------
          _botaoConfig(
            context: context,
            icone: Icons.person_outline_rounded,
            titulo: ehNutri ? 'Dados Profissionais' : 'Dados Pessoais',
            subtitulo: 'Veja e edite suas informações',
            corIcone: AppColors.paletaVerde,
            corFundoIcone: AppColors.paletaVerde.withValues(alpha: 0.12),
            escuro: escuro,
            aoPressionar: () {
              if (ehNutri) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DadosPerfilScreen(
                      usuario: usuario,
                      onboardingService: onboardingService,
                      aoAtualizarUsuario: aoAtualizarUsuario,
                    ),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PerfilScreen(
                      usuario: usuario,
                      authService: authService,
                      onboardingService: onboardingService,
                      aoAtualizarUsuario: aoAtualizarUsuario,
                      aoFazerLogout: aoFazerLogout,
                    ),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------------------
          // 2. Notificacoes
          // -------------------------------------------------------------
          _botaoConfig(
            context: context,
            icone: Icons.notifications_none_rounded,
            titulo: 'Notificações',
            subtitulo: 'Mensagens, consultas e personalização',
            corIcone:
                escuro ? AppColors.paletaVerde : AppColors.paletaRoxo,
            corFundoIcone: escuro
                ? AppColors.paletaVerde.withValues(alpha: 0.15)
                : AppColors.paletaRoxo.withValues(alpha: 0.12),
            escuro: escuro,
            aoPressionar: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificacoesConfigScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------------------
          // 3. Aparencia e Acessibilidade
          // -------------------------------------------------------------
          _botaoConfig(
            context: context,
            icone: Icons.palette_outlined,
            titulo: 'Aparência e Acessibilidade',
            subtitulo: 'Altere o tema e o tamanho da fonte',
            corIcone: const Color(0xFF00A73E),
            corFundoIcone: AppColors.paletaVerdeSuave,
            escuro: escuro,
            aoPressionar: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AparenciaAcessibilidadeScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // 4. Botao Sair da Conta
          // -------------------------------------------------------------
          _botaoAcaoBorda(
            titulo: 'Sair da conta',
            icone: Icons.logout_rounded,
            corTexto: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
            corBorda: escuro ? AppColors.bordaEscura : AppColors.bordaCinza,
            aoPressionar: () => _confirmarLogout(context),
          ),

          const SizedBox(height: 10),

          // -------------------------------------------------------------
          // 5. Botao Excluir Conta
          // -------------------------------------------------------------
          _botaoAcaoBorda(
            titulo: 'Excluir conta',
            icone: Icons.delete_outline_rounded,
            corTexto: AppColors.vermelho,
            corBorda: AppColors.vermelho.withValues(alpha: 0.4),
            corFundo: AppColors.vermelho.withValues(alpha: 0.04),
            aoPressionar: () => _confirmarExclusaoConta(context),
          ),

          const SizedBox(height: 20),

          // Versao do aplicativo
          Center(
            child: Text(
              'Meu Virtual Nutri • Versão 2.1.0',
              style: TextStyle(
                fontSize: 11.5,
                color: escuro
                    ? AppColors.fonteSubtituloClaro
                    : AppColors.textoFraco,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoConfig({
    required BuildContext context,
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required Color corIcone,
    required Color corFundoIcone,
    required bool escuro,
    required VoidCallback aoPressionar,
  }) {
    return InkWell(
      onTap: aoPressionar,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: MvnCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: corFundoIcone,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icone, size: 24, color: corIcone),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textoFraco,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoAcaoBorda({
    required String titulo,
    required IconData icone,
    required Color corTexto,
    required Color corBorda,
    Color? corFundo,
    required VoidCallback aoPressionar,
  }) {
    return InkWell(
      onTap: aoPressionar,
      borderRadius: BorderRadius.circular(AppSizes.botaoRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: corFundo ?? Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.botaoRadius),
          border: Border.all(color: corBorda, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 19, color: corTexto),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: corTexto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarLogout(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: escuro ? AppColors.paletaEscuroCard : AppColors.branco,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: escuro
              ? const BorderSide(color: AppColors.bordaEscura)
              : BorderSide.none,
        ),
        title: Text(
          'Encerrar Sessão',
          style: TextStyle(
            color: escuro ? AppColors.paletaClaro : AppColors.fonteTitulo,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Deseja realmente sair da sua conta no aplicativo?',
          style: TextStyle(
            color: escuro ? AppColors.fonteSubtituloClaro : AppColors.textoSuave,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: escuro ? AppColors.fonteSubtituloClaro : AppColors.textoSuave,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              aoFazerLogout();
            },
            child: const Text(
              'Sair',
              style: TextStyle(color: AppColors.vermelho, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusaoConta(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: escuro ? AppColors.paletaEscuroCard : AppColors.branco,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: escuro
              ? const BorderSide(color: AppColors.bordaEscura)
              : BorderSide.none,
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.vermelho),
            SizedBox(width: 8),
            Text('Excluir Conta'),
          ],
        ),
        content: Text(
          'Esta ação é irreversível. Todos os seus dados, histórico, planos e consultas serão permanentemente excluídos.',
          style: TextStyle(
            color: escuro ? AppColors.fonteSubtituloClaro : AppColors.textoSuave,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: escuro ? AppColors.fonteSubtituloClaro : AppColors.textoSuave,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await authService.excluirConta();
                aoFazerLogout();
              } on ApiException catch (erro) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(erro.mensagem)),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Falha ao excluir a conta. Tente novamente.'),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Excluir Definitivamente',
              style: TextStyle(color: AppColors.vermelho, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
