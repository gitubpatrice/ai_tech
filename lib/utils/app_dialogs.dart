import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Dialog de confirmation. Renvoie `true` si l'utilisateur a confirmé,
/// `false` ou `null` sinon. Si [destructive] est vrai, le bouton de
/// confirmation est rendu en rouge (`cs.error`) — utiliser pour les
/// suppressions, mode panique, etc.
///
/// Centralise le pattern dupliqué entre `chat_screen`, `chat_list_screen`,
/// `documents_screen` et `settings_screen`.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String yesLabel,
  String? noLabel,
  bool destructive = false,
}) {
  final t = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            // U2 v0.9.1 — `autofocus` sur Cancel quand destructif :
            // Enter (clavier physique / a11y) annule au lieu de
            // détruire. Safe default.
            autofocus: destructive,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(noLabel ?? t.commonCancel),
          ),
          FilledButton(
            // U3 v0.9.1 — Si destructif, fournir `foregroundColor: cs.onError`
            // explicite. Avant : `backgroundColor: cs.error` seul → texte
            // par défaut pouvait tomber sur `primary` et le contraste
            // WCAG AA était fragile en dark mode.
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yesLabel),
          ),
        ],
      );
    },
  );
}
