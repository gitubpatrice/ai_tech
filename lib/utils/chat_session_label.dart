import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_session.dart';

/// Résout le titre d'une session : si la session porte encore le sentinel
/// par défaut (`ChatSession.defaultTitleSentinel`), retourne la traduction
/// localisée (`AppLocalizations.chatTitleDefault`) ; sinon retourne le titre
/// stocké (potentiellement dérivé du premier message).
String localizedSessionTitle(BuildContext context, ChatSession s) {
  final t = AppLocalizations.of(context);
  final raw = s.safeTitle;
  if (raw == ChatSession.defaultTitleSentinel) return t.chatTitleDefault;
  return raw;
}
