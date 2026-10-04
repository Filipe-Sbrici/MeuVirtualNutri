/// Seleciona, valida e persiste fotos de perfil no Firestore pela API.
library;

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../models/usuario.dart';
import 'mvn_services.dart';

class FotoPerfilService {
  FotoPerfilService({FirebaseAuth? auth, ImagePicker? seletor})
      : _auth = auth ?? FirebaseAuth.instance,
        _seletor = seletor ?? ImagePicker();

  // Base64 ocupa aproximadamente 4/3 do tamanho binario; esse limite deixa
  // margem para os demais campos dentro do limite de 1 MiB do Firestore.
  static const int limiteBytes = 512 * 1024;
  final FirebaseAuth _auth;
  final ImagePicker _seletor;

  Future<bool> selecionarEnviarEAtualizar({
    required Usuario usuario,
    required OnboardingService onboardingService,
  }) async {
    final autenticado = _auth.currentUser;
    if (autenticado == null || autenticado.uid != usuario.uid) {
      throw ApiException('Entre novamente para alterar sua foto de perfil.');
    }

    final arquivo = await _seletor.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (arquivo == null) return false;

    final bytes = await arquivo.readAsBytes();
    final mimeType = _validarImagem(bytes);
    try {
      await onboardingService.salvarFotoPerfil(
        mimeType: mimeType,
        dadosBase64: base64Encode(bytes),
      );
      return true;
    } on ApiException {
      rethrow;
    } catch (erro) {
      throw ApiException(
          'Nao foi possivel salvar a foto. Verifique a conexao e tente novamente. ($erro)');
    }
  }

  String _validarImagem(Uint8List bytes) {
    if (bytes.isEmpty) throw ApiException('O arquivo selecionado esta vazio.');
    if (bytes.length > limiteBytes) {
      throw ApiException('A foto deve ter no maximo 512 KiB.');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        listEquals(bytes.sublist(0, 8),
            const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    throw ApiException('Formato invalido. Use uma imagem JPG, PNG ou WebP.');
  }
}
