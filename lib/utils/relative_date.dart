import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// Format relatif d'une date pour les listes (chats, documents).
/// Renvoie « à l'instant », « il y a X min/h/j », ou la date complète au-delà
/// d'une semaine.
///
/// Sourcé via [AppLocalizations] (FR/EN). Centralisé pour éviter les copies
/// dans `chat_list_screen.dart` et `documents_screen.dart`.
String relativeDate(BuildContext context, DateTime d) {
  final t = AppLocalizations.of(context);
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return t.dateJustNow;
  if (diff.inMinutes < 60) return t.dateMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return t.dateHoursAgo(diff.inHours);
  if (diff.inDays < 7) return t.dateDaysAgo(diff.inDays);
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}
