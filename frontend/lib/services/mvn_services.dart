/// Servicos do onboarding, do cardapio do paciente e do painel do
/// nutricionista.
library;

import '../core/api_client.dart';
import '../models/cardapio.dart';
import '../models/usuario.dart';

/// Onboarding do paciente (telas 4.5.5 a 4.5.11) e edicao de perfil.
class OnboardingService {
  OnboardingService(this._api);

  final ApiClient _api;

  /// Etapa 1: nutricionistas disponiveis.
  Future<List<NutricionistaResumo>> listarNutricionistas() async {
    final resposta = await _api.get('/onboarding/nutricionistas');
    return lerLista(resposta, 'nutricionistas', NutricionistaResumo.fromJson);
  }

  /// Etapa 1: escolher nutricionista.
  Future<void> escolherNutricionista(String uidNutricionista) async {
    await _api.post('/onboarding/nutricionista',
        corpo: {'uidNutricionista': uidNutricionista});
  }

  /// Etapa 2: dados pessoais.
  Future<Usuario> salvarDadosPessoais({
    required int idade,
    required double pesoAtual,
    required double altura,
    required String genero,
    String? meta,
    double? pesoMeta,
  }) async {
    final resposta = await _api.post('/onboarding/dados-pessoais', corpo: {
      'idade': idade,
      'pesoAtual': pesoAtual,
      'altura': altura,
      'genero': genero,
      if (meta != null) 'meta': meta,
      if (pesoMeta != null) 'pesoMeta': pesoMeta,
    });
    return _perfil(resposta);
  }

  /// Etapa 3: nivel de atividade + objetivo.
  Future<Usuario> salvarEstiloVida({
    required String nivelAtividade,
    required String meta,
  }) async {
    final resposta = await _api.post('/onboarding/estilo-vida', corpo: {
      'nivelAtividade': nivelAtividade,
      'meta': meta,
    });
    return _perfil(resposta);
  }

  /// Etapa 4: perfil alimentar.
  Future<Usuario> salvarPerfilAlimentar({
    required String tipoDieta,
    List<String> favoritos = const [],
    List<String> rejeitados = const [],
  }) async {
    final resposta = await _api.post('/onboarding/perfil-alimentar', corpo: {
      'tipoDieta': tipoDieta,
      'alimentosFavoritos': favoritos,
      'alimentosRejeitados': rejeitados,
    });
    return _perfil(resposta);
  }

  /// Etapa 5: restricoes + condicoes.
  Future<Usuario> salvarRestricoes({
    List<String> restricoes = const [],
    List<String> condicoesMedicas = const [],
  }) async {
    final resposta = await _api.post('/onboarding/restricoes', corpo: {
      'restricoes': restricoes,
      'condicoesMedicas': condicoesMedicas,
    });
    return _perfil(resposta);
  }

  /// Etapa 6: conclui o tutorial interativo.
  Future<void> concluirTutorial() async {
    await _api.post('/onboarding/tutorial');
  }

  /// PUT /api/perfil/perfil - edicao livre (tela 4.5.19).
  Future<Usuario> atualizarPerfil(Map<String, dynamic> campos) async {
    final resposta = await _api.put('/perfil/perfil', corpo: campos);
    return _perfil(resposta);
  }

  /// Atualiza configuracoes de privacidade do paciente.
  Future<Usuario> atualizarPrivacidade({
    bool? compartilharListaCompras,
    bool? compartilharHumor,
  }) async {
    final resposta = await _api.put('/perfil/perfil', corpo: {
      if (compartilharListaCompras != null)
        'compartilharListaCompras': compartilharListaCompras,
      if (compartilharHumor != null) 'compartilharHumor': compartilharHumor,
    });
    return _perfil(resposta);
  }

  /// Atualiza dados de seguranca alimentar (restricoes clinicas).
  Future<Usuario> atualizarSegurancaAlimentar({
    List<String>? restricoes,
    List<String>? condicoesMedicas,
    String? observacoesSeguranca,
  }) async {
    final resposta = await _api.put('/perfil/perfil', corpo: {
      if (restricoes != null) 'restricoes': restricoes,
      if (condicoesMedicas != null) 'condicoesMedicas': condicoesMedicas,
      if (observacoesSeguranca != null)
        'observacoesSeguranca': observacoesSeguranca,
    });
    return _perfil(resposta);
  }

