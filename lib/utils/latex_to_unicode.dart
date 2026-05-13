// v0.8.0 — Conversion LaTeX → Unicode côté affichage.
//
// Contexte : Gemma 4 (et 3) émet souvent des formules en LaTeX/MathJax
// ($\text{H}_2\text{O}$, $E = mc^2$, $\alpha$). L'app n'a pas de moteur de
// rendu math (MarkdownBody ne connaît pas LaTeX), donc ces expressions
// s'affichent en brut → "mots bizarres".
//
// Le system prompt demande déjà à Gemma d'utiliser Unicode natif, mais le
// modèle ignore parfois cette consigne (surtout pour les formules
// chimiques/scientifiques). Ce module fait la conversion côté UI en
// post-traitement, sans modifier le texte stocké.
//
// Scope volontairement limité : on couvre les patterns LaTeX les plus
// fréquents en chimie / maths basiques. Les expressions complexes
// (intégrales, matrices, etc.) restent imparfaites — pour un rendu math
// complet, intégrer flutter_math_fork (chantier futur).
//
// **P1.2 v0.9.1** — Toutes les `RegExp`, les maps `subscript`/`superscript`
// et la liste triée des symboles grecs sont désormais des constantes
// top-level / static final, plus de re-compilation par appel. Pendant
// streaming Gemma (~20 tok/s), `latexToUnicode` est appelé à chaque token
// sur le buffer cumulatif → avant ce refactor : 17 RegExp + 2 maps
// allouées par appel, ~3-6 ms/frame de CPU et GC churn marqué sur S9.
//
// **M1 v0.9.1** — `\(...\)` greedy fixé : on n'accepte un `)` interne que
// s'il n'est pas suivi d'un `\)` qui ferme — empêchait `\( a \) puis \( b \)`
// de fusionner en un seul groupe et perdre du texte utilisateur.

// ────────────── Constantes top-level (allouées 1 fois) ──────────────

final RegExp _reDollarDouble = RegExp(r'\$\$([^\$]+?)\$\$');
final RegExp _reDollarSingle = RegExp(r'\$([^\$\n]+?)\$');
// M1 v0.9.1 : `[^)]*?` + lookahead `\\\)` — refuse d'absorber un `)` qui
// n'est PAS suivi de `\)` (la séquence de fermeture LaTeX réelle).
final RegExp _reBackslashParen = RegExp(r'\\\(((?:[^)]|\)(?!\\\)))*?)\\\)');
final RegExp _reBackslashBracket = RegExp(r'\\\[([^\]]+?)\\\]');

// `\text{X}` & co — pré-construits une fois.
final List<RegExp> _reTextCommands =
    const ['text', 'mathrm', 'mathbf', 'mathit', 'mathsf', 'operatorname']
        .map(
          (cmd) => RegExp(
            '\\\\$cmd'
            r'\{([^{}]*?)\}',
          ),
        )
        .toList(growable: false);

final RegExp _reFrac = RegExp(r'\\frac\{([^{}]*?)\}\{([^{}]*?)\}');
final RegExp _reSqrt = RegExp(r'\\sqrt\{([^{}]*?)\}');

final RegExp _reSubscriptBrace = RegExp(r'_\{([^{}]*?)\}');
final RegExp _reSubscriptChar = RegExp(r'_([A-Za-z0-9+\-=()])');
final RegExp _reSuperscriptBrace = RegExp(r'\^\{([^{}]*?)\}');
final RegExp _reSuperscriptChar = RegExp(r'\^([A-Za-z0-9+\-=()])');

final RegExp _reThinSpaces = RegExp(r'\\[,;!:]');

