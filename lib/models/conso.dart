import 'dart:math' as math;

import 'json.dart';

class Conso {
  Conso(this.categories);

  final List<ConsoCategory> categories;

  factory Conso.fromJson(dynamic json) => Conso(
    jsonList(json is Map ? json['categories'] : null, ConsoCategory.fromJson),
  );

  /// Same shape as the API response, for the local cache.
  Map<String, Object?> toJson() => {
    'categories': [for (final c in categories) c.toJson()],
  };

  /// Cards to show: details grouped by sub-category, France and international
  /// together, calls and SMS in a single card.
  late final List<ConsoGroup> groups = _groupsOf(categories);

  static List<ConsoGroup> _groupsOf(List<ConsoCategory> categories) {
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
    if (groups.isEmpty) return const [];
    // Youprice omits unused services: show them at zero instead.
    for (final placeholder in _placeholders) {
      if (groups.values.every((g) => g.kind != placeholder.kind)) {
        groups[placeholder.label.toLowerCase()] = placeholder;
      }
    }
    List<ConsoGroup> ofKind(ConsoKind kind) =>
        groups.values.where((g) => g.kind == kind).toList();
    return [
      ...ofKind(ConsoKind.data),
      // A few plain rows each: one card for both.
      ConsoGroup(label: 'Appels et SMS', kind: ConsoKind.calls)
        ..items.addAll([
          for (final group in [
            ...ofKind(ConsoKind.calls),
            ...ofKind(ConsoKind.sms),
          ])
            ...group.items,
        ]),
      ...ofKind(ConsoKind.other),
    ];
  }

  static List<ConsoGroup> get _placeholders => [
    ConsoGroup.unused(ConsoKind.data, 'Internet mobile', {'En France': '0 MO'}),
    ConsoGroup.unused(ConsoKind.calls, 'Appels', {
      "Temps d'appel en France": '00:00:00',
    }),
    ConsoGroup.unused(ConsoKind.sms, 'SMS / MMS', {
      'SMS envoyés': '0',
      'MMS envoyés': '0',
    }),
  ];
}

class ConsoGroup {
  ConsoGroup({required this.label, required this.kind});

  /// A service absent from the response: nothing consumed this month.
  ConsoGroup.unused(this.kind, this.label, Map<String, String> values) {
    for (final MapEntry(key: label, :value) in values.entries) {
      items.add(
        ConsoItem(
          detail: ConsoDetail(label: label, value: value, refValue: ''),
          categoryLabel: '',
          international: false,
        ),
      );
    }
  }

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
    label: jsonText(json['libelle']),
    subCategories: jsonList(json['sousCategories'], ConsoSubCategory.fromJson),
  );

  Map<String, Object?> toJson() => {
    'libelle': label,
    'sousCategories': [for (final s in subCategories) s.toJson()],
  };

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
    label: jsonText(json['libelle']),
    // "detais" (sic) is the actual API key.
    details: jsonList(json['detais'], ConsoDetail.fromJson),
  );

  Map<String, Object?> toJson() => {
    'libelle': label,
    'detais': [for (final d in details) d.toJson()],
  };

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
    label: jsonText(json['libelle'])
        .replaceFirst("Heures d'appel", "Temps d'appel"),
    value: jsonText(json['valeur']),
    refValue: jsonText(json['valeurRef']),
  );

  Map<String, Object?> toJson() => {
    'libelle': label,
    'valeur': value,
    'valeurRef': refValue,
  };

  bool get hasQuota => refValue.isNotEmpty;

  String get displayValue => _prettify(value);

  String? get quota {
    if (!hasQuota) return null;
    if (_parseDuration(refValue) != null) return _prettify(refValue);
    final match = _quantityRe.firstMatch(refValue);
    return _prettify(match?.group(0) ?? refValue);
  }

  String? get quotaNote {
    if (!hasQuota || _parseDuration(refValue) != null) return null;
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

  /// Minutes for durations, Mo for data sizes ("201,6 MO" vs "300 GO").
  static double? _number(String text) {
    final duration = _parseDuration(text);
    if (duration != null) return duration.inSeconds / 60;
    final match = _numberRe.firstMatch(text);
    if (match == null) return null;
    final number = double.tryParse(match[1]!.replaceAll(',', '.'));
    if (number == null) return null;
    final unit = match[2]?.toUpperCase();
    final exponent = unit == null ? 0 : 'KMGT'.indexOf(unit) - 1;
    return number * math.pow(1024, exponent);
  }
}

final _numberRe = RegExp(
  r'(-?\d+(?:[.,]\d+)?)(?:\s*([KMGT])O\b)?',
  caseSensitive: false,
);
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
  if (s == 0) return '0 min';
  return '$s s';
}
