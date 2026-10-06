import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/conso.dart';
import '../models/invoice.dart';
import '../models/line_info.dart';
import '../models/json.dart';

/// Conso of one line as last fetched.
class CachedLine {
  const CachedLine({required this.conso, this.info, required this.updatedAt});

  final Conso conso;
  final LineInfo? info;
  final DateTime updatedAt;

  static CachedLine? fromJson(dynamic json) {
    if (json is! Map) return null;
    final at = json['updatedAt'];
    if (at is! int) return null;
    final info = json['info'];
    return CachedLine(
      conso: Conso.fromJson(json['conso']),
      info: info is Map ? LineInfo.fromJson(info) : null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  Map<String, Object?> toJson() => {
    'conso': conso.toJson(),
    'info': info?.toJson(),
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
}

/// Last home screen data, shown at launch while it refreshes.
class HomeSnapshot {
  HomeSnapshot({
    this.customerName,
    this.numbers,
    this.selectedNumber,
    Map<String, CachedLine>? lines,
    this.invoices,
  }) : lines = lines ?? {};

  String? customerName;
  List<String>? numbers;
  String? selectedNumber;
  final Map<String, CachedLine> lines;
  List<Invoice>? invoices;

  factory HomeSnapshot.fromJson(Map json) {
    final numbers = json['numbers'];
    final lines = json['lines'];
    final invoices = json['invoices'];
    return HomeSnapshot(
      customerName: jsonTextOrNull(json['customerName']),
      numbers: numbers is List ? [for (final n in numbers) '$n'] : null,
      selectedNumber: jsonTextOrNull(json['selectedNumber']),
      lines: {
        if (lines is Map)
          for (final MapEntry(:key, :value) in lines.entries)
            '$key': ?CachedLine.fromJson(value),
      },
      invoices: invoices is List ? jsonList(invoices, Invoice.fromJson) : null,
    );
  }

  Map<String, Object?> toJson() => {
    'customerName': customerName,
    'numbers': numbers,
    'selectedNumber': selectedNumber,
    'lines': {
      for (final MapEntry(:key, :value) in lines.entries) key: value.toJson(),
    },
    'invoices': invoices?.map((i) => i.toJson()).toList(),
  };
}

/// [HomeSnapshot] in the shared preferences, tied to the account that
/// fetched it so another account never sees it. Failures are ignored: the
/// cache only speeds up the launch.
class HomeCache {
  static const _key = 'home_cache';

  Future<HomeSnapshot?> load(String account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonDecode(prefs.getString(_key) ?? 'null');
      if (json is! Map || json['account'] != account) return null;
      final data = json['data'];
      return data is Map ? HomeSnapshot.fromJson(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String account, HomeSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({'account': account, 'data': snapshot.toJson()}),
      );
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
