/// Aides de parsing partagées par les modèles.
///
/// L'API Youprice renvoie des champs parfois absents, nuls, numériques là où
/// on attend du texte, ou avec des espaces parasites : on normalise tout ici.
library;

final _spaces = RegExp(r'\s+');

/// Texte nettoyé (espaces multiples réduits), chaîne vide si absent.
String jsonText(dynamic value) =>
    value == null ? '' : value.toString().trim().replaceAll(_spaces, ' ');

/// Comme [jsonText], mais `null` plutôt qu'une chaîne vide.
String? jsonTextOrNull(dynamic value) {
  final text = jsonText(value);
  return text.isEmpty ? null : text;
}

double? jsonNumber(dynamic value) => value is num ? value.toDouble() : null;

/// Construit un objet par élément de [list] qui est bien un `Map`, ignore le reste.
List<T> jsonList<T>(dynamic list, T Function(Map) build) => [
  if (list is List)
    for (final item in list)
      if (item is Map) build(item),
];