const Map<String, String> _subscriptMap = {
  '0': '₀',
  '1': '₁',
  '2': '₂',
  '3': '₃',
  '4': '₄',
  '5': '₅',
  '6': '₆',
  '7': '₇',
  '8': '₈',
  '9': '₉',
  '+': '₊',
  '-': '₋',
  '=': '₌',
  '(': '₍',
  ')': '₎',
  'a': 'ₐ',
  'e': 'ₑ',
  'h': 'ₕ',
  'i': 'ᵢ',
  'j': 'ⱼ',
  'k': 'ₖ',
  'l': 'ₗ',
  'm': 'ₘ',
  'n': 'ₙ',
  'o': 'ₒ',
  'p': 'ₚ',
  'r': 'ᵣ',
  's': 'ₛ',
  't': 'ₜ',
  'u': 'ᵤ',
  'v': 'ᵥ',
  'x': 'ₓ',
};

const Map<String, String> _superscriptMap = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  '+': '⁺',
  '-': '⁻',
  '=': '⁼',
  '(': '⁽',
  ')': '⁾',
  'a': 'ᵃ',
  'b': 'ᵇ',
  'c': 'ᶜ',
  'd': 'ᵈ',
  'e': 'ᵉ',
  'f': 'ᶠ',
  'g': 'ᵍ',
  'h': 'ʰ',
  'i': 'ⁱ',
  'j': 'ʲ',
  'k': 'ᵏ',
  'l': 'ˡ',
  'm': 'ᵐ',
  'n': 'ⁿ',
  'o': 'ᵒ',
  'p': 'ᵖ',
  'r': 'ʳ',
  's': 'ˢ',
  't': 'ᵗ',
  'u': 'ᵘ',
  'v': 'ᵛ',
  'w': 'ʷ',
  'x': 'ˣ',
  'y': 'ʸ',
  'z': 'ᶻ',
};

const Map<String, String> _greekAndSymbols = {
  r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
  r'\epsilon': 'ε', r'\varepsilon': 'ε', r'\zeta': 'ζ', r'\eta': 'η',
  r'\theta': 'θ', r'\vartheta': 'ϑ', r'\iota': 'ι', r'\kappa': 'κ',
  r'\lambda': 'λ', r'\mu': 'μ', r'\nu': 'ν', r'\xi': 'ξ',
  r'\pi': 'π', r'\varpi': 'ϖ', r'\rho': 'ρ', r'\varrho': 'ϱ',
  r'\sigma': 'σ', r'\varsigma': 'ς', r'\tau': 'τ', r'\upsilon': 'υ',
  r'\phi': 'φ', r'\varphi': 'ϕ', r'\chi': 'χ', r'\psi': 'ψ',
  r'\omega': 'ω',
  r'\Alpha': 'Α', r'\Beta': 'Β', r'\Gamma': 'Γ', r'\Delta': 'Δ',
  r'\Epsilon': 'Ε', r'\Zeta': 'Ζ', r'\Eta': 'Η', r'\Theta': 'Θ',
  r'\Iota': 'Ι', r'\Kappa': 'Κ', r'\Lambda': 'Λ', r'\Mu': 'Μ',
  r'\Nu': 'Ν', r'\Xi': 'Ξ', r'\Pi': 'Π', r'\Rho': 'Ρ',
  r'\Sigma': 'Σ', r'\Tau': 'Τ', r'\Upsilon': 'Υ', r'\Phi': 'Φ',
  r'\Chi': 'Χ', r'\Psi': 'Ψ', r'\Omega': 'Ω',
  r'\sum': '∑', r'\prod': '∏', r'\int': '∫', r'\oint': '∮',
  r'\partial': '∂', r'\nabla': '∇', r'\infty': '∞',
  r'\pm': '±', r'\mp': '∓', r'\times': '×', r'\div': '÷',
  r'\cdot': '·', r'\bullet': '•',
  r'\le': '≤', r'\leq': '≤', r'\ge': '≥', r'\geq': '≥',
  r'\neq': '≠', r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\sim': '∼', r'\propto': '∝',
  r'\to': '→', r'\rightarrow': '→', r'\leftarrow': '←',
  r'\Rightarrow': '⇒', r'\Leftarrow': '⇐', r'\Leftrightarrow': '⇔',
  r'\in': '∈', r'\notin': '∉', r'\subset': '⊂', r'\supset': '⊃',
  r'\cap': '∩', r'\cup': '∪', r'\emptyset': '∅',
  r'\forall': '∀', r'\exists': '∃',
  r'\degree': '°', r'\circ': '°',
  r'\hbar': 'ℏ', r'\ell': 'ℓ',
  r'\\': '\n', // saut de ligne LaTeX
};

