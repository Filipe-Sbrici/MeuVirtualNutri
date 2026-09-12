/// Servicos de autenticacao (Firebase Auth + perfil na API) e das telas
/// de Progresso e Evolucao.
library;

import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../models/evolucao.dart';
import '../models/progresso.dart';
import '../models/usuario.dart';

class AuthService {
  AuthService(this._api, {FirebaseAuth? firebaseAuth})
      : _firebaseAuthInicial = firebaseAuth;

  final ApiClient _api;
  final FirebaseAuth? _firebaseAuthInicial;

  /// Acesso lazy: tests substituem os metodos que o utilizam sem
  /// precisar de um FirebaseApp inicializado.
  FirebaseAuth get _auth => _firebaseAuthInicial ?? FirebaseAuth.instance;

  User? get usuarioAtual => _auth.currentUser;
  Stream<User?> get mudancasDeSessao => _auth.userChanges();

  /// Autentica no Firebase e devolve o perfil registrado na API.
  Future<Usuario> login({required String email, required String senha}) async {
    final credencial = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
    return carregarPerfil(credencial.user!.uid);
  }

  /// Cria a conta no Firebase e materializa o perfil paciente na API.
  ///
  /// Se a API falhar, a conta recem-criada no Firebase Auth e desfeita:
  /// sem isso o e-mail ficaria preso (o cadastro acusaria
  /// "e-mail ja cadastrado" e o login nao acharia perfil).
  Future<Usuario> cadastrarPaciente({
    required String nome,
    required String email,
    required String senha,
    required String confirmarSenha,
  }) async {
    if (senha != confirmarSenha) {
      throw ApiException('As senhas nao conferem.');
    }
    final credencial = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
    try {
      await credencial.user!.updateDisplayName(nome);
      await _api.post('/auth/cadastro/paciente', corpo: {
        'nome': nome,
        'email': email.trim(),
      });
      return await carregarPerfil();
    } catch (_) {
      await credencial.user?.delete().catchError((_) {});
      rethrow;
    }
  }

  /// Cria a conta do nutricionista (com CRN) no Firebase + API.
  Future<Usuario> cadastrarNutricionista({
    required String nome,
    required String email,
    required String crn,
    String? telefone,
    String? especializacao,
    required String senha,
    required String confirmarSenha,
  }) async {
    if (senha != confirmarSenha) {
      throw ApiException('As senhas nao conferem.');
    }
    final credencial = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
    try {
      await credencial.user!.updateDisplayName(nome);

      final resposta = await _api.post('/auth/cadastro/nutricionista', corpo: {
        'nome': nome,
        'email': email.trim(),
        'crn': crn.trim(),
        if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
        if (especializacao != null && especializacao.isNotEmpty)
          'especializacao': especializacao,
      });
      final perfil = lerDados(resposta, Usuario.fromJson);
      return perfil;
    } catch (_) {
      await credencial.user?.delete().catchError((_) {});
      rethrow;
    }
  }

  /// Perfil do usuario autenticado (GET /api/auth/perfil).
  Future<Usuario> carregarPerfil([String? uid]) async {
    final resposta = await _api.get('/auth/perfil');
    return lerDados(resposta, Usuario.fromJson);
  }

  /// Envia o e-mail de redefinicao de senha (tela "Esqueceu a senha?").
  Future<void> redefinirSenha(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> logout() => _auth.signOut();

  /// Exclui a conta do Firebase Auth apos a API apagar o perfil.
  ///
  /// A ordem importa: se a API falhar, a conta do Authentication e
  /// mantida para o usuario poder tentar de novo (do contrario sobraria
  /// um perfil orfao no Firestore sem dono).
  Future<void> excluirConta() async {
    await _api.delete('/perfil/perfil');
    await _auth.currentUser?.delete();
  }
}

class ProgressoService {
  ProgressoService(this._api);

  final ApiClient _api;

  /// Resumo + historico de pesagens do paciente logado.
  Future<Progresso> carregar() async {
    final resposta = await _api.get('/progresso');
    return lerDados(resposta, Progresso.fromJson);
  }

  /// Registra uma nova pesagem e devolve o progresso ja recalculado.
  ///
  /// [data] e opcional; sem ela a API usa a data de hoje.
  Future<Progresso> registrarPeso({required double peso, DateTime? data}) async {
    final resposta = await _api.post('/progresso/peso', corpo: {
      'peso': peso,
      if (data != null) 'dataRegistro': _formatarData(data),
    });
    return lerDados(resposta, Progresso.fromJson);
  }

  /// Remove uma pesagem e devolve o progresso recalculado.
  Future<Progresso> removerPesagem({required String dataRegistro}) async {
    final resposta = await _api.delete('/progresso/peso/$dataRegistro');
    return lerDados(resposta, Progresso.fromJson);
  }

  /// Contador de agua do Bem-Estar.
  Future<void> registrarAgua({required int coposAgua}) async {
    await _api.post('/progresso/agua', corpo: {'coposAgua': coposAgua});
  }

  /// Termometro emocional do Bem-Estar.
  Future<void> registrarHumor({required String humor}) async {
    await _api.post('/progresso/humor', corpo: {'humor': humor});
  }

  /// Converte para 'YYYY-MM-DD' esperado pela API.
  static String _formatarData(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';
}

class EvolucaoService {
  EvolucaoService(this._api);

  final ApiClient _api;

  /// Dados dos tres graficos. [periodo] = 'semanal' | 'mensal'.
  /// [uidPaciente] vazio consulta o paciente logado (o nutricionista
  /// informa o uid de um paciente vinculado).
  Future<Evolucao> carregar({
    String? uidPaciente,
    String periodo = 'mensal',
  }) async {
    final caminho = uidPaciente == null || uidPaciente.isEmpty
        ? '/evolucao'
        : '/evolucao/$uidPaciente';
    final resposta = await _api.get(caminho, query: {'periodo': periodo});
    return lerDados(resposta, Evolucao.fromJson);
  }
}
