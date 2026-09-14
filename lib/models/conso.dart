class Conso {
  const Conso(this.categories);

  final List<ConsoCategory> categories;

  factory Conso.fromJson(dynamic json) => Conso(
    _mapList(json is Map ? json['categories'] : null, ConsoCategory.fromJson),
  );

  List<ConsoGroup> get groups {
    final groups = <String, ConsoGroup>{};
    for (final category in categories) {
      for (final sub in category.subCategories) {
        final group = groups.putIfAbsent(
          sub.label.toLowerCase(),
          () => ConsoGroup(label: sub.label, kind: sub.kind),
        );
        for (final detail in sub.details) {
          group.items.add(
            ConsoItem(
              detail: detail,
              categoryLabel: category.label,
              international: category.isInternational,
            ),
          );
        }
      }
    }
    return groups.values.toList();
  }
}

class ConsoGroup {
  ConsoGroup({required this.label, required this.kind});

  final String label;
  final ConsoKind kind;
  final List<ConsoItem> items = [];

  List<ConsoItem> get withQuota =>
      items.where((i) => i.detail.hasQuota).toList();
  List<ConsoItem> get simple => items.where((i) => !i.detail.hasQuota).toList();
}

class ConsoItem {
  const ConsoItem({
    required this.detail,
    required this.categoryLabel,
    required this.international,
  });

  final ConsoDetail detail;
  final String categoryLabel;
  final bool international;
}

class ConsoCategory {
  const ConsoCategory({required this.label, required this.subCategories});

  final String label;
  final List<ConsoSubCategory> subCategories;

  factory ConsoCategory.fromJson(Map json) => ConsoCategory(
    label: _text(json['libelle']),
    subCategories: _mapList(json['sousCategories'], ConsoSubCategory.fromJson),
  );

  bool get isInternational {
    final l = label.toLowerCase();
    return l.contains('international') ||
        l.contains('étranger') ||
        l.contains('europe') ||
        l.contains('roaming');
  }
}

class ConsoSubCategory {
  const ConsoSubCategory({required this.label, required this.details});

  final String label;
  final List<ConsoDetail> details;

  factory ConsoSubCategory.fromJson(Map json) => ConsoSubCategory(
    label: _text(json['libelle']),
    details: _mapList(json['detais'], ConsoDetail.fromJson),
  );

  ConsoKind get kind {
    final l = label.toLowerCase();
    if (l.contains('internet') || l.contains('data') || l.contains('donn')) {
      return ConsoKind.data;
    }
    if (l.contains('appel') || l.contains('voix') || l.contains('heure')) {
      return ConsoKind.calls;
    }
    if (l.contains('sms') || l.contains('mms') || l.contains('message')) {
      return ConsoKind.sms;
    }
    return ConsoKind.other;
  }
}

enum ConsoKind { data, calls, sms, other }

class ConsoDetail {
  const ConsoDetail({
    required this.label,
    required this.value,
    required this.refValue,
  });

  final String label;
  final String value;
  final String refValue;

  factory ConsoDetail.fromJson(Map json) => ConsoDetail(
    label: _text(json['libelle'])
        .replaceFirst("Heures d'appel", "Temps d'appel"),
    value: _text(json['valeur']),
    refValue: _text(json['valeurRef']),
  );

  bool get hasQuota => refValue.isNotEmpty;

  String get displayValue => _prettify(value);

  String? get quota {
    if (!hasQuota) return null;
    final match = _quantityRe.firstMatch(refValue);
    return _prettify(match?.group(0) ?? refValue);
  }

  String? get quotaNote {
    if (!hasQuota) return null;
    final match = _quantityRe.firstMatch(refValue);
    if (match == null) return null;
    final rest = refValue.substring(match.end).trim();
    return rest.isEmpty ? null : _prettify(rest);
  }

  double? get ratio {
    if (!hasQuota) return null;
    final used = _number(value);
    final total = _number(refValue);
    if (used == null || total == null || total <= 0) return null;
    final v = used / total;
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  String? get remaining {
    final used = _number(value);
    final total = _number(refValue);
    final quota = this.quota;
    if (used == null || total == null || quota == null) return null;
    final left = used >= total ? 0.0 : total - used;
    final number = left == left.roundToDouble()
        ? '${left.round()}'
        : left.toStringAsFixed(1).replaceAll('.', ',');
    final unit = quota.replaceFirst(RegExp(r'^[\d.,]+\s*'), '');
    return unit.isEmpty ? number : '$number $unit';
  }

  static double? _number(String text) {
    final duration = _parseDuration(text);
    if (duration != null) return duration.inSeconds / 60;
    final match = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }
}

final _quantityRe = RegExp(r'\d+(?:[.,]\d+)?\s*[A-Za-zÀ-ÿ]*');

String _prettify(String text) {
  final duration = _parseDuration(text.trim());
  if (duration != null) return formatDuration(duration);
  return text
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(
        RegExp(r'\b([KMGT])O\b', caseSensitive: false),
        (m) => '${m[1]!.toUpperCase()}o',
      );
}

Duration? _parseDuration(String text) {
  final match = RegExp(r'^(\d{1,3}):(\d{2}):(\d{2})$').firstMatch(text);
  if (match == null) return null;
  return Duration(
    hours: int.parse(match[1]!),
    minutes: int.parse(match[2]!),
    seconds: int.parse(match[3]!),
  );
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
  if (m > 0) return '$m min ${s.toString().padLeft(2, '0')} s';
  return '$s s';
}

String _text(dynamic value) => value == null
    ? ''
    : value.toString().trim().replaceAll(RegExp(r'\s+'), ' ');

List<T> _mapList<T>(dynamic list, T Function(Map) build) => [
  if (list is List)
    for (final item in list)
      if (item is Map) build(item),
];