  /// Atualiza preferencias alimentares e habitos.
  Future<Usuario> atualizarPreferencias({
    String? tipoDieta,
    List<String>? favoritos,
    List<String>? rejeitados,
  }) async {
    final resposta = await _api.put('/perfil/perfil', corpo: {
      if (tipoDieta != null) 'tipoDieta': tipoDieta,
      if (favoritos != null) 'alimentosFavoritos': favoritos,
      if (rejeitados != null) 'alimentosRejeitados': rejeitados,
    });
    return _perfil(resposta);
  }

  Usuario _perfil(Map<String, dynamic> resposta) {
    final dados = resposta['dados'];
    final perfil = dados is Map ? dados['perfil'] : null;
    if (perfil is! Map<String, dynamic>) {
      throw ApiException('Resposta inesperada ao salvar o perfil.');
    }
    try {
      return Usuario.fromJson(perfil);
    } catch (erro) {
      throw ApiException('Formato inesperado no perfil devolvido: $erro');
    }
  }
}

/// Cardapio do paciente: aba do dia, plano semanal, checklist, agua,
/// humor, lista de compras e receitas proprias.
class CardapioService {
  CardapioService(this._api);

  final ApiClient _api;

  /// Refeicoes de hoje + resumo do checklist.
  Future<CardapioDoDia> carregarHoje() async {
    final resposta = await _api.get('/cardapio/hoje');
    return lerDados(resposta, CardapioDoDia.fromJson);
  }

  /// Plano semanal completo.
  Future<PlanoSemanal> carregarSemanal() async {
    final resposta = await _api.get('/cardapio/semanal');
    return lerDados(resposta, PlanoSemanal.fromJson);
  }

