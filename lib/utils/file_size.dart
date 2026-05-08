/// Formate une taille en mégaoctets avec une décimale.
/// Centralise la conversion octets → "X.X Mo" partagée entre `model_picker`
/// (dialog d'installation) et toute autre vue qui a besoin d'afficher des
/// tailles de modèles MediaPipe.
String fmtMegabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