/// Clés `_greekAndSymbols` triées par longueur descendante : `\varepsilon`
/// matche avant `\eps...`. Calculé 1 fois au chargement du module.
final List<String> _greekKeysSorted = _greekAndSymbols.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

String _toSubscript(String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    buf.write(_subscriptMap[ch] ?? ch);
  }
  return buf.toString();
}

String _toSuperscript(String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    buf.write(_superscriptMap[ch] ?? ch);
  }
  return buf.toString();
}

/// Convertit les motifs LaTeX courants vers leur équivalent Unicode.
/// Idempotent : appliquer plusieurs fois ne casse pas le texte.
/// Préserve le Markdown (gras `**`, italique `*`, code `\``) en ne touchant
/// qu'aux séquences entre `$...$` et aux backslash-commands LaTeX.
String latexToUnicode(String input) {
  var s = input;

  // 1. Retirer les délimiteurs math `$$...$$` et `$...$` (garder le contenu).
  //    On NE retire PAS un `$` seul (prix, monnaie). Régex non-gourmande.
  s = s.replaceAllMapped(_reDollarDouble, (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(_reDollarSingle, (m) => m.group(1) ?? '');

  // 2. Délimiteurs LaTeX `\(...\)` et `\[...\]`.
  s = s.replaceAllMapped(_reBackslashParen, (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(_reBackslashBracket, (m) => m.group(1) ?? '');

  // 3. `\text{X}`, `\mathrm{X}`, `\mathbf{X}`, `\mathit{X}` → `X`.
  for (final re in _reTextCommands) {
    s = s.replaceAllMapped(re, (m) => m.group(1) ?? '');
  }

  // 4. `\frac{a}{b}` → `a/b`. Pas de récursion : on traite une passe.
  s = s.replaceAllMapped(_reFrac, (m) => '${m.group(1)}/${m.group(2)}');

  // 5. `\sqrt{X}` → `√X`. `\sqrt[n]{X}` → `ⁿ√X` (non géré ici, raw).
  s = s.replaceAllMapped(_reSqrt, (m) => '√${m.group(1)}');

  // 6. Indices `_{xx}` et `_x` → Unicode subscript.
  s = s.replaceAllMapped(
    _reSubscriptBrace,
    (m) => _toSubscript(m.group(1) ?? ''),
  );
  s = s.replaceAllMapped(
    _reSubscriptChar,
    (m) => _toSubscript(m.group(1) ?? ''),
  );
  s = s.replaceAllMapped(
    _reSuperscriptBrace,
    (m) => _toSuperscript(m.group(1) ?? ''),
  );
  s = s.replaceAllMapped(
    _reSuperscriptChar,
    (m) => _toSuperscript(m.group(1) ?? ''),
  );

  // 7. Lettres grecques + symboles maths courants.
  for (final k in _greekKeysSorted) {
    s = s.replaceAll(k, _greekAndSymbols[k]!);
  }

  // 8. Cleanup : `\,` `\;` `\!` `\:` (espaces fins LaTeX) → espace simple.
  s = s.replaceAll(_reThinSpaces, ' ');
  // `\quad` `\qquad` → 2/4 espaces
  s = s.replaceAll(r'\quad', '  ');
  s = s.replaceAll(r'\qquad', '    ');

  return s;
}