  /// Marca/desmarca refeicao concluida.
  Future<ResumoChecklist> alternarRefeicao({
    required String dia,
    required String tipo,
    required bool concluida,
  }) async {
    final resposta = await _api.post('/cardapio/hoje/check', corpo: {
      'dia': dia,
      'tipo': tipo,
      'concluida': concluida,
    });
    return lerDados(
      resposta,
      (dados) => ResumoChecklist.fromJson(
        (dados['resumo'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  /// Lista de compras gerada do plano + itens manuais.
  Future<List<ItemCompra>> carregarListaCompras() async {
    final resposta = await _api.get('/cardapio/lista-compras');
    return lerLista(resposta, 'itens', ItemCompra.fromJson);
  }

  /// Adiciona item personalizado a lista de compras.
  Future<ItemCompra> adicionarItemListaCompras({
    required String nome,
    String categoria = 'Outros',
    double quantidade = 1,
    String unidade = 'un',
  }) async {
    final resposta = await _api.post('/cardapio/lista-compras/item', corpo: {
      'nome': nome,
      'categoria': categoria,
      'quantidade': quantidade,
      'unidade': unidade,
    });
    return lerDados(resposta, (d) => ItemCompra.fromJson(d['item'] as Map<String, dynamic>));
  }

  /// Remove item manual da lista de compras.
  Future<void> removerItemListaCompras(String idItem) async {
    await _api.delete('/cardapio/lista-compras/item/$idItem');
  }

  /// Alterna status comprado de um item manual.
  Future<void> alternarItemListaCompras(String idItem, bool comprado) async {
    await _api.post('/cardapio/lista-compras/item/$idItem/toggle', corpo: {
      'comprado': comprado,
    });
  }

  /// Minhas Receitas (enviadas pelo paciente).
  Future<List<Receita>> minhasReceitas() async {
    final resposta = await _api.get('/minhas-receitas');
    return lerLista(resposta, 'receitas', Receita.fromJson);
  }

  /// Paciente compartilha receita para aprovacao.
  Future<void> compartilharReceita({
    required String nome,
    required List<Ingrediente> ingredientes,
    String modoPreparo = '',
  }) async {
    await _api.post('/minhas-receitas', corpo: {
      'nome': nome,
      'modoPreparo': modoPreparo,
      'ingredientes': ingredientes.map((i) => i.toJson()).toList(),
    });
  }

  /// Base de alimentos (catalogo publico) para montar a receita.
  Future<List<Alimento>> listarAlimentos() async {
    final resposta = await _api.get('/alimentos');
    return lerLista(resposta, 'alimentos', Alimento.fromJson);
  }

  /// Consultas da agenda do usuario.
  Future<List<Consulta>> listarConsultas() async {
    final resposta = await _api.get('/consultas');
    return lerLista(resposta, 'consultas', Consulta.fromJson);
  }

  /// Paciente solicita agendamento em um horario disponivel.
  Future<void> solicitarConsulta(String idConsulta) async {
    await _api.post('/consultas/$idConsulta/solicitar');
  }

  /// Paciente confirma um horario disponivel diretamente (legado).
  Future<void> confirmarConsulta(String idConsulta) async {
    await _api.post('/consultas/$idConsulta/confirmar');
  }

  /// Orientacoes recebidas (aba Orientacoes de "Meu nutricionista").
  Future<List<Orientacao>> listarOrientacoes() async {
    final resposta = await _api.get('/orientacoes');
    return lerLista(resposta, 'orientacoes', Orientacao.fromJson);
  }

  /// Marca orientacao como confirmada/ciente.
  Future<void> confirmarOrientacao(String idOrientacao) async {
    await _api.post('/orientacoes/$idOrientacao/confirmar');
  }
}

/// Painel do nutricionista.
class NutricionistaService {
  NutricionistaService(this._api);

  final ApiClient _api;
  ApiClient get api => _api;

  /// Pacientes vinculados com resumo clinico.
  Future<List<PacienteResumo>> listarPacientes() async {
    final resposta = await _api.get('/nutricionista/pacientes');
    return lerLista(resposta, 'pacientes', PacienteResumo.fromJson);
  }

  /// Solicitações pendentes de atendimento recebidas pelo nutricionista.
  Future<List<PacienteResumo>> listarSolicitacoes() async {
    final resposta = await _api.get('/nutricionista/solicitacoes');
    return lerLista(resposta, 'solicitacoes', PacienteResumo.fromJson);
  }

  /// Aceita uma solicitacao de atendimento pendente.
  Future<void> aceitarSolicitacao(String uidPaciente) async {
    await _api.post('/nutricionista/solicitacoes/$uidPaciente/aceitar');
  }

  /// Recusa uma solicitacao de atendimento.
  Future<void> recusarSolicitacao(String uidPaciente) async {
    await _api.post('/nutricionista/solicitacoes/$uidPaciente/recusar');
  }

  /// Vincula paciente existente por e-mail.
  Future<void> vincularPaciente(String email) async {
    await _api.post('/nutricionista/pacientes', corpo: {'email': email});
  }

  /// Consulta lista de compras do paciente (respeitando privacidade).
  Future<Map<String, dynamic>> obterListaComprasPaciente(String uidPaciente) async {
    final resposta = await _api.get('/nutricionista/pacientes/$uidPaciente/lista-compras');
    return lerDados(resposta, (d) => d);
  }

  /// Plano do paciente para edicao (cria o primeiro se necessario).
  Future<Map<String, dynamic>> carregarPlano(String uidPaciente) async {
    final resposta = await _api.get('/nutricionista/pacientes/$uidPaciente/plano');
    return lerDados(
      resposta,
      (dados) => dados,
    );
  }

  /// Wizard passo 3: define a receita de uma refeicao.
  Future<void> definirRefeicao({
    required String uidPaciente,
    required String dia,
    required String tipo,
    required String idReceita,
    String? horario,
  }) async {
    await _api.post(
      '/nutricionista/pacientes/$uidPaciente/plano/refeicoes',
      corpo: {
        'dia': dia,
        'tipo': tipo,
        'idReceita': idReceita,
        if (horario != null) 'horario': horario,
      },
    );
  }

  /// Remove uma refeicao do plano.
  Future<void> removerRefeicao({
    required String uidPaciente,
    required String dia,
    required String tipo,
  }) async {
    await _api.delete(
      '/nutricionista/pacientes/$uidPaciente/plano/refeicoes',
      query: {'dia': dia, 'tipo': tipo},
    );
  }

  /// Renomeia plano / ajusta objetivo.
  Future<void> atualizarPlano({
    required String uidPaciente,
    String? nomePlano,
    String? objetivo,
  }) async {
    await _api.put('/nutricionista/pacientes/$uidPaciente/plano', corpo: {
      if (nomePlano != null) 'nomePlano': nomePlano,
      if (objetivo != null) 'objetivo': objetivo,
    });
  }

  /// Biblioteca de receitas do nutricionista.
  Future<List<Receita>> listarReceitas() async {
    final resposta = await _api.get('/nutricionista/receitas');
    return lerLista(resposta, 'receitas', Receita.fromJson);
  }

  /// Cria/atualiza receita (macros calculados pela API).
  Future<void> salvarReceita({
    String? idReceita,
    required String nome,
    required List<Ingrediente> ingredientes,
    String modoPreparo = '',
  }) async {
    await _api.post('/nutricionista/receitas', corpo: {
      if (idReceita != null) 'idReceita': idReceita,
      'nome': nome,
      'modoPreparo': modoPreparo,
      'ingredientes': ingredientes.map((i) => i.toJson()).toList(),
    });
  }

  /// Receitas compartilhadas aguardando avaliacao.
  Future<List<Receita>> listarReceitasPendentes() async {
    final resposta = await _api.get('/nutricionista/receitas/pendentes');
    return lerLista(resposta, 'receitas', Receita.fromJson);
  }

  /// Aprova/recusa receita compartilhada.
  Future<void> avaliarReceita({
    required String idReceita,
    required String status,
    String justificativa = '',
  }) async {
    await _api.post('/nutricionista/receitas/$idReceita/avaliar', corpo: {
      'status': status,
      if (justificativa.isNotEmpty) 'justificativa': justificativa,
    });
  }

  /// Base de alimentos para montar receitas.
  Future<List<Alimento>> listarAlimentos() async {
    final resposta = await _api.get('/nutricionista/alimentos');
    return lerLista(resposta, 'alimentos', Alimento.fromJson);
  }

  /// Relatorios e analise (4.5.27).
  Future<List<RelatorioPaciente>> carregarRelatorios() async {
    final resposta = await _api.get('/nutricionista/relatorios');
    return lerLista(resposta, 'relatorios', RelatorioPaciente.fromJson);
  }

  /// Envia orientacao/feedback a um paciente.
  Future<void> enviarOrientacao({
    required String uidPaciente,
    required String categoria,
    required String texto,
  }) async {
    await _api.post('/nutricionista/orientacoes', corpo: {
      'uidPaciente': uidPaciente,
      'categoria': categoria,
      'texto': texto,
    });
  }

  /// Cria um horario disponivel na agenda.
  Future<void> criarConsulta({
    required DateTime dataHora,
    String observacoes = '',
  }) async {
    await _api.post('/consultas', corpo: {
      'dataHora': dataHora.toUtc().toIso8601String(),
      'observacoes': observacoes,
    });
  }

  /// Edita um horario na agenda.
  Future<void> editarConsulta(
    String idConsulta, {
    DateTime? dataHora,
    String? observacoes,
  }) async {
    await _api.put('/consultas/$idConsulta', corpo: {
      if (dataHora != null) 'dataHora': dataHora.toUtc().toIso8601String(),
      if (observacoes != null) 'observacoes': observacoes,
    });
  }

  /// Cria multiplos horarios disponiveis na agenda de uma vez.
  Future<void> criarHorariosLote({
    required List<DateTime> horarios,
    String observacoes = '',
  }) async {
    await _api.post('/consultas/lote', corpo: {
      'horarios': horarios.map((h) => h.toUtc().toIso8601String()).toList(),
      'observacoes': observacoes,
    });
  }

  /// Agenda do nutricionista (consultas ativas em que participa).
  Future<List<Consulta>> listarConsultas() async {
    final resposta = await _api.get('/consultas');
    return lerLista(resposta, 'consultas', Consulta.fromJson);
  }

  /// Historico de consultas concluidas/comparecidas.
  Future<List<Consulta>> listarHistoricoConsultas() async {
    final resposta = await _api.get('/consultas/historico');
    return lerLista(resposta, 'consultas', Consulta.fromJson);
  }

  /// Nutricionista aprova pedido de agendamento de consulta.
  Future<void> aprovarConsulta(String idConsulta) async {
    await _api.post('/consultas/$idConsulta/aprovar');
  }

  /// Nutricionista recusa pedido de agendamento de consulta.
  Future<void> recusarConsulta(String idConsulta) async {
    await _api.post('/consultas/$idConsulta/recusar');
  }

  /// Marca consulta como concluida.
  Future<void> concluirConsulta(String idConsulta) async {
    await _api.post('/consultas/$idConsulta/concluir');
  }

  /// Cancela a consulta (ou remove o horario livre) da agenda.
  Future<void> cancelarConsulta(String idConsulta) async {
    await _api.post('/consultas/$idConsulta/cancelar');
  }
}

