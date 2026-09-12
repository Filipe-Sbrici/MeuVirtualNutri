/// Campo de texto customizado para os fluxos de Autenticacao (Login e Cadastro).
///
/// Implementa a identidade visual definida na paleta de cores:
/// - Bordas arredondadas e suaves ([AppColors.bordaClara])
/// - Icone de prefixo tematico
/// - Botao de alternar visibilidade para senhas (olho)
/// - Rotulo superior e placeholder com cores harmonicas
library;

import 'package:flutter/material.dart';
import '../core/theme.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.helperText,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleVisibility,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  /// Rotulo exibido acima do campo (ex: 'Email', 'Senha', 'Nome Completo').
  final String label;

  /// Controlador de edicao de texto.
  final TextEditingController controller;

  /// Placeholder exibido dentro do campo.
  final String hint;

  /// Texto explicativo auxiliar exibido abaixo do campo (ex: 'Insira seu numero de registro profissional').
  final String? helperText;

  /// Icone exibido no inicio do campo.
  final IconData prefixIcon;

  /// Se este campo e uma senha e possui botao de visibilidade (olho).
  final bool isPassword;

  /// Se o texto esta oculto no momento.
  final bool obscureText;

  /// Callback acionado ao tocar no icone de olho.
  final VoidCallback? onToggleVisibility;

  /// Tipo do teclado (email, texto, numero, etc).
  final TextInputType keyboardType;

  /// Funcao validadora para formularios.
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.fonteTitulo,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? obscureText : false,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            color: AppColors.fonteTitulo,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.fontePlaceholder,
              fontSize: 13,
            ),
            helperText: helperText,
            helperStyle: const TextStyle(
              color: AppColors.fonteSubtitulo,
              fontSize: 11,
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(
              prefixIcon,
              color: AppColors.fonteSubtitulo,
              size: 20,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.fonteSubtitulo,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                    tooltip: obscureText
                        ? 'Mostrar senha'
                        : 'Esconder senha',
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.bordaClara,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.paletaVerde,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.vermelho,
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.vermelho,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
