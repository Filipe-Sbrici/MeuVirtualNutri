import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/mvn_services.dart';

class FotoPerfil extends StatefulWidget {
  const FotoPerfil({
    super.key,
    required this.nome,
    required this.uid,
    required this.onboardingService,
    required this.raio,
    this.revisao = 0,
  });

  final String nome;
  final String uid;
  final OnboardingService onboardingService;
  final double raio;
  final int revisao;

  @override
  State<FotoPerfil> createState() => _FotoPerfilState();
}

class _FotoPerfilState extends State<FotoPerfil> {
  late Future<Uint8List?> _imagem;

  @override
  void initState() {
    super.initState();
    _imagem = _carregar();
  }

  @override
  void didUpdateWidget(covariant FotoPerfil oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid || oldWidget.revisao != widget.revisao) {
      _imagem = _carregar();
    }
  }

  Future<Uint8List?> _carregar() async {
    try {
      if (FirebaseAuth.instance.currentUser?.uid != widget.uid) return null;
    } catch (_) {
      return null;
    }
    final foto = await widget.onboardingService.carregarFotoPerfil();
    if (foto == null ||
        foto['mimeType'] is! String ||
        foto['dadosBase64'] is! String) {
      return null;
    }
    try {
      return base64Decode(foto['dadosBase64'] as String);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final inicial = widget.nome.trim().isNotEmpty
        ? widget.nome.trim()[0].toUpperCase()
        : 'U';
    final fallback = Container(
      color: escuro ? const Color(0xFF21262D) : AppColors.paletaVerdeSuave,
      alignment: Alignment.center,
      child: Text(inicial,
          style: TextStyle(
            fontSize: widget.raio * 0.8,
            fontWeight: FontWeight.bold,
            color: escuro ? AppColors.paletaLilasSuave : AppColors.paletaRoxo,
          )),
    );

    return SizedBox(
      width: widget.raio * 2,
      height: widget.raio * 2,
      child: ClipOval(
        child: FutureBuilder<Uint8List?>(
          future: _imagem,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (snapshot.hasError ||
                (snapshot.connectionState == ConnectionState.done &&
                    bytes == null)) {
              return fallback;
            }
            if (bytes == null) {
              return Stack(fit: StackFit.expand, children: [
                fallback,
                const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              ]);
            }
            return Image.memory(bytes,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
          },
        ),
      ),
    );
  }
}
