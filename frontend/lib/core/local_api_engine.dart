/// Motor de API integrado ao aplicativo (Modo Autonomo / Cloud + Persistência Local).
///
/// Quando o APK Android e instalado em um celular fisico e o servidor Node.js
/// local (ex.: 10.0.2.2:3000 ou IP da rede Wi-Fi) nao esta acessivel, este
/// motor processa todas as rotas da API REST diretamente no dispositivo,
/// mantendo os dados persistidos em [SharedPreferences] e sincronizados com a
/// sessao real do [FirebaseAuth].
///
/// Assim, o aplicativo funciona em qualquer celular (4G/5G ou Wi-Fi) sem
/// depender de um computador ligado na mesma rede.
library;

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class LocalApiEngine {
  LocalApiEngine._();

  static final LocalApiEngine instance = LocalApiEngine._();

  static const String _chaveBancoLocal = 'mvn_local_api_db_v2';
  static const int _limiteGratuito = 15;
  static const double _precoPro = 29.90;

  static const List<String> _diasSemana = <String>[
    'segunda',
    'terca',
    'quarta',
    'quinta',
    'sexta',
    'sabado',
    'domingo',
  ];

  static const Map<String, String> _rotulosDia = <String, String>{
    'segunda': 'Segunda-feira',
    'terca': 'Terça-feira',
    'quarta': 'Quarta-feira',
    'quinta': 'Quinta-feira',
    'sexta': 'Sexta-feira',
    'sabado': 'Sábado',
    'domingo': 'Domingo',
  };

  static const List<String> _tiposRefeicao = <String>[
    'cafeManha',
    'lancheManha',
    'almoco',
    'lancheTarde',
    'jantar',
    'ceia',
  ];

  static const Map<String, String> _rotulosRefeicao = <String, String>{
    'cafeManha': 'Café da Manhã',
    'lancheManha': 'Lanche da Manhã',
    'almoco': 'Almoço',
    'lancheTarde': 'Lanche da Tarde',
    'jantar': 'Jantar',
    'ceia': 'Ceia',
  };

  static const Map<String, String> _horariosPadrao = <String, String>{
    'cafeManha': '07:30',
    'lancheManha': '10:00',
    'almoco': '12:30',
    'lancheTarde': '16:00',
    'jantar': '19:30',
    'ceia': '21:30',
  };

  Map<String, dynamic>? _db;

  Future<Map<String, dynamic>> _carregarDb() async {
    if (_db != null) return _db!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final bruto = prefs.getString(_chaveBancoLocal);
      if (bruto != null && bruto.isNotEmpty) {
        final decodificado = jsonDecode(bruto);
        if (decodificado is Map<String, dynamic>) {
          _db = decodificado;
          _garantirEstrutura(_db!);
          return _db!;
        }
      }
    } catch (_) {}

    _db = _criarSeedInicial();
    await _salvarDb();
    return _db!;
  }

  Future<void> _salvarDb() async {
    final dbAtual = _db;
    if (dbAtual == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveBancoLocal, jsonEncode(dbAtual));
    } catch (_) {}
  }

  void _garantirEstrutura(Map<String, dynamic> db) {
    db['usuarios'] ??= <String, dynamic>{};
    db['fotos'] ??= <String, dynamic>{};
    db['alimentos'] ??= _alimentosIniciais();
    db['receitas'] ??= _receitasIniciais();
    db['planos'] ??= <String, dynamic>{};
    db['progresso'] ??= <String, dynamic>{};
    db['consultas'] ??= <dynamic>[];
    db['orientacoes'] ??= <dynamic>[];
    db['mensagens'] ??= <dynamic>[];
  }

  Map<String, dynamic> _usuarioFirebaseAtual() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return <String, dynamic>{
          'uid': user.uid,
          'email': (user.email ?? 'usuario@mvn.com').toLowerCase(),
          'nome': (user.displayName != null && user.displayName!.trim().isNotEmpty)
              ? user.displayName!.trim()
              : (user.email?.split('@').first ?? 'Usuário MVN'),
          'emailVerificado': user.emailVerified,
        };
      }
    } catch (_) {}
    return <String, dynamic>{
      'uid': 'paciente_ana',
      'email': 'ana@mvn.com',
      'nome': 'Ana Carolina Silva',
      'emailVerificado': true,
    };
  }

  Map<String, dynamic> _obterOuCriarPerfilAtual(Map<String, dynamic> db) {
    final sessao = _usuarioFirebaseAtual();
    final uid = sessao['uid'] as String;
    final email = (sessao['email'] as String).toLowerCase();
    final nome = sessao['nome'] as String;
    final usuarios = db['usuarios'] as Map<String, dynamic>;

    if (usuarios[uid] is Map<String, dynamic>) {
      final existente = usuarios[uid] as Map<String, dynamic>;
      existente['emailVerificado'] = sessao['emailVerificado'] == true;
      return existente;
    }

    // Procura por e-mail caso ja exista no seed
    for (final entrada in usuarios.entries) {
      final dados = entrada.value;
      if (dados is Map<String, dynamic> &&
          (dados['email']?.toString().toLowerCase() == email)) {
        final copia = Map<String, dynamic>.from(dados);
        copia['uid'] = uid;
        copia['emailVerificado'] = sessao['emailVerificado'] == true;
        usuarios[uid] = copia;
        return copia;
      }
    }

    final ehNutri = email.startsWith('nutri') ||
        email.startsWith('nteste') ||
        email.startsWith('dr');

    final novo = _criarDocumentoUsuario(
      uid: uid,
      nome: nome,
      email: email,
      tipoUsuario: ehNutri ? 'nutricionista' : 'paciente',
      crn: ehNutri ? 'CRN-3 45821' : null,
      especializacao: ehNutri ? 'Nutrição Clínica e Esportiva' : null,
      emailVerificado: sessao['emailVerificado'] == true,
    );
    usuarios[uid] = novo;
    if (ehNutri) {
      _vincularDadosIniciaisAoNutricionista(db, uid, nome);
    } else {
      _garantirPlanoParaPaciente(db, uid, 'nutri_gabriel');
      _garantirProgressoInicial(db, uid, 68.5);
    }
    return novo;
  }

  /// Processa qualquer requisicao REST da aplicacao localmente.
  Future<Map<String, dynamic>> processar(
    String metodo,
    String caminho, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? corpo,
  }) async {
    final db = await _carregarDb();
    final m = metodo.toUpperCase();
    final body = corpo ?? const <String, dynamic>{};
    final q = query ?? const <String, dynamic>{};

    if (caminho == '/health') {
      return _ok(<String, dynamic>{
        'status': 'online',
        'banco': 'ok',
        'modo': 'integrado',
      });
    }

    // ---------------- AUTENTICACAO & CADASTRO ----------------
    if (m == 'POST' && caminho == '/auth/cadastro/paciente') {
      final sessao = _usuarioFirebaseAtual();
      final uid = sessao['uid'] as String;
      final nome = (body['nome']?.toString().trim().isNotEmpty == true)
          ? body['nome'].toString().trim()
          : (sessao['nome'] as String);
      final email = (body['email']?.toString().trim().isNotEmpty == true)
          ? body['email'].toString().trim().toLowerCase()
          : (sessao['email'] as String);

      final usuarios = db['usuarios'] as Map<String, dynamic>;
      final perfil = _criarDocumentoUsuario(
        uid: uid,
        nome: nome,
        email: email,
        tipoUsuario: 'paciente',
        telefone: body['telefone']?.toString(),
        onboardingCompleto: false,
        emailVerificado: sessao['emailVerificado'] == true,
      );
      usuarios[uid] = perfil;
      _garantirPlanoParaPaciente(db, uid, 'nutri_gabriel');
      await _salvarDb();
      return _ok(_perfilParaJson(perfil));
    }

    if (m == 'POST' && caminho == '/auth/cadastro/nutricionista') {
      final sessao = _usuarioFirebaseAtual();
      final uid = sessao['uid'] as String;
      final nome = (body['nome']?.toString().trim().isNotEmpty == true)
          ? body['nome'].toString().trim()
          : (sessao['nome'] as String);
      final email = (body['email']?.toString().trim().isNotEmpty == true)
          ? body['email'].toString().trim().toLowerCase()
          : (sessao['email'] as String);
      final crn = (body['crn']?.toString().trim().isNotEmpty == true)
          ? body['crn'].toString().trim()
          : 'CRN-3 12345';

      final usuarios = db['usuarios'] as Map<String, dynamic>;
      final perfil = _criarDocumentoUsuario(
        uid: uid,
        nome: nome,
        email: email,
        tipoUsuario: 'nutricionista',
        telefone: body['telefone']?.toString(),
        crn: crn,
        especializacao: body['especializacao']?.toString() ??
            'Nutrição Clínica e Funcional',
        onboardingCompleto: true,
        emailVerificado: sessao['emailVerificado'] == true,
      );
      usuarios[uid] = perfil;
      _vincularDadosIniciaisAoNutricionista(db, uid, nome);
      await _salvarDb();
      return _ok(_perfilParaJson(perfil));
    }

    if (m == 'GET' && caminho == '/auth/perfil') {
      final perfil = _obterOuCriarPerfilAtual(db);
      await _salvarDb();
      return _ok(_perfilParaJson(perfil));
    }

    // ---------------- PERFIL & FOTO ----------------
    if (m == 'GET' && caminho == '/perfil/foto') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final fotos = db['fotos'] as Map<String, dynamic>;
      final foto = fotos[perfil['uid']];
      return _ok(<String, dynamic>{'foto': foto});
    }

    if (m == 'PUT' && caminho == '/perfil/foto') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final fotos = db['fotos'] as Map<String, dynamic>;
      fotos[perfil['uid'] as String] = <String, dynamic>{
        'mimeType': body['mimeType'] ?? 'image/jpeg',
        'dadosBase64': body['dadosBase64'] ?? '',
      };
      await _salvarDb();
      return _ok(<String, dynamic>{'atualizado': true});
    }

    if (m == 'PUT' && caminho == '/perfil/perfil') {
      final perfil = _obterOuCriarPerfilAtual(db);
      _mesclarCamposPerfil(perfil, body);
      if (body['pesoAtual'] is num) {
        _registrarPesoInterno(
          db,
          perfil['uid'] as String,
          (body['pesoAtual'] as num).toDouble(),
          null,
        );
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'perfil': _perfilParaJson(perfil)});
    }

    if (m == 'DELETE' && caminho == '/perfil/perfil') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final uid = perfil['uid'] as String;
      (db['usuarios'] as Map<String, dynamic>).remove(uid);
      (db['fotos'] as Map<String, dynamic>).remove(uid);
      await _salvarDb();
      return _ok(<String, dynamic>{'excluido': true});
    }

    // ---------------- ONBOARDING ----------------
    if (m == 'GET' && caminho == '/onboarding/nutricionistas') {
      final usuarios = db['usuarios'] as Map<String, dynamic>;
      final nutris = usuarios.values
          .whereType<Map<String, dynamic>>()
          .where((u) => u['tipoUsuario'] == 'nutricionista')
          .map((u) => <String, dynamic>{
                'uid': u['uid'],
                'nome': u['nome'],
                'crn': u['crn'],
                'especializacao': u['especializacao'],
              })
          .toList();
      return _ok(<String, dynamic>{'nutricionistas': nutris});
    }

    if (m == 'POST' && caminho == '/onboarding/nutricionista') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final uidNutri = body['uidNutricionista']?.toString() ?? 'nutri_gabriel';
      perfil['idNutricionista'] = uidNutri;
      perfil['statusVinculo'] = 'aprovado';
      _garantirPlanoParaPaciente(db, perfil['uid'] as String, uidNutri);
      await _salvarDb();
      return _ok(<String, dynamic>{'perfil': _perfilParaJson(perfil)});
    }

    if (m == 'POST' &&
        (caminho == '/onboarding/dados-pessoais' ||
            caminho == '/onboarding/estilo-vida' ||
            caminho == '/onboarding/perfil-alimentar' ||
            caminho == '/onboarding/restricoes')) {
      final perfil = _obterOuCriarPerfilAtual(db);
      _mesclarCamposPerfil(perfil, body);
      if (caminho == '/onboarding/restricoes') {
        perfil['onboardingCompleto'] = true;
      }
      if (body['pesoAtual'] is num) {
        _registrarPesoInterno(
          db,
          perfil['uid'] as String,
          (body['pesoAtual'] as num).toDouble(),
          null,
        );
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'perfil': _perfilParaJson(perfil)});
    }

    if (m == 'POST' && caminho == '/onboarding/tutorial') {
      final perfil = _obterOuCriarPerfilAtual(db);
      perfil['onboardingCompleto'] = true;
      perfil['tutorialVisto'] = true;
      await _salvarDb();
      return _ok(<String, dynamic>{'perfil': _perfilParaJson(perfil)});
    }

    // ---------------- CARDAPIO & LISTA DE COMPRAS ----------------
    if (m == 'GET' && caminho == '/cardapio/hoje') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final uid = perfil['uid'] as String;
      final plano = _garantirPlanoParaPaciente(
        db,
        uid,
        (perfil['idNutricionista'] as String?) ?? 'nutri_gabriel',
      );
      final diaHoje = _diaDaSemanaAtual();
      final refeicoesDia = _montarRefeicoesDoDia(db, plano, diaHoje);
      final resumo = _calcularResumoChecklist(refeicoesDia);
      return _ok(<String, dynamic>{
        'dia': diaHoje,
        'plano': <String, dynamic>{
          'idPlano': plano['idPlano'],
          'nomePlano': plano['nomePlano'],
          'objetivo': plano['objetivo'],
        },
        'refeicoes': refeicoesDia,
        'resumo': resumo,
      });
    }

    if (m == 'GET' && caminho == '/cardapio/semanal') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final uid = perfil['uid'] as String;
      final plano = _garantirPlanoParaPaciente(
        db,
        uid,
        (perfil['idNutricionista'] as String?) ?? 'nutri_gabriel',
      );
      return _ok(_montarPlanoSemanalPayload(db, plano));
    }

    if (m == 'POST' && caminho == '/cardapio/hoje/check') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final uid = perfil['uid'] as String;
      final plano = _garantirPlanoParaPaciente(
        db,
        uid,
        (perfil['idNutricionista'] as String?) ?? 'nutri_gabriel',
      );
      final dia = (body['dia']?.toString() ?? _diaDaSemanaAtual());
      final tipo = (body['tipo']?.toString() ?? 'cafeManha');
      final concluida = body['concluida'] == true;

      final checks =
          (plano['checks'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      checks['$dia:$tipo'] = concluida;
      plano['checks'] = checks;
      await _salvarDb();

      final refeicoesDia = _montarRefeicoesDoDia(db, plano, dia);
      final resumo = _calcularResumoChecklist(refeicoesDia);
      return _ok(<String, dynamic>{'resumo': resumo});
    }

    if (m == 'GET' && caminho == '/cardapio/lista-compras') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final uid = perfil['uid'] as String;
      final itens = _montarListaCompras(db, uid);
      return _ok(<String, dynamic>{'itens': itens});
    }

    if (m == 'POST' && caminho == '/cardapio/lista-compras/item') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final extras = (perfil['itensListaComprasExtras'] as List<dynamic>?) ??
          <dynamic>[];
      final novoItem = <String, dynamic>{
        'id': 'item_${DateTime.now().millisecondsSinceEpoch}',
        'nome': body['nome']?.toString() ?? 'Item',
        'categoria': body['categoria']?.toString() ?? 'Outros',
        'quantidadeG': (body['quantidade'] as num?)?.toDouble() ?? 1,
        'unidade': body['unidade']?.toString() ?? 'un',
        'comprado': false,
        'manual': true,
      };
      extras.add(novoItem);
      perfil['itensListaComprasExtras'] = extras;
      await _salvarDb();
      return _ok(<String, dynamic>{'item': novoItem});
    }

    if (m == 'DELETE' && caminho.startsWith('/cardapio/lista-compras/item/')) {
      final idItem = caminho.split('/').last;
      final perfil = _obterOuCriarPerfilAtual(db);
      final extras = (perfil['itensListaComprasExtras'] as List<dynamic>?) ??
          <dynamic>[];
      extras.removeWhere((i) => i is Map && i['id']?.toString() == idItem);
      perfil['itensListaComprasExtras'] = extras;
      await _salvarDb();
      return _ok(<String, dynamic>{'removido': true});
    }

    if (m == 'POST' &&
        caminho.startsWith('/cardapio/lista-compras/item/') &&
        caminho.endsWith('/toggle')) {
      final partes = caminho.split('/');
      final idItem = partes[partes.length - 2];
      final comprado = body['comprado'] == true;
      final perfil = _obterOuCriarPerfilAtual(db);
      final compradosMap =
          (perfil['itensCompradosMap'] as Map<String, dynamic>?) ??
              <String, dynamic>{};
      compradosMap[idItem] = comprado;
      perfil['itensCompradosMap'] = compradosMap;

      final extras = (perfil['itensListaComprasExtras'] as List<dynamic>?) ??
          <dynamic>[];
      for (final item in extras) {
        if (item is Map<String, dynamic> && item['id']?.toString() == idItem) {
          item['comprado'] = comprado;
        }
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'atualizado': true});
    }

    // ---------------- RECEITAS & ALIMENTOS ----------------
    if (m == 'GET' &&
        (caminho == '/alimentos' || caminho == '/nutricionista/alimentos')) {
      final alimentos = db['alimentos'] as List<dynamic>;
      return _ok(<String, dynamic>{'alimentos': alimentos});
    }

    if (m == 'GET' && caminho == '/minhas-receitas') {
      final receitas = (db['receitas'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      return _ok(<String, dynamic>{'receitas': receitas});
    }

    if (m == 'POST' && caminho == '/minhas-receitas') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final nova = _criarReceitaComMacros(
        idReceita: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        nome: body['nome']?.toString() ?? 'Receita Caseira',
        modoPreparo: body['modoPreparo']?.toString() ?? '',
        ingredientesRaw: (body['ingredientes'] as List<dynamic>?) ?? const [],
        status: 'pendente',
        autorUid: perfil['uid'] as String,
      );
      (db['receitas'] as List<dynamic>).insert(0, nova);
      await _salvarDb();
      return _ok(<String, dynamic>{'receita': nova});
    }

    if (m == 'GET' && caminho == '/nutricionista/receitas') {
      final receitas = (db['receitas'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .where((r) => r['status'] != 'recusada')
          .toList();
      return _ok(<String, dynamic>{'receitas': receitas});
    }

    if (m == 'GET' && caminho == '/nutricionista/receitas/pendentes') {
      final pendentes = (db['receitas'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .where((r) => r['status'] == 'pendente')
          .toList();
      return _ok(<String, dynamic>{'receitas': pendentes});
    }

    if (m == 'POST' && caminho == '/nutricionista/receitas') {
      final idReceita = body['idReceita']?.toString() ??
          'rec_${DateTime.now().millisecondsSinceEpoch}';
      final nova = _criarReceitaComMacros(
        idReceita: idReceita,
        nome: body['nome']?.toString() ?? 'Nova Receita',
        modoPreparo: body['modoPreparo']?.toString() ?? '',
        ingredientesRaw: (body['ingredientes'] as List<dynamic>?) ?? const [],
        status: 'aprovada',
      );
      final lista = db['receitas'] as List<dynamic>;
      final idx = lista.indexWhere(
          (r) => r is Map && r['idReceita']?.toString() == idReceita);
      if (idx >= 0) {
        lista[idx] = nova;
      } else {
        lista.insert(0, nova);
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'receita': nova});
    }

    if (m == 'POST' &&
        caminho.startsWith('/nutricionista/receitas/') &&
        caminho.endsWith('/avaliar')) {
      final partes = caminho.split('/');
      final idReceita = partes[partes.length - 2];
      final lista = db['receitas'] as List<dynamic>;
      for (final item in lista) {
        if (item is Map<String, dynamic> &&
            item['idReceita']?.toString() == idReceita) {
          item['status'] = body['status']?.toString() ?? 'aprovada';
          if (body['justificativa'] != null) {
            item['justificativa'] = body['justificativa'].toString();
          }
        }
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'avaliada': true});
    }

    // ---------------- PROGRESSO & EVOLUCAO ----------------
    if (m == 'GET' && caminho == '/progresso') {
      final perfil = _obterOuCriarPerfilAtual(db);
      return _ok(_montarProgressoPayload(db, perfil));
    }

    if (m == 'POST' && caminho == '/progresso/peso') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final peso = (body['peso'] as num?)?.toDouble() ?? 68.0;
      final data = body['dataRegistro']?.toString();
      _registrarPesoInterno(db, perfil['uid'] as String, peso, data);
      perfil['pesoAtual'] = peso;
      await _salvarDb();
      return _ok(_montarProgressoPayload(db, perfil));
    }

    if (m == 'DELETE' && caminho.startsWith('/progresso/peso/')) {
      final dataRegistro = caminho.split('/').last;
      final perfil = _obterOuCriarPerfilAtual(db);
      final uid = perfil['uid'] as String;
      final progMap = db['progresso'] as Map<String, dynamic>;
      final dadosProg =
          (progMap[uid] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final pesagens =
          (dadosProg['pesagens'] as List<dynamic>?) ?? <dynamic>[];
      pesagens.removeWhere(
          (p) => p is Map && p['idProgresso']?.toString() == dataRegistro);
      if (pesagens.isNotEmpty) {
        final ultimo = pesagens.first as Map<String, dynamic>;
        perfil['pesoAtual'] = (ultimo['peso'] as num).toDouble();
      }
      await _salvarDb();
      return _ok(_montarProgressoPayload(db, perfil));
    }

    if (m == 'POST' && caminho == '/progresso/agua') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final uid = perfil['uid'] as String;
      final prog = _garantirProgressoInicial(
        db,
        uid,
        (perfil['pesoAtual'] as num?)?.toDouble() ?? 68.5,
      );
      prog['coposAgua'] = (body['coposAgua'] as num?)?.toInt() ?? 0;
      await _salvarDb();
      return _ok(<String, dynamic>{'coposAgua': prog['coposAgua']});
    }

    if (m == 'POST' && caminho == '/progresso/humor') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final uid = perfil['uid'] as String;
      final prog = _garantirProgressoInicial(
        db,
        uid,
        (perfil['pesoAtual'] as num?)?.toDouble() ?? 68.5,
      );
      prog['humor'] = body['humor']?.toString() ?? 'bom';
      await _salvarDb();
      return _ok(<String, dynamic>{'humor': prog['humor']});
    }

    if (m == 'GET' &&
        (caminho == '/evolucao' || caminho.startsWith('/evolucao/'))) {
      final perfilAtual = _obterOuCriarPerfilAtual(db);
      final uidAlvo = caminho == '/evolucao'
          ? (perfilAtual['uid'] as String)
          : caminho.split('/').last;
      final usuarios = db['usuarios'] as Map<String, dynamic>;
      final paciente = (usuarios[uidAlvo] as Map<String, dynamic>?) ??
          perfilAtual;
      final periodo = q['periodo']?.toString() ?? 'mensal';
      return _ok(_montarEvolucaoPayload(db, paciente, periodo));
    }

    // ---------------- CHAT ----------------
    if (m == 'GET' && caminho == '/chat/contato') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final usuarios = db['usuarios'] as Map<String, dynamic>;
      if (perfil['tipoUsuario'] == 'nutricionista') {
        final uidPac = q['uidPaciente']?.toString() ?? 'paciente_ana';
        final pac = (usuarios[uidPac] as Map<String, dynamic>?) ??
            usuarios['paciente_ana'] as Map<String, dynamic>?;
        return _ok(<String, dynamic>{
          'idUsuario': pac?['uid'] ?? 'paciente_ana',
          'nome': pac?['nome'] ?? 'Ana Carolina Silva',
          'papel': 'Paciente',
        });
      }
      final uidNutri =
          (perfil['idNutricionista'] as String?) ?? 'nutri_gabriel';
      final nutri = (usuarios[uidNutri] as Map<String, dynamic>?) ??
          usuarios['nutri_gabriel'] as Map<String, dynamic>?;
      return _ok(<String, dynamic>{
        'idUsuario': nutri?['uid'] ?? 'nutri_gabriel',
        'nome': nutri?['nome'] ?? 'Dr. Gabriel Costa',
        'papel': 'Nutricionista',
        'crn': nutri?['crn'] ?? 'CRN-3 45821',
        'especializacao':
            nutri?['especializacao'] ?? 'Nutrição Esportiva e Emagrecimento',
      });
    }

    if (m == 'GET' && caminho.startsWith('/chat/conversa/')) {
      final idContato = caminho.split('/').last;
      final perfil = _obterOuCriarPerfilAtual(db);
      final meuUid = perfil['uid'] as String;
      final usuarios = db['usuarios'] as Map<String, dynamic>;
      final contatoDoc = usuarios[idContato] as Map<String, dynamic>?;
      final ehNutriContato =
          (contatoDoc?['tipoUsuario'] ?? 'nutricionista') == 'nutricionista';

      final todas = (db['mensagens'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .where((msg) =>
              (msg['idRemetente'] == meuUid &&
                  msg['idDestinatario'] == idContato) ||
              (msg['idRemetente'] == idContato &&
                  msg['idDestinatario'] == meuUid))
          .map((msg) => <String, dynamic>{
                ...msg,
                'ehMinha': msg['idRemetente'] == meuUid,
              })
          .toList();

      return _ok(<String, dynamic>{
        'contato': <String, dynamic>{
          'idUsuario': idContato,
          'nome': contatoDoc?['nome'] ??
              (ehNutriContato ? 'Dr. Gabriel Costa' : 'Ana Carolina Silva'),
          'papel': ehNutriContato ? 'Nutricionista' : 'Paciente',
          'crn': contatoDoc?['crn'],
          'especializacao': contatoDoc?['especializacao'],
        },
        'mensagens': todas,
      });
    }

    if (m == 'POST' && caminho == '/chat/mensagens') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final meuUid = perfil['uid'] as String;
      final idContato = body['uidContato']?.toString() ?? 'nutri_gabriel';
      final texto = body['mensagem']?.toString() ?? '';
      final agora = DateTime.now().toIso8601String();
      final msg = <String, dynamic>{
        'idMensagem': 'msg_${DateTime.now().millisecondsSinceEpoch}',
        'idRemetente': meuUid,
        'idDestinatario': idContato,
        'nomeRemetente': perfil['nome'] ?? 'Você',
        'mensagem': texto,
        'dataHora': agora,
        'ehMinha': true,
      };
      (db['mensagens'] as List<dynamic>).add(msg);
      await _salvarDb();
      return _ok(msg);
    }

    if (m == 'GET' && caminho == '/chat/nao-lidas') {
      return _ok(<String, dynamic>{'total': 0});
    }

    // ---------------- CONSULTAS & ORIENTACOES ----------------
    if (m == 'GET' && caminho == '/consultas') {
      final consultas = (db['consultas'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .where((c) => c['status'] != 'concluida' && c['status'] != 'cancelada')
          .toList();
      return _ok(<String, dynamic>{'consultas': consultas});
    }

    if (m == 'GET' && caminho == '/consultas/historico') {
      final historico = (db['consultas'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .where((c) => c['status'] == 'concluida')
          .toList();
      return _ok(<String, dynamic>{'consultas': historico});
    }

    if (m == 'POST' && caminho == '/consultas') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final nova = <String, dynamic>{
        'idConsulta': 'cons_${DateTime.now().millisecondsSinceEpoch}',
        'dataHora': body['dataHora']?.toString() ??
            DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'status': 'disponivel',
        'uidNutricionista': perfil['uid'],
        'nomeNutricionista': perfil['nome'],
        'observacoes': body['observacoes']?.toString() ?? '',
      };
      (db['consultas'] as List<dynamic>).add(nova);
      await _salvarDb();
      return _ok(<String, dynamic>{'consulta': nova});
    }

    if (m == 'POST' && caminho == '/consultas/lote') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final horarios = (body['horarios'] as List<dynamic>?) ?? const [];
      final lista = db['consultas'] as List<dynamic>;
      int idx = 0;
      for (final h in horarios) {
        idx++;
        lista.add(<String, dynamic>{
          'idConsulta':
              'cons_${DateTime.now().millisecondsSinceEpoch}_$idx',
          'dataHora': h.toString(),
          'status': 'disponivel',
          'uidNutricionista': perfil['uid'],
          'nomeNutricionista': perfil['nome'],
          'observacoes': body['observacoes']?.toString() ?? '',
        });
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'criadas': horarios.length});
    }

    if (m == 'PUT' && caminho.startsWith('/consultas/')) {
      final idConsulta = caminho.split('/').last;
      final lista = db['consultas'] as List<dynamic>;
      for (final c in lista) {
        if (c is Map<String, dynamic> &&
            c['idConsulta']?.toString() == idConsulta) {
          if (body['dataHora'] != null) {
            c['dataHora'] = body['dataHora'].toString();
          }
          if (body['observacoes'] != null) {
            c['observacoes'] = body['observacoes'].toString();
          }
        }
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'atualizada': true});
    }

    if (m == 'POST' && caminho.startsWith('/consultas/')) {
      final partes = caminho.split('/');
      final idConsulta = partes[partes.length - 2];
      final acao = partes.last;
      final perfil = _obterOuCriarPerfilAtual(db);
      final lista = db['consultas'] as List<dynamic>;
      for (final c in lista) {
        if (c is Map<String, dynamic> &&
            c['idConsulta']?.toString() == idConsulta) {
          if (acao == 'solicitar') {
            c['status'] = 'pendente';
            c['uidPaciente'] = perfil['uid'];
            c['nomePaciente'] = perfil['nome'];
          } else if (acao == 'confirmar' || acao == 'aprovar') {
            c['status'] = 'confirmada';
            c['uidPaciente'] ??= perfil['uid'];
            c['nomePaciente'] ??= perfil['nome'];
          } else if (acao == 'recusar') {
            c['status'] = 'disponivel';
            c['uidPaciente'] = null;
            c['nomePaciente'] = null;
          } else if (acao == 'concluir') {
            c['status'] = 'concluida';
          } else if (acao == 'cancelar') {
            c['status'] = 'cancelada';
          }
        }
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'atualizada': true});
    }

    if (m == 'GET' && caminho == '/orientacoes') {
      final orientacoes = (db['orientacoes'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      return _ok(<String, dynamic>{'orientacoes': orientacoes});
    }

    if (m == 'POST' &&
        caminho.startsWith('/orientacoes/') &&
        caminho.endsWith('/confirmar')) {
      final partes = caminho.split('/');
      final idOrientacao = partes[partes.length - 2];
      final lista = db['orientacoes'] as List<dynamic>;
      for (final o in lista) {
        if (o is Map<String, dynamic> &&
            o['idOrientacao']?.toString() == idOrientacao) {
          o['lida'] = true;
          o['confirmada'] = true;
          o['confirmadaEm'] = DateTime.now().toIso8601String();
        }
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'confirmada': true});
    }

    if (m == 'POST' && caminho == '/nutricionista/orientacoes') {
      final nova = <String, dynamic>{
        'idOrientacao': 'ori_${DateTime.now().millisecondsSinceEpoch}',
        'uidPaciente': body['uidPaciente']?.toString() ?? 'paciente_ana',
        'categoria': body['categoria']?.toString() ?? 'positivo',
        'texto': body['texto']?.toString() ?? '',
        'lida': false,
        'confirmada': false,
        'criadoEm': DateTime.now().toIso8601String(),
      };
      (db['orientacoes'] as List<dynamic>).insert(0, nova);
      await _salvarDb();
      return _ok(<String, dynamic>{'orientacao': nova});
    }

    // ---------------- PAINEL DO NUTRICIONISTA ----------------
    if (m == 'GET' && caminho == '/nutricionista/pacientes') {
      final perfil = _obterOuCriarPerfilAtual(db);
      final pacientes = _listarPacientesAtivosDoNutricionista(
        db,
        perfil['uid'] as String,
      );
      return _ok(<String, dynamic>{'pacientes': pacientes});
    }

    if (m == 'GET' && caminho == '/nutricionista/solicitacoes') {
      final usuarios = db['usuarios'] as Map<String, dynamic>;
      final solicitacoes = usuarios.values
          .whereType<Map<String, dynamic>>()
          .where((u) =>
              u['tipoUsuario'] == 'paciente' &&
              u['statusVinculo'] == 'pendente')
          .map((u) => _pacienteParaResumo(db, u))
          .toList();
      return _ok(<String, dynamic>{'solicitacoes': solicitacoes});
    }

    if (m == 'POST' &&
        caminho.startsWith('/nutricionista/solicitacoes/') &&
        caminho.endsWith('/aceitar')) {
      final partes = caminho.split('/');
      final uidPac = partes[partes.length - 2];
      final nutri = _obterOuCriarPerfilAtual(db);
      _validarLimitePacientes(db, nutri);

      final usuarios = db['usuarios'] as Map<String, dynamic>;
      final pac = usuarios[uidPac] as Map<String, dynamic>?;
      if (pac != null) {
        pac['idNutricionista'] = nutri['uid'];
        pac['statusVinculo'] = 'aprovado';
        _garantirPlanoParaPaciente(db, uidPac, nutri['uid'] as String);
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'aceito': true});
    }

    if (m == 'POST' &&
        caminho.startsWith('/nutricionista/solicitacoes/') &&
        caminho.endsWith('/recusar')) {
      final partes = caminho.split('/');
      final uidPac = partes[partes.length - 2];
      final usuarios = db['usuarios'] as Map<String, dynamic>;
      final pac = usuarios[uidPac] as Map<String, dynamic>?;
      if (pac != null) {
        pac['statusVinculo'] = 'recusado';
      }
      await _salvarDb();
      return _ok(<String, dynamic>{'recusado': true});
    }

    if (m == 'POST' && caminho == '/nutricionista/pacientes') {
      final nutri = _obterOuCriarPerfilAtual(db);
      _validarLimitePacientes(db, nutri);

      final email = (body['email']?.toString() ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        throw ApiException('Informe o e-mail do paciente.', status: 400);
      }

      final usuarios = db['usuarios'] as Map<String, dynamic>;
      Map<String, dynamic>? encontrado;
      for (final u in usuarios.values.whereType<Map<String, dynamic>>()) {
        if (u['email']?.toString().toLowerCase() == email) {
          encontrado = u;
          break;
        }
      }

      if (encontrado == null) {
        final novoUid = 'pac_${DateTime.now().millisecondsSinceEpoch}';
        final nomeGerado = email.split('@').first;
        encontrado = _criarDocumentoUsuario(
          uid: novoUid,
          nome: nomeGerado[0].toUpperCase() + nomeGerado.substring(1),
          email: email,
          tipoUsuario: 'paciente',
          onboardingCompleto: true,
        );
        encontrado['idade'] = 28;
        encontrado['pesoAtual'] = 70.0;
        encontrado['pesoMeta'] = 65.0;
        encontrado['altura'] = 1.68;
        encontrado['meta'] = 'Reeducação alimentar';
        usuarios[novoUid] = encontrado;
        _garantirProgressoInicial(db, novoUid, 70.0);
      }

      encontrado['idNutricionista'] = nutri['uid'];
      encontrado['statusVinculo'] = 'aprovado';
      _garantirPlanoParaPaciente(
        db,
        encontrado['uid'] as String,
        nutri['uid'] as String,
      );
      await _salvarDb();
      return _ok(<String, dynamic>{
        'paciente': _pacienteParaResumo(db, encontrado),
      });
    }

    if (m == 'GET' &&
        caminho.startsWith('/nutricionista/pacientes/') &&
        caminho.endsWith('/lista-compras')) {
      final partes = caminho.split('/');
      final uidPac = partes[partes.length - 2];
      final itens = _montarListaCompras(db, uidPac);
      return _ok(<String, dynamic>{
        'compartilhada': true,
        'itens': itens,
      });
    }

    if (m == 'GET' &&
        caminho.startsWith('/nutricionista/pacientes/') &&
        caminho.endsWith('/plano')) {
      final partes = caminho.split('/');
      final uidPac = partes[partes.length - 2];
      final nutri = _obterOuCriarPerfilAtual(db);
      final plano = _garantirPlanoParaPaciente(
        db,
        uidPac,
        nutri['uid'] as String,
      );
      return _ok(_montarPlanoSemanalPayload(db, plano));
    }

    if (m == 'POST' &&
        caminho.startsWith('/nutricionista/pacientes/') &&
        caminho.endsWith('/plano/refeicoes')) {
      final partes = caminho.split('/');
      final uidPac = partes[partes.length - 3];
      final nutri = _obterOuCriarPerfilAtual(db);
      final plano = _garantirPlanoParaPaciente(
        db,
        uidPac,
        nutri['uid'] as String,
      );
      final dia = body['dia']?.toString() ?? 'segunda';
      final tipo = body['tipo']?.toString() ?? 'cafeManha';
      final idReceita = body['idReceita']?.toString() ?? 'rec_1';
      final horario = body['horario']?.toString() ?? _horariosPadrao[tipo];

      final grade =
          (plano['grade'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      grade['$dia:$tipo'] = <String, dynamic>{
        'idReceita': idReceita,
        'horario': horario,
      };
      plano['grade'] = grade;
      await _salvarDb();
      return _ok(_montarPlanoSemanalPayload(db, plano));
    }

    if (m == 'DELETE' &&
        caminho.startsWith('/nutricionista/pacientes/') &&
        caminho.endsWith('/plano/refeicoes')) {
      final partes = caminho.split('/');
      final uidPac = partes[partes.length - 3];
      final nutri = _obterOuCriarPerfilAtual(db);
      final plano = _garantirPlanoParaPaciente(
        db,
        uidPac,
        nutri['uid'] as String,
      );
      final dia = q['dia']?.toString() ?? 'segunda';
      final tipo = q['tipo']?.toString() ?? 'cafeManha';
      final grade =
          (plano['grade'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      grade.remove('$dia:$tipo');
      await _salvarDb();
      return _ok(_montarPlanoSemanalPayload(db, plano));
    }

    if (m == 'PUT' &&
        caminho.startsWith('/nutricionista/pacientes/') &&
        caminho.endsWith('/plano')) {
      final partes = caminho.split('/');
      final uidPac = partes[partes.length - 2];
      final nutri = _obterOuCriarPerfilAtual(db);
      final plano = _garantirPlanoParaPaciente(
        db,
        uidPac,
        nutri['uid'] as String,
      );
      if (body['nomePlano'] != null) {
        plano['nomePlano'] = body['nomePlano'].toString();
      }
      if (body['objetivo'] != null) {
        plano['objetivo'] = body['objetivo'].toString();
      }
      await _salvarDb();
      return _ok(_montarPlanoSemanalPayload(db, plano));
    }

    if (m == 'GET' && caminho == '/nutricionista/relatorios') {
      final nutri = _obterOuCriarPerfilAtual(db);
      final pacientes = _listarPacientesAtivosDoNutricionista(
        db,
        nutri['uid'] as String,
      );
      final relatorios = pacientes.map((p) {
        final uidPac = p['uid'] as String;
        final progMap = db['progresso'] as Map<String, dynamic>;
        final prog = progMap[uidPac] as Map<String, dynamic>?;
        final pesagens = (prog?['pesagens'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final pontos = pesagens.reversed
            .map((item) => <String, dynamic>{
                  'data': item['dataRegistro'],
                  'peso': item['peso'],
                })
            .toList();
        double variacao = 0;
        if (pontos.length >= 2) {
          final primeiro = (pontos.first['peso'] as num).toDouble();
          final ultimo = (pontos.last['peso'] as num).toDouble();
          variacao = double.parse((primeiro - ultimo).toStringAsFixed(1));
        }
        return <String, dynamic>{
          'uid': uidPac,
          'nome': p['nome'],
          'objetivo': p['objetivo'] ?? 'Emagrecimento saudável',
          'nomePlano': p['nomePlano'] ?? 'Plano Alimentar Personalizado',
          'aderenciaMedia': 86.0,
          'frequenciaRegistros': pontos.length,
          'evolucaoPeso': <String, dynamic>{
            'pontos': pontos,
            'variacao30d': variacao,
          },
        };
      }).toList();
      return _ok(<String, dynamic>{'relatorios': relatorios});
    }

    // ---------------- ASSINATURA MERCADO PAGO ----------------
    if (m == 'GET' && caminho == '/assinatura/status') {
      final nutri = _obterOuCriarPerfilAtual(db);
      return _ok(<String, dynamic>{
        'assinatura': _montarStatusAssinatura(db, nutri),
      });
    }

    if (m == 'POST' && caminho == '/assinatura/assinar') {
      final nutri = _obterOuCriarPerfilAtual(db);
      final metodo = body['metodoPagamento']?.toString() ?? 'pix';
      final confirmar = body['confirmarImediatamente'] == true;
      final idMp = 'mp_pro_${DateTime.now().millisecondsSinceEpoch}';
      final validade =
          DateTime.now().add(const Duration(days: 30)).toIso8601String();

      nutri['idAssinaturaMp'] = idMp;
      nutri['metodoPagamentoAssinatura'] = metodo;
      nutri['checkoutUrlAssinatura'] =
          'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_id=$idMp';

      if (confirmar) {
        nutri['planoAssinatura'] = 'pro';
        nutri['statusAssinatura'] = 'ativa';
        nutri['ehAssinante'] = true;
        nutri['limitePacientes'] = null;
        nutri['assinaturaValidaAte'] = validade;
      } else {
        nutri['statusAssinatura'] = 'pendente';
      }
      await _salvarDb();
      return _ok(<String, dynamic>{
        'assinatura': _montarStatusAssinatura(db, nutri),
        'perfil': _perfilParaJson(nutri),
      });
    }

    if (m == 'POST' && caminho == '/assinatura/sincronizar') {
      final nutri = _obterOuCriarPerfilAtual(db);
      final validade =
          DateTime.now().add(const Duration(days: 30)).toIso8601String();
      nutri['planoAssinatura'] = 'pro';
      nutri['statusAssinatura'] = 'ativa';
      nutri['ehAssinante'] = true;
      nutri['limitePacientes'] = null;
      nutri['assinaturaValidaAte'] = validade;
      nutri['idAssinaturaMp'] ??=
          'mp_pro_${DateTime.now().millisecondsSinceEpoch}';
      await _salvarDb();
      return _ok(<String, dynamic>{
        'assinatura': _montarStatusAssinatura(db, nutri),
        'perfil': _perfilParaJson(nutri),
      });
    }

    if (m == 'POST' && caminho == '/assinatura/cancelar') {
      final nutri = _obterOuCriarPerfilAtual(db);
      nutri['planoAssinatura'] = 'gratuito';
      nutri['statusAssinatura'] = 'cancelada';
      nutri['ehAssinante'] = false;
      nutri['limitePacientes'] = _limiteGratuito;
      nutri['assinaturaValidaAte'] = null;
      await _salvarDb();
      return _ok(<String, dynamic>{
        'assinatura': _montarStatusAssinatura(db, nutri),
        'perfil': _perfilParaJson(nutri),
      });
    }

    return _ok(<String, dynamic>{});
  }

  // =====================================================================
  //  AUXILIARES INTERNOS
  // =====================================================================

  Map<String, dynamic> _ok(Map<String, dynamic> dados) => <String, dynamic>{
        'sucesso': true,
        'dados': dados,
      };

  Map<String, dynamic> _criarDocumentoUsuario({
    required String uid,
    required String nome,
    required String email,
    required String tipoUsuario,
    String? telefone,
    String? crn,
    String? especializacao,
    bool onboardingCompleto = true,
    bool emailVerificado = true,
  }) {
    final ehNutri = tipoUsuario == 'nutricionista';
    return <String, dynamic>{
      'uid': uid,
      'nome': nome,
      'email': email,
      'emailVerificado': emailVerificado,
      'telefone': telefone ?? '(19) 99812-3456',
      'tipoUsuario': tipoUsuario,
      'crn': crn,
      'especializacao': especializacao,
      'onboardingCompleto': onboardingCompleto,
      'tutorialVisto': onboardingCompleto,
      'planoAssinatura': 'gratuito',
      'statusAssinatura': 'inativa',
      'ehAssinante': false,
      'limitePacientes': ehNutri ? _limiteGratuito : null,
      'precoAssinatura': _precoPro,
      'assinaturaValidaAte': null,
      'idAssinaturaMp': null,
      'metodoPagamentoAssinatura': 'pix',
      'idade': ehNutri ? null : 27,
      'pesoAtual': ehNutri ? null : 68.5,
      'pesoMeta': ehNutri ? null : 64.0,
      'altura': ehNutri ? null : 1.68,
      'genero': ehNutri ? null : 'Feminino',
      'meta': ehNutri ? null : 'Emagrecimento e Definição',
      'nivelAtividade': ehNutri ? null : 'Moderado (3 a 5x por semana)',
      'tipoDieta': ehNutri ? null : 'Equilibrada / Flexível',
      'idNutricionista': ehNutri ? uid : 'nutri_gabriel',
      'statusVinculo': 'aprovado',
      'alimentosFavoritos': <String>['Frango grelhado', 'Aveia', 'Banana'],
      'alimentosRejeitados': <String>[],
      'restricoes': <String>[],
      'condicoesMedicas': <String>[],
      'compartilharListaCompras': true,
      'compartilharHumor': true,
      'observacoesSeguranca': '',
      'itensListaComprasExtras': <dynamic>[],
    };
  }

  Map<String, dynamic> _perfilParaJson(Map<String, dynamic> perfil) {
    final ehAssinante = perfil['ehAssinante'] == true ||
        (perfil['planoAssinatura'] == 'pro' &&
            perfil['statusAssinatura'] == 'ativa');
    return <String, dynamic>{
      'idUsuario': perfil['uid'],
      'uid': perfil['uid'],
      'idPaciente':
          perfil['tipoUsuario'] == 'paciente' ? perfil['uid'] : null,
      'idNutricionista': perfil['tipoUsuario'] == 'nutricionista'
          ? perfil['uid']
          : (perfil['idNutricionista'] ?? 'nutri_gabriel'),
      'crn': perfil['crn'],
      'nome': perfil['nome'] ?? '',
      'email': perfil['email'] ?? '',
      'emailVerificado': perfil['emailVerificado'] != false,
      'telefone': perfil['telefone'],
      'tipoUsuario': perfil['tipoUsuario'] ?? 'paciente',
      'onboardingCompleto': perfil['onboardingCompleto'] == true,
      'tutorialVisto': perfil['tutorialVisto'] == true,
      'especializacao': perfil['especializacao'],
      'planoAssinatura': perfil['planoAssinatura'] ?? 'gratuito',
      'statusAssinatura': perfil['statusAssinatura'] ?? 'inativa',
      'ehAssinante': ehAssinante,
      'limitePacientes': ehAssinante
          ? null
          : ((perfil['limitePacientes'] as num?)?.toInt() ?? _limiteGratuito),
      'precoAssinatura':
          (perfil['precoAssinatura'] as num?)?.toDouble() ?? _precoPro,
      'assinaturaValidaAte': perfil['assinaturaValidaAte'],
      'idAssinaturaMp': perfil['idAssinaturaMp'],
      'metodoPagamentoAssinatura': perfil['metodoPagamentoAssinatura'],
      'idade': perfil['idade'],
      'pesoAtual': perfil['pesoAtual'],
      'pesoMeta': perfil['pesoMeta'],
      'altura': perfil['altura'],
      'genero': perfil['genero'],
      'meta': perfil['meta'],
      'nivelAtividade': perfil['nivelAtividade'],
      'tipoDieta': perfil['tipoDieta'],
      'alimentosFavoritos': perfil['alimentosFavoritos'] ?? const <String>[],
      'alimentosRejeitados': perfil['alimentosRejeitados'] ?? const <String>[],
      'restricoes': perfil['restricoes'] ?? const <String>[],
      'condicoesMedicas': perfil['condicoesMedicas'] ?? const <String>[],
      'compartilharListaCompras': perfil['compartilharListaCompras'] != false,
      'compartilharHumor': perfil['compartilharHumor'] != false,
      'observacoesSeguranca': perfil['observacoesSeguranca'] ?? '',
    };
  }

  void _mesclarCamposPerfil(
    Map<String, dynamic> perfil,
    Map<String, dynamic> body,
  ) {
    const chavesPermitidas = <String>[
      'nome',
      'telefone',
      'crn',
      'especializacao',
      'idade',
      'pesoAtual',
      'pesoMeta',
      'altura',
      'genero',
      'meta',
      'nivelAtividade',
      'tipoDieta',
      'alimentosFavoritos',
      'alimentosRejeitados',
      'restricoes',
      'condicoesMedicas',
      'compartilharListaCompras',
      'compartilharHumor',
      'observacoesSeguranca',
    ];
    for (final chave in chavesPermitidas) {
      if (body.containsKey(chave) && body[chave] != null) {
        perfil[chave] = body[chave];
      }
    }
  }

  void _vincularDadosIniciaisAoNutricionista(
    Map<String, dynamic> db,
    String uidNutri,
    String nomeNutri,
  ) {
    final usuarios = db['usuarios'] as Map<String, dynamic>;
    for (final u in usuarios.values.whereType<Map<String, dynamic>>()) {
      if (u['tipoUsuario'] == 'paciente') {
        u['idNutricionista'] = uidNutri;
      }
    }
    final consultas = db['consultas'] as List<dynamic>;
    for (final c in consultas.whereType<Map<String, dynamic>>()) {
      c['uidNutricionista'] = uidNutri;
      c['nomeNutricionista'] = nomeNutri;
    }
  }

  List<Map<String, dynamic>> _listarPacientesAtivosDoNutricionista(
    Map<String, dynamic> db,
    String uidNutri,
  ) {
    final usuarios = db['usuarios'] as Map<String, dynamic>;
    final vinculados = usuarios.values
        .whereType<Map<String, dynamic>>()
        .where((u) =>
            u['tipoUsuario'] == 'paciente' &&
            u['statusVinculo'] != 'pendente' &&
            u['statusVinculo'] != 'recusado' &&
            (u['idNutricionista'] == uidNutri ||
                u['idNutricionista'] == 'nutri_gabriel'))
        .map((u) => _pacienteParaResumo(db, u))
        .toList();
    return vinculados;
  }

  Map<String, dynamic> _pacienteParaResumo(
    Map<String, dynamic> db,
    Map<String, dynamic> u,
  ) {
    final planos = db['planos'] as Map<String, dynamic>;
    final plano = planos[u['uid']] as Map<String, dynamic>?;
    return <String, dynamic>{
      'uid': u['uid'],
      'nome': u['nome'] ?? '',
      'email': u['email'] ?? '',
      'idade': u['idade'],
      'pesoAtual': u['pesoAtual'],
      'pesoMeta': u['pesoMeta'],
      'altura': u['altura'],
      'genero': u['genero'],
      'objetivo': u['meta'] ?? 'Emagrecimento saudável',
      'tipoDieta': u['tipoDieta'] ?? 'Equilibrada',
      'alimentosFavoritos': u['alimentosFavoritos'] ?? const <String>[],
      'alimentosRejeitados': u['alimentosRejeitados'] ?? const <String>[],
      'restricoes': u['restricoes'] ?? const <String>[],
      'condicoesMedicas': u['condicoesMedicas'] ?? const <String>[],
      'compartilharListaCompras': u['compartilharListaCompras'] != false,
      'compartilharHumor': u['compartilharHumor'] != false,
      'observacoesSeguranca': u['observacoesSeguranca'] ?? '',
      'temPlanoAtivo': plano != null,
      'nomePlano': plano?['nomePlano'] ?? 'Plano Alimentar Personalizado',
    };
  }

  void _validarLimitePacientes(
    Map<String, dynamic> db,
    Map<String, dynamic> nutri,
  ) {
    final ehAssinante = nutri['ehAssinante'] == true ||
        (nutri['planoAssinatura'] == 'pro' &&
            nutri['statusAssinatura'] == 'ativa');
    if (ehAssinante) return;

    final ativos = _listarPacientesAtivosDoNutricionista(
      db,
      nutri['uid'] as String,
    );
    if (ativos.length >= _limiteGratuito) {
      throw ApiException(
        'Limite de $_limiteGratuito pacientes atingido no plano gratuito. Assine o Plano Pro (R\$ 29,90/mês) nas Configurações para liberar pacientes ilimitados.',
        status: 403,
      );
    }
  }

  Map<String, dynamic> _montarStatusAssinatura(
    Map<String, dynamic> db,
    Map<String, dynamic> nutri,
  ) {
    final plano = (nutri['planoAssinatura'] ?? 'gratuito').toString();
    final status = (nutri['statusAssinatura'] ?? 'inativa').toString();
    final ehAssinante =
        nutri['ehAssinante'] == true || (plano == 'pro' && status == 'ativa');
    final ativos = _listarPacientesAtivosDoNutricionista(
      db,
      nutri['uid'] as String,
    ).length;
    final restantes =
        (_limiteGratuito - ativos).clamp(0, _limiteGratuito);

    return <String, dynamic>{
      'planoAssinatura': plano,
      'statusAssinatura': status,
      'ehAssinante': ehAssinante,
      'precoMensal': _precoPro,
      'limitePacientes': ehAssinante ? null : _limiteGratuito,
      'limitePlanoGratuito': _limiteGratuito,
      'totalPacientesAtivos': ativos,
      'restantesGratuito': ehAssinante ? null : restantes,
      'limiteAtingido': !ehAssinante && ativos >= _limiteGratuito,
      'assinaturaValidaAte': nutri['assinaturaValidaAte'],
      'idAssinaturaMp': nutri['idAssinaturaMp'],
      'checkoutUrl': nutri['checkoutUrlAssinatura'],
      'metodoPagamento': nutri['metodoPagamentoAssinatura'] ?? 'pix',
      'modoIntegracao': 'mercadopago_sandbox_local',
    };
  }

  Map<String, dynamic> _garantirPlanoParaPaciente(
    Map<String, dynamic> db,
    String uidPaciente,
    String uidNutricionista,
  ) {
    final planos = db['planos'] as Map<String, dynamic>;
    if (planos[uidPaciente] is Map<String, dynamic>) {
      return planos[uidPaciente] as Map<String, dynamic>;
    }

    final grade = <String, dynamic>{};
    const padraoDia = <String, String>{
      'cafeManha': 'rec_1',
      'lancheManha': 'rec_5',
      'almoco': 'rec_2',
      'lancheTarde': 'rec_3',
      'jantar': 'rec_4',
      'ceia': 'rec_6',
    };
    for (final dia in _diasSemana) {
      for (final tipo in _tiposRefeicao) {
        grade['$dia:$tipo'] = <String, dynamic>{
          'idReceita': padraoDia[tipo] ?? 'rec_1',
          'horario': _horariosPadrao[tipo] ?? '12:00',
        };
      }
    }

    final novoPlano = <String, dynamic>{
      'idPlano': 'plano_$uidPaciente',
      'uidPaciente': uidPaciente,
      'uidNutricionista': uidNutricionista,
      'nomePlano': 'Plano Equilíbrio & Saúde',
      'objetivo': 'Emagrecimento e Reeducação Alimentar',
      'grade': grade,
      'checks': <String, dynamic>{
        '${_diaDaSemanaAtual()}:cafeManha': true,
        '${_diaDaSemanaAtual()}:lancheManha': true,
      },
    };
    planos[uidPaciente] = novoPlano;
    return novoPlano;
  }

  List<Map<String, dynamic>> _montarRefeicoesDoDia(
    Map<String, dynamic> db,
    Map<String, dynamic> plano,
    String dia,
  ) {
    final grade =
        (plano['grade'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final checks =
        (plano['checks'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final receitas = (db['receitas'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();

    final resultado = <Map<String, dynamic>>[];
    for (final tipo in _tiposRefeicao) {
      final slot = grade['$dia:$tipo'] as Map<String, dynamic>?;
      if (slot == null) continue;
      final idReceita = slot['idReceita']?.toString() ?? 'rec_1';
      final receita = receitas.firstWhere(
        (r) => r['idReceita'] == idReceita,
        orElse: () => receitas.first,
      );
      resultado.add(<String, dynamic>{
        'dia': dia,
        'tipo': tipo,
        'rotuloDia': _rotulosDia[dia] ?? dia,
        'rotuloTipo': _rotulosRefeicao[tipo] ?? tipo,
        'horario': slot['horario'] ?? _horariosPadrao[tipo],
        'idReceita': idReceita,
        'nomeReceita': receita['nome'],
        'calorias': receita['calorias'],
        'proteinas': receita['proteinas'],
        'carboidratos': receita['carboidratos'],
        'gorduras': receita['gorduras'],
        'ingredientes': receita['ingredientes'],
        'concluida': checks['$dia:$tipo'] == true,
      });
    }
    return resultado;
  }

  Map<String, dynamic> _calcularResumoChecklist(
    List<Map<String, dynamic>> refeicoes,
  ) {
    final total = refeicoes.length;
    int concluidas = 0;
    double totalCalorias = 0;
    double caloriasConcluidas = 0;

    for (final r in refeicoes) {
      final kcal = (r['calorias'] as num?)?.toDouble() ?? 0;
      totalCalorias += kcal;
      if (r['concluida'] == true) {
        concluidas++;
        caloriasConcluidas += kcal;
      }
    }

    final percentual = total > 0 ? (concluidas / total) * 100.0 : 0.0;
    return <String, dynamic>{
      'total': total,
      'concluidas': concluidas,
      'percentual': double.parse(percentual.toStringAsFixed(1)),
      'totalCalorias': double.parse(totalCalorias.toStringAsFixed(1)),
      'caloriasConcluidas':
          double.parse(caloriasConcluidas.toStringAsFixed(1)),
    };
  }

  Map<String, dynamic> _montarPlanoSemanalPayload(
    Map<String, dynamic> db,
    Map<String, dynamic> plano,
  ) {
    int preenchidas = 0;
    final dias = _diasSemana.map((dia) {
      final refeicoes = _montarRefeicoesDoDia(db, plano, dia);
      preenchidas += refeicoes.length;
      return <String, dynamic>{
        'dia': dia,
        'rotulo': _rotulosDia[dia] ?? dia,
        'refeicoes': refeicoes,
      };
    }).toList();

    return <String, dynamic>{
      'plano': <String, dynamic>{
        'idPlano': plano['idPlano'],
        'nomePlano': plano['nomePlano'],
        'objetivo': plano['objetivo'],
      },
      'dias': dias,
      'progressoMontagem': <String, dynamic>{
        'preenchidas': preenchidas,
        'total': 42,
      },
    };
  }

  List<Map<String, dynamic>> _montarListaCompras(
    Map<String, dynamic> db,
    String uidPaciente,
  ) {
    final usuarios = db['usuarios'] as Map<String, dynamic>;
    final perfil = (usuarios[uidPaciente] as Map<String, dynamic>?) ??
        _obterOuCriarPerfilAtual(db);
    final plano = _garantirPlanoParaPaciente(
      db,
      uidPaciente,
      (perfil['idNutricionista'] as String?) ?? 'nutri_gabriel',
    );
    final compradosMap =
        (perfil['itensCompradosMap'] as Map<String, dynamic>?) ??
            <String, dynamic>{};

    final agregados = <String, Map<String, dynamic>>{};
    for (final dia in _diasSemana) {
      final refeicoes = _montarRefeicoesDoDia(db, plano, dia);
      for (final ref in refeicoes) {
        final ings = (ref['ingredientes'] as List<dynamic>?) ?? const [];
        for (final ing in ings.whereType<Map<String, dynamic>>()) {
          final nome = (ing['nome'] ?? 'Ingrediente').toString();
          final chave = nome.toLowerCase();
          final qtd = (ing['quantidadeG'] as num?)?.toDouble() ?? 100;
          if (agregados.containsKey(chave)) {
            agregados[chave]!['quantidadeG'] =
                ((agregados[chave]!['quantidadeG'] as num).toDouble() + qtd);
          } else {
            final idGerado = 'auto_${chave.replaceAll(' ', '_')}';
            agregados[chave] = <String, dynamic>{
              'id': idGerado,
              'idAlimento': ing['idAlimento'],
              'nome': nome,
              'categoria': ing['categoria'] ?? 'Mercearia',
              'quantidadeG': qtd,
              'unidade': ing['unidade'] ?? 'g',
              'comprado': compradosMap[idGerado] == true,
              'manual': false,
            };
          }
        }
      }
    }

    final extras = (perfil['itensListaComprasExtras'] as List<dynamic>? ??
            const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    return <Map<String, dynamic>>[...agregados.values, ...extras];
  }

  Map<String, dynamic> _garantirProgressoInicial(
    Map<String, dynamic> db,
    String uidPaciente,
    double pesoBase,
  ) {
    final progMap = db['progresso'] as Map<String, dynamic>;
    if (progMap[uidPaciente] is Map<String, dynamic>) {
      return progMap[uidPaciente] as Map<String, dynamic>;
    }
    final hoje = DateTime.now();
    final d1 = _formatarData(hoje.subtract(const Duration(days: 21)));
    final d2 = _formatarData(hoje.subtract(const Duration(days: 14)));
    final d3 = _formatarData(hoje.subtract(const Duration(days: 7)));
    final d4 = _formatarData(hoje);

    final dados = <String, dynamic>{
      'coposAgua': 5,
      'humor': 'bom',
      'pesagens': <Map<String, dynamic>>[
        <String, dynamic>{
          'idProgresso': d4,
          'peso': pesoBase,
          'dataRegistro': d4,
          'aderenciaPlano': 90.0,
        },
        <String, dynamic>{
          'idProgresso': d3,
          'peso': double.parse((pesoBase + 0.6).toStringAsFixed(1)),
          'dataRegistro': d3,
          'aderenciaPlano': 85.0,
        },
        <String, dynamic>{
          'idProgresso': d2,
          'peso': double.parse((pesoBase + 1.2).toStringAsFixed(1)),
          'dataRegistro': d2,
          'aderenciaPlano': 82.0,
        },
        <String, dynamic>{
          'idProgresso': d1,
          'peso': double.parse((pesoBase + 1.9).toStringAsFixed(1)),
          'dataRegistro': d1,
          'aderenciaPlano': 80.0,
        },
      ],
    };
    progMap[uidPaciente] = dados;
    return dados;
  }

  void _registrarPesoInterno(
    Map<String, dynamic> db,
    String uidPaciente,
    double peso,
    String? data,
  ) {
    final prog = _garantirProgressoInicial(db, uidPaciente, peso);
    final dataFormatada = data ?? _formatarData(DateTime.now());
    final pesagens = (prog['pesagens'] as List<dynamic>);
    pesagens.removeWhere(
        (p) => p is Map && p['idProgresso']?.toString() == dataFormatada);
    pesagens.insert(0, <String, dynamic>{
      'idProgresso': dataFormatada,
      'peso': peso,
      'dataRegistro': dataFormatada,
      'aderenciaPlano': 90.0,
    });
  }

  Map<String, dynamic> _montarProgressoPayload(
    Map<String, dynamic> db,
    Map<String, dynamic> perfil,
  ) {
    final uid = perfil['uid'] as String;
    final pesoBase = (perfil['pesoAtual'] as num?)?.toDouble() ?? 68.5;
    final prog = _garantirProgressoInicial(db, uid, pesoBase);
    final pesagens = (prog['pesagens'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();

    final pesoAtual = pesagens.isNotEmpty
        ? (pesagens.first['peso'] as num).toDouble()
        : pesoBase;
    final pesoInicial = pesagens.isNotEmpty
        ? (pesagens.last['peso'] as num).toDouble()
        : pesoBase;
    final variacao = pesoAtual - pesoInicial;
    final diferenca = double.parse(variacao.abs().toStringAsFixed(1));
    final sentido = variacao < -0.05
        ? 'perda'
        : (variacao > 0.05 ? 'ganho' : 'estavel');
    final rotulo = sentido == 'perda'
        ? 'Perdidos desde o início'
        : (sentido == 'ganho' ? 'Ganhos desde o início' : 'Estável no período');

    final pesoMeta = (perfil['pesoMeta'] as num?)?.toDouble() ?? 64.0;
    final restantes =
        double.parse((pesoAtual - pesoMeta).abs().toStringAsFixed(1));
    final totalMeta = (pesoInicial - pesoMeta).abs();
    final alcancado = (pesoInicial - pesoAtual).abs();
    final percentualMeta = totalMeta > 0.1
        ? ((alcancado / totalMeta) * 100.0).clamp(0.0, 100.0)
        : 100.0;

    return <String, dynamic>{
      'paciente': <String, dynamic>{
        'nome': perfil['nome'],
        'objetivo': perfil['meta'] ?? 'Emagrecimento e Saúde',
      },
      'resumo': <String, dynamic>{
        'pesoAtual': pesoAtual,
        'pesoInicial': pesoInicial,
        'diferenca': diferenca,
        'sentido': sentido,
        'rotuloDiferenca': rotulo,
        'pesoMeta': pesoMeta,
        'restantesParaMeta': restantes,
        'percentualMeta': double.parse(percentualMeta.toStringAsFixed(1)),
      },
      'historico': pesagens,
      'hoje': <String, dynamic>{
        'coposAgua': prog['coposAgua'] ?? 5,
        'humor': prog['humor'] ?? 'bom',
      },
    };
  }

  Map<String, dynamic> _montarEvolucaoPayload(
    Map<String, dynamic> db,
    Map<String, dynamic> paciente,
    String periodo,
  ) {
    final uid = paciente['uid'] as String;
    final pesoBase = (paciente['pesoAtual'] as num?)?.toDouble() ?? 68.5;
    final prog = _garantirProgressoInicial(db, uid, pesoBase);
    final pesagens = (prog['pesagens'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();

    final pontos = pesagens.reversed
        .map((p) => <String, dynamic>{
              'data': p['dataRegistro'],
              'peso': p['peso'],
            })
        .toList();

    double minPeso = pesoBase - 2;
    double maxPeso = pesoBase + 2;
    double variacao = 0;
    if (pontos.isNotEmpty) {
      final valores = pontos.map((p) => (p['peso'] as num).toDouble()).toList();
      valores.sort();
      minPeso = (valores.first - 1.5).floorToDouble();
      maxPeso = (valores.last + 1.5).ceilToDouble();
      variacao = double.parse(
        ((pontos.last['peso'] as num).toDouble() -
                (pontos.first['peso'] as num).toDouble())
            .toStringAsFixed(1),
      );
    }

    const metaKcal = 1850.0;
    const barras = <Map<String, dynamic>>[
      <String, dynamic>{'rotulo': 'Seg', 'consumido': 1810.0, 'meta': metaKcal},
      <String, dynamic>{'rotulo': 'Ter', 'consumido': 1790.0, 'meta': metaKcal},
      <String, dynamic>{'rotulo': 'Qua', 'consumido': 1860.0, 'meta': metaKcal},
      <String, dynamic>{'rotulo': 'Qui', 'consumido': 1820.0, 'meta': metaKcal},
      <String, dynamic>{'rotulo': 'Sex', 'consumido': 1880.0, 'meta': metaKcal},
      <String, dynamic>{'rotulo': 'Sáb', 'consumido': 1920.0, 'meta': metaKcal},
      <String, dynamic>{'rotulo': 'Dom', 'consumido': 1800.0, 'meta': metaKcal},
    ];

    return <String, dynamic>{
      'periodo': periodo,
      'metaCalorica': metaKcal,
      'plano': <String, dynamic>{
        'nomePlano': 'Plano Equilíbrio & Saúde',
      },
      'evolucaoPeso': <String, dynamic>{
        'pontos': pontos,
        'variacao': variacao,
        'minimo': minPeso,
        'maximo': maxPeso,
      },
      'consumoSemanal': <String, dynamic>{
        'barras': barras,
        'mediaConsumida': 1840.0,
        'maximoEixo': 2300.0,
        'meta': metaKcal,
      },
      'macronutrientes': <String, dynamic>{
        'aderenciaMedia': 88.5,
        'origemMeta': 'plano_alimentar',
        'itens': <Map<String, dynamic>>[
          <String, dynamic>{
            'chave': 'proteinas',
            'rotulo': 'Proteínas',
            'consumido': 128,
            'meta': 135,
            'percentual': 94.8,
          },
          <String, dynamic>{
            'chave': 'carboidratos',
            'rotulo': 'Carboidratos',
            'consumido': 185,
            'meta': 200,
            'percentual': 92.5,
          },
          <String, dynamic>{
            'chave': 'gorduras',
            'rotulo': 'Gorduras',
            'consumido': 54,
            'meta': 60,
            'percentual': 90.0,
          },
        ],
      },
    };
  }

  Map<String, dynamic> _criarReceitaComMacros({
    required String idReceita,
    required String nome,
    required String modoPreparo,
    required List<dynamic> ingredientesRaw,
    String status = 'aprovada',
    String? autorUid,
  }) {
    double cal = 0;
    double prot = 0;
    double carb = 0;
    double gord = 0;
    final ings = <Map<String, dynamic>>[];

    for (final item in ingredientesRaw.whereType<Map<String, dynamic>>()) {
      final qtd = (item['quantidadeG'] as num?)?.toDouble() ?? 100;
      final c100 = (item['calorias'] as num?)?.toDouble() ?? 120;
      final p100 = (item['proteinas'] as num?)?.toDouble() ?? 10;
      final cb100 = (item['carboidratos'] as num?)?.toDouble() ?? 15;
      final g100 = (item['gorduras'] as num?)?.toDouble() ?? 4;
      final fator = qtd / 100.0;

      cal += c100 * fator;
      prot += p100 * fator;
      carb += cb100 * fator;
      gord += g100 * fator;

      ings.add(<String, dynamic>{
        'idAlimento': item['idAlimento'],
        'nome': item['nome'] ?? 'Ingrediente',
        'categoria': item['categoria'] ?? 'Outros',
        'quantidadeG': qtd,
        'unidade': item['unidade'] ?? 'g',
        'calorias': c100,
        'proteinas': p100,
        'carboidratos': cb100,
        'gorduras': g100,
      });
    }

    if (cal <= 0) {
      cal = 280;
      prot = 22;
      carb = 28;
      gord = 8;
    }

    return <String, dynamic>{
      'idReceita': idReceita,
      'nome': nome,
      'modoPreparo': modoPreparo,
      'ingredientes': ings,
      'calorias': double.parse(cal.toStringAsFixed(1)),
      'proteinas': double.parse(prot.toStringAsFixed(1)),
      'carboidratos': double.parse(carb.toStringAsFixed(1)),
      'gorduras': double.parse(gord.toStringAsFixed(1)),
      'status': status,
      if (autorUid != null) 'autorUid': autorUid,
    };
  }

  static String _diaDaSemanaAtual() {
    final idx = (DateTime.now().weekday - 1).clamp(0, 6);
    return _diasSemana[idx];
  }

  static String _formatarData(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // =====================================================================
  //  SEED INICIAL DO BANCO LOCAL
  // =====================================================================

  Map<String, dynamic> _criarSeedInicial() {
    final db = <String, dynamic>{
      'usuarios': <String, dynamic>{
        'nutri_gabriel': _criarDocumentoUsuario(
          uid: 'nutri_gabriel',
          nome: 'Dr. Gabriel Costa',
          email: 'gabriel@mvn.com',
          tipoUsuario: 'nutricionista',
          crn: 'CRN-3 45821',
          especializacao: 'Nutrição Esportiva e Emagrecimento',
        ),
        'nutri_emilly': _criarDocumentoUsuario(
          uid: 'nutri_emilly',
          nome: 'Dra. Emilly Alves',
          email: 'emilly@mvn.com',
          tipoUsuario: 'nutricionista',
          crn: 'CRN-3 51209',
          especializacao: 'Nutrição Clínica e Funcional',
        ),
        'paciente_ana': <String, dynamic>{
          ..._criarDocumentoUsuario(
            uid: 'paciente_ana',
            nome: 'Ana Carolina Silva',
            email: 'ana@mvn.com',
            tipoUsuario: 'paciente',
          ),
          'idade': 28,
          'pesoAtual': 68.5,
          'pesoMeta': 63.0,
          'altura': 1.66,
          'meta': 'Emagrecimento saudável',
          'tipoDieta': 'Equilibrada',
          'restricoes': <String>['Intolerância leve a lactose'],
        },
        'paciente_joao': <String, dynamic>{
          ..._criarDocumentoUsuario(
            uid: 'paciente_joao',
            nome: 'João Pedro Santos',
            email: 'joao@mvn.com',
            tipoUsuario: 'paciente',
          ),
          'idade': 32,
          'pesoAtual': 81.2,
          'pesoMeta': 76.0,
          'altura': 1.78,
          'genero': 'Masculino',
          'meta': 'Hipertrofia e definição',
          'tipoDieta': 'Hiperproteica',
          'restricoes': <String>['Sem glúten'],
        },
      },
      'fotos': <String, dynamic>{},
      'alimentos': _alimentosIniciais(),
      'receitas': _receitasIniciais(),
      'planos': <String, dynamic>{},
      'progresso': <String, dynamic>{},
      'consultas': <Map<String, dynamic>>[
        <String, dynamic>{
          'idConsulta': 'cons_seed_1',
          'dataHora':
              DateTime.now().add(const Duration(days: 2, hours: 3)).toIso8601String(),
          'status': 'confirmada',
          'uidNutricionista': 'nutri_gabriel',
          'nomeNutricionista': 'Dr. Gabriel Costa',
          'uidPaciente': 'paciente_ana',
          'nomePaciente': 'Ana Carolina Silva',
          'observacoes': 'Avaliação mensal de bioimpedância e ajustes do cardápio.',
        },
        <String, dynamic>{
          'idConsulta': 'cons_seed_2',
          'dataHora':
              DateTime.now().add(const Duration(days: 4, hours: 5)).toIso8601String(),
          'status': 'disponivel',
          'uidNutricionista': 'nutri_gabriel',
          'nomeNutricionista': 'Dr. Gabriel Costa',
          'observacoes': 'Horário livre para retorno presencial ou teleconsulta.',
        },
      ],
      'orientacoes': <Map<String, dynamic>>[
        <String, dynamic>{
          'idOrientacao': 'ori_seed_1',
          'uidPaciente': 'paciente_ana',
          'categoria': 'positivo',
          'texto':
              'Excelente evolução na última semana! Continue mantendo a meta de 2L de água por dia e priorizando proteínas no café da manhã.',
          'lida': false,
          'confirmada': false,
          'criadoEm':
              DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
        },
      ],
      'mensagens': <Map<String, dynamic>>[
        <String, dynamic>{
          'idMensagem': 'msg_seed_1',
          'idRemetente': 'nutri_gabriel',
          'idDestinatario': 'paciente_ana',
          'nomeRemetente': 'Dr. Gabriel Costa',
          'mensagem':
              'Olá! Já atualizei seu cardápio desta semana com novas opções práticas para o almoço e lanche da tarde.',
          'dataHora':
              DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        },
      ],
    };

    _garantirPlanoParaPaciente(db, 'paciente_ana', 'nutri_gabriel');
    _garantirPlanoParaPaciente(db, 'paciente_joao', 'nutri_gabriel');
    _garantirProgressoInicial(db, 'paciente_ana', 68.5);
    _garantirProgressoInicial(db, 'paciente_joao', 81.2);
    return db;
  }

  static List<Map<String, dynamic>> _alimentosIniciais() =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'idAlimento': 'ali_1',
          'nome': 'Peito de frango grelhado',
          'categoria': 'Proteínas',
          'calorias': 159.0,
          'proteinas': 32.0,
          'carboidratos': 0.0,
          'gorduras': 2.5,
        },
        <String, dynamic>{
          'idAlimento': 'ali_2',
          'nome': 'Arroz integral cozido',
          'categoria': 'Grãos e Cereais',
          'calorias': 124.0,
          'proteinas': 2.6,
          'carboidratos': 25.8,
          'gorduras': 1.0,
        },
        <String, dynamic>{
          'idAlimento': 'ali_3',
          'nome': 'Ovo de galinha cozido',
          'categoria': 'Proteínas',
          'calorias': 146.0,
          'proteinas': 13.3,
          'carboidratos': 0.6,
          'gorduras': 9.5,
        },
        <String, dynamic>{
          'idAlimento': 'ali_4',
          'nome': 'Aveia em flocos',
          'categoria': 'Grãos e Cereais',
          'calorias': 394.0,
          'proteinas': 13.9,
          'carboidratos': 66.6,
          'gorduras': 8.5,
        },
        <String, dynamic>{
          'idAlimento': 'ali_5',
          'nome': 'Banana prata',
          'categoria': 'Frutas',
          'calorias': 98.0,
          'proteinas': 1.3,
          'carboidratos': 26.0,
          'gorduras': 0.1,
        },
        <String, dynamic>{
          'idAlimento': 'ali_6',
          'nome': 'Batata-doce cozida',
          'categoria': 'Tubérculos',
          'calorias': 77.0,
          'proteinas': 0.6,
          'carboidratos': 18.4,
          'gorduras': 0.1,
        },
        <String, dynamic>{
          'idAlimento': 'ali_7',
          'nome': 'Brócolis cozido',
          'categoria': 'Hortaliças',
          'calorias': 25.0,
          'proteinas': 2.1,
          'carboidratos': 4.4,
          'gorduras': 0.3,
        },
        <String, dynamic>{
          'idAlimento': 'ali_8',
          'nome': 'Salmão grelhado',
          'categoria': 'Proteínas',
          'calorias': 208.0,
          'proteinas': 20.4,
          'carboidratos': 0.0,
          'gorduras': 13.4,
        },
        <String, dynamic>{
          'idAlimento': 'ali_9',
          'nome': 'Iogurte natural desnatado',
          'categoria': 'Laticínios',
          'calorias': 57.0,
          'proteinas': 5.8,
          'carboidratos': 7.8,
          'gorduras': 0.3,
        },
        <String, dynamic>{
          'idAlimento': 'ali_10',
          'nome': 'Castanha-do-pará',
          'categoria': 'Oleaginosas',
          'calorias': 643.0,
          'proteinas': 14.5,
          'carboidratos': 15.1,
          'gorduras': 63.5,
        },
      ];

  static List<Map<String, dynamic>> _receitasIniciais() =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'idReceita': 'rec_1',
          'nome': 'Omelete Proteico com Aveia',
          'modoPreparo':
              'Bata 2 ovos com 20g de aveia e uma pitada de sal. Doure em frigideira antiaderente por 3 minutos de cada lado.',
          'calorias': 298.0,
          'proteinas': 19.4,
          'carboidratos': 14.2,
          'gorduras': 12.6,
          'status': 'aprovada',
          'ingredientes': <Map<String, dynamic>>[
            <String, dynamic>{
              'idAlimento': 'ali_3',
              'nome': 'Ovo de galinha cozido',
              'categoria': 'Proteínas',
              'quantidadeG': 120.0,
              'unidade': 'g',
              'calorias': 146.0,
              'proteinas': 13.3,
              'carboidratos': 0.6,
              'gorduras': 9.5,
            },
            <String, dynamic>{
              'idAlimento': 'ali_4',
              'nome': 'Aveia em flocos',
              'categoria': 'Grãos e Cereais',
              'quantidadeG': 30.0,
              'unidade': 'g',
              'calorias': 394.0,
              'proteinas': 13.9,
              'carboidratos': 66.6,
              'gorduras': 8.5,
            },
          ],
        },
        <String, dynamic>{
          'idReceita': 'rec_2',
          'nome': 'Frango Grelhado com Batata-Doce e Brócolis',
          'modoPreparo':
              'Grelhe o filé de frango temperado com ervas. Sirva acompanhado da batata-doce cozida e brócolis no vapor.',
          'calorias': 378.0,
          'proteinas': 50.8,
          'carboidratos': 32.0,
          'gorduras': 4.1,
          'status': 'aprovada',
          'ingredientes': <Map<String, dynamic>>[
            <String, dynamic>{
              'idAlimento': 'ali_1',
              'nome': 'Peito de frango grelhado',
              'categoria': 'Proteínas',
              'quantidadeG': 150.0,
              'unidade': 'g',
              'calorias': 159.0,
              'proteinas': 32.0,
              'carboidratos': 0.0,
              'gorduras': 2.5,
            },
            <String, dynamic>{
              'idAlimento': 'ali_6',
              'nome': 'Batata-doce cozida',
              'categoria': 'Tubérculos',
              'quantidadeG': 150.0,
              'unidade': 'g',
              'calorias': 77.0,
              'proteinas': 0.6,
              'carboidratos': 18.4,
              'gorduras': 0.1,
            },
            <String, dynamic>{
              'idAlimento': 'ali_7',
              'nome': 'Brócolis cozido',
              'categoria': 'Hortaliças',
              'quantidadeG': 100.0,
              'unidade': 'g',
              'calorias': 25.0,
              'proteinas': 2.1,
              'carboidratos': 4.4,
              'gorduras': 0.3,
            },
          ],
        },
        <String, dynamic>{
          'idReceita': 'rec_3',
          'nome': 'Mingau Funcional de Aveia e Banana',
          'modoPreparo':
              'Amasse a banana e leve ao fogo baixo com a aveia e água ou leite vegetal por 4 minutos. Finalize com canela.',
          'calorias': 236.0,
          'proteinas': 6.8,
          'carboidratos': 46.0,
          'gorduras': 3.5,
          'status': 'aprovada',
          'ingredientes': <Map<String, dynamic>>[
            <String, dynamic>{
              'idAlimento': 'ali_5',
              'nome': 'Banana prata',
              'categoria': 'Frutas',
              'quantidadeG': 100.0,
              'unidade': 'g',
              'calorias': 98.0,
              'proteinas': 1.3,
              'carboidratos': 26.0,
              'gorduras': 0.1,
            },
            <String, dynamic>{
              'idAlimento': 'ali_4',
              'nome': 'Aveia em flocos',
              'categoria': 'Grãos e Cereais',
              'quantidadeG': 35.0,
              'unidade': 'g',
              'calorias': 394.0,
              'proteinas': 13.9,
              'carboidratos': 66.6,
              'gorduras': 8.5,
            },
          ],
        },
        <String, dynamic>{
          'idReceita': 'rec_4',
          'nome': 'Salmão Grelhado com Arroz Integral e Brócolis',
          'modoPreparo':
              'Grelhe o salmão em fogo médio por 4 minutos de cada lado e sirva com arroz integral e brócolis no vapor.',
          'calorias': 435.0,
          'proteinas': 33.8,
          'carboidratos': 35.0,
          'gorduras': 17.5,
          'status': 'aprovada',
          'ingredientes': <Map<String, dynamic>>[
            <String, dynamic>{
              'idAlimento': 'ali_8',
              'nome': 'Salmão grelhado',
              'categoria': 'Proteínas',
              'quantidadeG': 130.0,
              'unidade': 'g',
              'calorias': 208.0,
              'proteinas': 20.4,
              'carboidratos': 0.0,
              'gorduras': 13.4,
            },
            <String, dynamic>{
              'idAlimento': 'ali_2',
              'nome': 'Arroz integral cozido',
              'categoria': 'Grãos e Cereais',
              'quantidadeG': 120.0,
              'unidade': 'g',
              'calorias': 124.0,
              'proteinas': 2.6,
              'carboidratos': 25.8,
              'gorduras': 1.0,
            },
          ],
        },
        <String, dynamic>{
          'idReceita': 'rec_5',
          'nome': 'Bowl de Iogurte Natural com Castanhas',
          'modoPreparo':
              'Sirva o iogurte natural gelado com as castanhas picadas por cima.',
          'calorias': 195.0,
          'proteinas': 11.6,
          'carboidratos': 15.2,
          'gorduras': 9.8,
          'status': 'aprovada',
          'ingredientes': <Map<String, dynamic>>[
            <String, dynamic>{
              'idAlimento': 'ali_9',
              'nome': 'Iogurte natural desnatado',
              'categoria': 'Laticínios',
              'quantidadeG': 170.0,
              'unidade': 'g',
              'calorias': 57.0,
              'proteinas': 5.8,
              'carboidratos': 7.8,
              'gorduras': 0.3,
            },
            <String, dynamic>{
              'idAlimento': 'ali_10',
              'nome': 'Castanha-do-pará',
              'categoria': 'Oleaginosas',
              'quantidadeG': 15.0,
              'unidade': 'g',
              'calorias': 643.0,
              'proteinas': 14.5,
              'carboidratos': 15.1,
              'gorduras': 63.5,
            },
          ],
        },
        <String, dynamic>{
          'idReceita': 'rec_6',
          'nome': 'Ceia Leve de Iogurte e Aveia',
          'modoPreparo': 'Misture o iogurte natural com uma colher de aveia.',
          'calorias': 148.0,
          'proteinas': 9.8,
          'carboidratos': 20.5,
          'gorduras': 2.1,
          'status': 'aprovada',
          'ingredientes': <Map<String, dynamic>>[
            <String, dynamic>{
              'idAlimento': 'ali_9',
              'nome': 'Iogurte natural desnatado',
              'categoria': 'Laticínios',
              'quantidadeG': 150.0,
              'unidade': 'g',
              'calorias': 57.0,
              'proteinas': 5.8,
              'carboidratos': 7.8,
              'gorduras': 0.3,
            },
          ],
        },
      ];
}

