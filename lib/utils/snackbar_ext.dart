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

  /// v0.9.2 (F1) — helper canonique snack d'erreur. Pose automatiquement
  /// la paire `cs.errorContainer` + `cs.onErrorContainer` pour garantir le
  /// contraste WCAG AA. Aligné PDF Tech v1.12.4 U1, Notes Tech v1.1.4 M4.
  /// Durée par défaut 6 s (lecture erreur).
  void showErrorSnack(String message, {Duration? duration}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    final cs = Theme.of(this).colorScheme;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: cs.onErrorContainer)),
        backgroundColor: cs.errorContainer,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 6),
      ),
    );
  }

  /// v0.9.2 (F1) — helper canonique snack succès. Pose la paire
  /// `cs.primaryContainer` + `cs.onPrimaryContainer`.
  void showSuccessSnack(String message, {Duration? duration}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    final cs = Theme.of(this).colorScheme;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: cs.onPrimaryContainer)),
        backgroundColor: cs.primaryContainer,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
}
