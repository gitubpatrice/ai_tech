/// Utilitaire pour strip les caracteres Bidi/RLO/ZWSP des titres ou
/// contenus persistes. Anti homograph spoofing (un fichier nomme avec
/// le codepoint RLO affiche son extension a l'envers, masquant la vraie
/// extension).
///
/// v0.9.2 (#5) — codepoints construits via String.fromCharCodes pour
/// eviter les warnings dart analyzer sur les chars Bidi litteraux dans
/// le code source (lints `unicode_directional_chars`).
library;

/// Liste explicite des codepoints a strip :
/// - U+200B/C/D : zero-width space/non-joiner/joiner
/// - U+202A-E  : LRE/RLE/PDF/LRO/RLO (bidirectional formatting)
/// - U+2066-9  : LRI/RLI/FSI/PDI (bidirectional isolates)
/// - U+FEFF    : byte order mark
const Set<int> _bidiCodeUnits = {
  0x200B, 0x200C, 0x200D,
  0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
  0x2066, 0x2067, 0x2068, 0x2069,
  0xFEFF,
};

/// Retourne [s] avec tous les codepoints Bidi/zero-width retires.
/// Implementation manuelle (pas de RegExp avec litteraux Bidi) pour
/// satisfaire les lints dart sur les chars `unicode_directional_chars`.
String stripBidi(String s) {
  if (s.isEmpty) return s;
  final buffer = StringBuffer();
  for (final r in s.runes) {
    if (!_bidiCodeUnits.contains(r)) {
      buffer.writeCharCode(r);
    }
  }
  return buffer.toString();
}
