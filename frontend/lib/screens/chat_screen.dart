/// Tela de Chat (tela 14 do prototipo).
///
/// Layout reproduzido:
///   - Cabecalho com gradiente verde -> roxo, botao voltar circular,
///     nome do contato em negrito e o papel ("Nutricionista") abaixo.
///   - Mensagens recebidas: balao branco a esquerda, com o nome do
///     remetente em cinza acima do texto e o horario abaixo.
///   - Mensagens enviadas: balao com gradiente a direita, texto branco.
///   - Barra inferior: clipe de anexo, campo arredondado
///     "Digite sua mensagem..." e botao circular de enviar.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/theme.dart';
import '../models/mensagem.dart';
import '../services/chat_service.dart';
import '../widgets/common.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatService,
    required this.idUsuario,
    required this.idContato,
    this.nomeContato,
    this.papelContato,
  });

  final ChatService chatService;

  /// Usuario logado (remetente das mensagens enviadas).
  final String idUsuario;

  /// Interlocutor da conversa.
  final String idContato;

  /// Quando informados, evitam o "pulo" do cabecalho durante a carga.
  final String? nomeContato;
  final String? papelContato;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _campo = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<Mensagem> _mensagens = [];
  Contato? _contato;
  bool _carregando = true;
  bool _enviando = false;
  String? _erro;
  Timer? _timerPolling;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _timerPolling?.cancel();
    _campo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Carga inicial da conversa.
  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final conversa = await widget.chatService.carregarConversa(
        idContato: widget.idContato,
      );
      if (!mounted) return;

      setState(() {
        _contato = conversa.contato;
        _mensagens = conversa.mensagens;
        _carregando = false;
      });

      _irParaOFim(animar: false);
      _iniciarPolling();
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _carregando = false;
      });
    }
  }

  /// Atualizacao periodica: busca apenas mensagens novas.
  void _iniciarPolling() {
    _timerPolling?.cancel();
    _timerPolling = Timer.periodic(
      AppConfig.intervaloPollingChat,
      (_) => _buscarNovas(),
    );
  }

  Future<void> _buscarNovas() async {
    if (_enviando) return;

    // Cursor: id da ULTIMA mensagem confirmada, na ordem cronologica
    // (ids do Firestore sao aleatorios, nao monotonicos). Null quando a
    // conversa ainda esta vazia (a API devolve tudo).
    String? ultimoId;
    for (final mensagem in _mensagens) {
      if (!mensagem.pendente && mensagem.idMensagem.isNotEmpty) {
        ultimoId = mensagem.idMensagem;
      }
    }

    try {
      final novas = await widget.chatService.buscarNovas(
        idContato: widget.idContato,
        ultimoId: ultimoId,
      );
      if (!mounted || novas.isEmpty) return;

      // Evita duplicar mensagens que o proprio app acabou de enviar.
      final idsConhecidos = _mensagens.map((m) => m.idMensagem).toSet();
      final adicionar =
          novas.where((m) => !idsConhecidos.contains(m.idMensagem)).toList();
      if (adicionar.isEmpty) return;

      setState(() => _mensagens = [..._mensagens, ...adicionar]);
      _irParaOFim();
    } on ApiException {
      // Falha de polling e silenciosa: a proxima tentativa pode funcionar
      // e um erro de rede transitorio nao deve interromper a leitura.
    }
  }

  /// Envio otimista: mostra o balao imediatamente e substitui pelo
  /// registro real quando o servidor confirma.
  Future<void> _enviar() async {
    final texto = _campo.text.trim();
    if (texto.isEmpty || _enviando) return;

    // Id temporario, nunca colide com ids do Firestore.
    final idTemporario = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    final otimista = Mensagem(
      idMensagem: idTemporario,
      idRemetente: widget.idUsuario,
      idDestinatario: widget.idContato,
      nomeRemetente: '',
      texto: texto,
      dataHora: DateTime.now(),
      ehMinha: true,
      pendente: true,
    );

    setState(() {
      _mensagens = [..._mensagens, otimista];
      _campo.clear();
      _enviando = true;
    });
    _irParaOFim();

    try {
      final salva = await widget.chatService.enviar(
        idContato: widget.idContato,
        texto: texto,
      );
      if (!mounted) return;

      setState(() {
        _mensagens = _mensagens
            .map((m) => m.idMensagem == idTemporario ? salva : m)
            .toList();
        _enviando = false;
      });
    } on ApiException catch (erro) {
      if (!mounted) return;

      // Remove o balao otimista e devolve o texto ao campo.
      setState(() {
        _mensagens =
            _mensagens.where((m) => m.idMensagem != idTemporario).toList();
        _campo.text = texto;
        _enviando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel enviar: ${erro.mensagem}'),
          backgroundColor: AppColors.vermelho,
        ),
      );
    }
  }

  void _irParaOFim({bool animar = true}) {
    // Aguarda o frame para que a lista ja tenha a nova extensao.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final destino = _scroll.position.maxScrollExtent;
      if (animar) {
        _scroll.animateTo(
          destino,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(destino);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nome = _contato?.nome ?? widget.nomeContato ?? 'Conversa';
    final papel = _contato?.papel ?? widget.papelContato;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          GradientHeader(
            titulo: nome,
            subtitulo: papel,
            icone: Icons.chat_bubble_outline,
            gradiente: AppColors.gradienteChat,
            aoVoltar: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: _corpo()),
          _barraEnvio(),
        ],
      ),
    );
  }

  Widget _corpo() {
    if (_carregando) return const CarregandoView();
    if (_erro != null) return ErroView(mensagem: _erro!, aoTentar: _carregar);

    if (_mensagens.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nenhuma mensagem ainda.\nEnvie a primeira para iniciar a conversa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSuave, fontSize: 13.5),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      itemCount: _mensagens.length,
      itemBuilder: (context, indice) {
        final mensagem = _mensagens[indice];
        // O nome do remetente aparece so na primeira de uma sequencia.
        final anterior = indice > 0 ? _mensagens[indice - 1] : null;
        final mostrarNome = !mensagem.ehMinha &&
            (anterior == null || anterior.idRemetente != mensagem.idRemetente);

        return _BalaoMensagem(mensagem: mensagem, mostrarNome: mostrarNome);
      },
    );
  }

  Widget _barraEnvio() {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Anexo: presente no prototipo, sem funcao definida nele.
              IconButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Envio de anexos nao faz parte desta entrega.'),
                  ),
                ),
                icon: const Icon(Icons.attach_file_rounded),
                color: AppColors.textoSuave,
                iconSize: 22,
              ),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 110),
                  child: TextField(
                    controller: _campo,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviar(),
                    style: TextStyle(
                      fontSize: 14,
                      color: escuro ? AppColors.paletaClaro : AppColors.texto,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      hintStyle: const TextStyle(
                        color: AppColors.textoFraco,
                        fontSize: 14,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor:
                          escuro ? AppColors.paletaEscuro : AppColors.branco,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: escuro ? AppColors.bordaEscura : AppColors.borda,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.verde),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _BotaoEnviar(aoTocar: _enviar, enviando: _enviando),
            ],
          ),
        ),
      ),
    );
  }
}

