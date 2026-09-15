final _spaces = RegExp(r'\s+');

String jsonText(dynamic value) =>
    value == null ? '' : value.toString().trim().replaceAll(_spaces, ' ');

String? jsonTextOrNull(dynamic value) {
  final text = jsonText(value);
  return text.isEmpty ? null : text;
}

double? jsonNumber(dynamic value) => value is num ? value.toDouble() : null;

List<T> jsonList<T>(dynamic list, T Function(Map) build) => [
  if (list is List)
    for (final item in list)
      if (item is Map) build(item),
];
