/// Dialogo para configuracao interativa do endereco do servidor da API (Node.js).
///
/// Permite aos desenvolvedores, testadores e avaliadores do TCC:
/// 1. Visualizar a URL atualmente ativa da API ou ativar o Modo Integrado (Celular).
/// 2. Alterar o IP ou endereco (ex.: IP da rede local Wi-Fi, emulador ou nuvem).
/// 3. Buscar automaticamente o servidor Node.js na rede Wi-Fi local.
/// 4. Testar a conexao em tempo real antes de salvar.
/// 5. Persistir a escolha no dispositivo para sessoes futuras.
library;

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/theme.dart';

class ConfigServidorDialog extends StatefulWidget {
  const ConfigServidorDialog({super.key});

  /// Exibe o dialogo de configuracao do servidor e retorna true caso tenha sido alterado.
  static Future<bool?> mostrar(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const ConfigServidorDialog(),
    );
  }

  @override
  State<ConfigServidorDialog> createState() => _ConfigServidorDialogState();
}

class _ConfigServidorDialogState extends State<ConfigServidorDialog> {
  late final TextEditingController _urlController;
  bool _testando = false;
  bool _buscandoRede = false;
  ResultadoConexao? _resultadoTeste;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _executarTeste() async {
    final entrada = _urlController.text.trim();
    if (entrada.isEmpty) return;

    setState(() {
      _testando = true;
      _resultadoTeste = null;
    });

    final resultado = await AppConfig.testarConexao(entrada);

    if (!mounted) return;
    setState(() {
      _testando = false;
      _resultadoTeste = resultado;
    });
  }

  Future<void> _buscarNaRede() async {
    setState(() {
      _buscandoRede = true;
      _resultadoTeste = null;
    });

    final encontrado = await AppConfig.descobrirServidorNaRede();
    if (!mounted) return;

    if (encontrado != null) {
      setState(() {
        _buscandoRede = false;
        _urlController.text = encontrado;
        _resultadoTeste = ResultadoConexao(
          sucesso: true,
          mensagem: 'Servidor Node.js encontrado automaticamente em $encontrado!',
          tempoMs: 0,
        );
      });
    } else {
      AppConfig.ativarModoIntegrado(true);
      setState(() {
        _buscandoRede = false;
        _urlController.text = 'integrado';
        _resultadoTeste = const ResultadoConexao(
          sucesso: true,
          mensagem:
              'Nenhum servidor Node.js externo encontrado no Wi-Fi. Modo Integrado do Celular ativado automaticamente!',
          tempoMs: 0,
        );
      });
    }
  }

  Future<void> _salvar() async {
    final entrada = _urlController.text.trim();
    if (entrada.isEmpty) return;

    setState(() => _salvando = true);
    await AppConfig.definirUrlCustomizada(entrada);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _restaurarPadrao() async {
    setState(() => _salvando = true);
    await AppConfig.limparUrlCustomizada();

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _aplicarPredefinicao(String valor) {
    setState(() {
      _urlController.text =
          valor == 'integrado' ? 'integrado' : AppConfig.normalizarUrl(valor);
      _resultadoTeste = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: AppColors.verdeEscuro, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Servidor da API',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No celular, o aplicativo funciona automaticamente com o Modo Integrado + Firebase Auth, ou pode se conectar a um servidor Node.js na mesma rede Wi-Fi.',
              style: TextStyle(fontSize: 13, color: AppColors.textoFraco),
            ),
            const SizedBox(height: 16),

            // Campo de texto para URL
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Modo ou URL da API',
                hintText: 'integrado ou http://192.168.0.22:3000/api',
                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: 'Limpar',
                  onPressed: () => _urlController.clear(),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) {
                if (_resultadoTeste != null) {
                  setState(() => _resultadoTeste = null);
                }
              },
            ),

            const SizedBox(height: 12),

            // Sugestoes rapidas (Chips)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text(
                    'Modo Celular (Integrado)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  avatar: const Icon(Icons.smartphone_rounded, size: 14),
                  onPressed: () => _aplicarPredefinicao('integrado'),
                ),
                ActionChip(
                  label: const Text('192.168.15.165 (PC Wi-Fi)', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.wifi_rounded, size: 14),
                  onPressed: () => _aplicarPredefinicao('192.168.15.165'),
                ),
                ActionChip(
                  label: const Text('192.168.0.22', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.wifi_rounded, size: 14),
                  onPressed: () => _aplicarPredefinicao('192.168.0.22'),
                ),
                ActionChip(
                  label: const Text('10.0.2.2 (Emulador)', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.phone_android_rounded, size: 14),
                  onPressed: () => _aplicarPredefinicao('10.0.2.2'),
                ),
                ActionChip(
                  label: const Text('localhost', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.computer_rounded, size: 14),
                  onPressed: () => _aplicarPredefinicao('localhost'),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Botao de Buscar na Rede Wi-Fi
            OutlinedButton.icon(
              onPressed: (_testando || _buscandoRede) ? null : _buscarNaRede,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.paletaRoxo,
                side: const BorderSide(color: AppColors.paletaRoxo),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _buscandoRede
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.paletaRoxo,
                      ),
                    )
                  : const Icon(Icons.wifi_find_rounded, size: 18),
              label: Text(
                _buscandoRede
                    ? 'Procurando servidor no Wi-Fi...'
                    : 'Detectar Servidor na Rede Wi-Fi',
              ),
            ),

            const SizedBox(height: 8),

            // Botao de Testar Conexao
            OutlinedButton.icon(
              onPressed: (_testando || _buscandoRede) ? null : _executarTeste,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.verdeEscuro,
                side: const BorderSide(color: AppColors.verde),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _testando
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.verdeEscuro,
                      ),
                    )
                  : const Icon(Icons.network_check_rounded, size: 18),
              label: Text(_testando ? 'Testando conexão...' : 'Testar Conexão'),
            ),

            // Resultado do teste
            if (_resultadoTeste != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _resultadoTeste!.sucesso
                      ? AppColors.paletaVerdeSuave
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _resultadoTeste!.sucesso
                        ? AppColors.verde
                        : AppColors.vermelho,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _resultadoTeste!.sucesso
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 18,
                      color: _resultadoTeste!.sucesso
                          ? AppColors.verdeEscuro
                          : AppColors.vermelho,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resultadoTeste!.mensagem,
                        style: TextStyle(
                          fontSize: 12,
                          color: _resultadoTeste!.sucesso
                              ? AppColors.verdeEscuro
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (AppConfig.temUrlCustomizada) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _salvando ? null : _restaurarPadrao,
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text(
                    'Restaurar padrão da plataforma',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvando ? null : _salvar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.verde,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(_salvando ? 'Salvando...' : 'Salvar e Aplicar'),
        ),
      ],
    );
  }
}