/// Balao de mensagem. Recebida = branca/escura a esquerda,
/// enviada = gradiente a direita.
class _BalaoMensagem extends StatelessWidget {
  const _BalaoMensagem({required this.mensagem, required this.mostrarNome});

  final Mensagem mensagem;
  final bool mostrarNome;

  @override
  Widget build(BuildContext context) {
    final minha = mensagem.ehMinha;
    final larguraMaxima = MediaQuery.of(context).size.width * 0.75;
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        // Leve transparencia enquanto o servidor nao confirmou o envio.
        opacity: mensagem.pendente ? 0.7 : 1,
        child: Container(
          constraints: BoxConstraints(maxWidth: larguraMaxima),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: minha
                ? null
                : (escuro ? AppColors.paletaEscuroCard : AppColors.branco),
            gradient: minha ? AppColors.gradienteChat : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppSizes.baloesRadius),
              topRight: const Radius.circular(AppSizes.baloesRadius),
              bottomLeft: Radius.circular(minha ? AppSizes.baloesRadius : 4),
              bottomRight: Radius.circular(minha ? 4 : AppSizes.baloesRadius),
            ),
            border: minha || !escuro
                ? null
                : Border.all(color: AppColors.bordaEscura),
            boxShadow: minha || escuro ? null : kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mostrarNome) ...[
                Text(
                  mensagem.nomeRemetente,
                  style: TextStyle(
                    fontSize: 11,
                    color: escuro
                        ? AppColors.fonteSubtituloClaro
                        : AppColors.textoSuave,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                mensagem.texto,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: minha
                      ? Colors.white
                      : (escuro ? AppColors.paletaClaro : AppColors.texto),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mensagem.horaFormatada,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: minha
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textoFraco,
                    ),
                  ),
                  if (mensagem.pendente) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 9,
                      height: 9,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.4,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botao circular de enviar, com o mesmo gradiente do cabecalho.
class _BotaoEnviar extends StatelessWidget {
  const _BotaoEnviar({required this.aoTocar, required this.enviando});

  final VoidCallback aoTocar;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        gradient: AppColors.gradienteChat,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enviando ? null : aoTocar,
          child: Center(
            child: enviando
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }
}
