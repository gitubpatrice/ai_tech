import 'package:flutter/material.dart';

extension SnackbarExt on BuildContext {
  /// Affiche un SnackBar floating avec une durée optionnelle.
  /// Centralise le pattern dupliqué dans 3+ écrans.
  void showFloatingSnack(String message, {Duration? duration}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }
}
