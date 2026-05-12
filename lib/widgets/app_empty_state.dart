import 'package:flutter/material.dart';

/// Écran vide standardisé (icône + titre + sous-titre + action optionnelle).
/// Centralise le pattern dupliqué dans `chat_list_screen`, `documents_screen`,
/// `chat_screen`.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.semanticHeader = false,
    this.excludeIconSemantics = false,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  /// Si vrai, le titre est wrappé `Semantics(header:true)` (TalkBack annonce
  /// l'écran comme un en-tête).
  final bool semanticHeader;

  /// Si vrai, l'icône est exclue des Semantics (icône purement décorative).
  final bool excludeIconSemantics;

  /// Override de la couleur de l'icône (défaut = `cs.outline`).
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final iconWidget = Icon(icon, size: 56, color: iconColor ?? cs.outline);
    // QW17 v0.8.1 — dérivé de textTheme.titleMedium (respect Dynamic Type
    // a11y) au lieu de fontSize 18 hard-coded.
    final titleWidget = Text(
      title,
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            excludeIconSemantics
                ? ExcludeSemantics(child: iconWidget)
                : iconWidget,
            const SizedBox(height: 12),
            semanticHeader
                ? Semantics(header: true, child: titleWidget)
                : titleWidget,
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
