/// Gerenciador de preferencias globais do aplicativo (Tema Claro/Escuro,
/// Tamanho de Fontes e Notificacoes).
///
/// Implementa o padrao [ChangeNotifier] para que a arvore de widgets
/// atualize instantaneamente quando qualquer preferencia for alterada.
library;

import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  ThemeMode _themeMode = ThemeMode.system;
  double _textScaleFactor = 1.0;

  bool _notificacoesChat = true;
  bool _notificacoesConsultas = true;
  bool _notificacoesLembretes = true;
  bool _notificacoesSolicitacoes = true;

  // Getters
  ThemeMode get themeMode => _themeMode;
  ThemeMode get modoTema => _themeMode;
  double get textScaleFactor => _textScaleFactor;
  double get fatorEscalaTexto => _textScaleFactor;

  bool get notificacoesChat => _notificacoesChat;
  bool get notificacoesConsultas => _notificacoesConsultas;
  bool get notificacoesLembretes => _notificacoesLembretes;
  bool get notificacoesSolicitacoes => _notificacoesSolicitacoes;

  /// Atualiza o modo de tema (Claro, Escuro ou Seguir Sistema).
  void definirModoTema(ThemeMode modo) {
    if (_themeMode == modo) return;
    _themeMode = modo;
    notifyListeners();
  }

  /// Atualiza o fator de escala de fontes (0.9 = pequeno, 1.0 = normal, 1.15 = grande).
  void definirEscalaFonte(double escala) {
    if (_textScaleFactor == escala) return;
    _textScaleFactor = escala;
    notifyListeners();
  }

  /// Alterna preferencia individual de notificacao.
  void alternarNotificacao(String tipo, bool ativo) {
    switch (tipo) {
      case 'chat':
        _notificacoesChat = ativo;
        break;
      case 'consultas':
        _notificacoesConsultas = ativo;
        break;
      case 'lembretes':
        _notificacoesLembretes = ativo;
        break;
      case 'solicitacoes':
        _notificacoesSolicitacoes = ativo;
        break;
    }
    notifyListeners();
  }
}
