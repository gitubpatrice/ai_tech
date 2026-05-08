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
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(noLabel ?? t.commonCancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: cs.error)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yesLabel),
          ),
        ],
      );
    },
  );
}
