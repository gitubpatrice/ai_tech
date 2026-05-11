// v0.8.0 — Helpers de validation magic pour fichiers modèles importés
// (`.task` MediaPipe et `.litertlm` LiteRT-LM).
//
// On ne valide PAS positivement le format LiteRT-LM (header FlatBuffers
// non documenté publiquement, peut évoluer). On se contente de rejeter
// les magics les plus courants qu'un fichier modèle ne devrait JAMAIS
// présenter en tête, pour repousser les renames opportunistes (PDF, EXE,
// image, ZIP, etc.) avant que le binaire C natif ne parse un fichier
// piégé.

/// Retourne true si les premiers octets ressemblent à un format binaire
/// connu qui n'est PAS un modèle d'inférence (PDF / EXE / ELF / Mach-O /
/// ZIP / image / RIFF / XML / HTML / RTF). Defense-in-depth pour
/// `.litertlm` (qui n'a pas de magic stable connu).
bool looksLikeKnownNonModel(List<int> head) {
  if (head.length < 4) return true; // fichier vide ou tronqué
  // PDF : "%PDF"
  if (head[0] == 0x25 && head[1] == 0x50 && head[2] == 0x44 && head[3] == 0x46) {
    return true;
  }
  // EXE Windows PE : "MZ"
  if (head[0] == 0x4D && head[1] == 0x5A) return true;
  // ELF Linux : 0x7F E L F
  if (head[0] == 0x7F && head[1] == 0x45 && head[2] == 0x4C && head[3] == 0x46) {
    return true;
  }
  // Mach-O macOS / iOS (2 variantes)
  if (head[0] == 0xCF && head[1] == 0xFA && head[2] == 0xED && head[3] == 0xFE) {
    return true;
  }
  if (head[0] == 0xFE && head[1] == 0xED && head[2] == 0xFA && head[3] == 0xCE) {
    return true;
  }
  // ZIP / .task / Office / APK : "PK"
  if (head[0] == 0x50 && head[1] == 0x4B) return true;
  // PNG : 89 50 4E 47
  if (head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47) {
    return true;
  }
  // JPEG : FF D8 FF
  if (head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF) return true;
  // GIF : "GIF8"
  if (head[0] == 0x47 && head[1] == 0x49 && head[2] == 0x46 && head[3] == 0x38) {
    return true;
  }
  // RIFF (WAV/AVI/WebP) : "RIFF"
  if (head[0] == 0x52 && head[1] == 0x49 && head[2] == 0x46 && head[3] == 0x46) {
    return true;
  }
  // XML / HTML : "<?xm" / "<htm" / "<!DO" / "<HTM"
  if (head[0] == 0x3C &&
      (head[1] == 0x3F || head[1] == 0x68 || head[1] == 0x21 || head[1] == 0x48)) {
    return true;
  }
  // RTF : "{\\rt"
  if (head[0] == 0x7B && head[1] == 0x5C && head[2] == 0x72 && head[3] == 0x74) {
    return true;
  }
  return false;
}
