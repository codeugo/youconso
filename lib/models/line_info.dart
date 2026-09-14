import 'json.dart';

String formatPhone(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 10) return number;
  return [for (var i = 0; i < 10; i += 2) digits.substring(i, i + 2)].join(' ');
}

class LineInfo {
  const LineInfo({
    this.status,
    this.planName,
    this.operator,
    this.simType,
    this.has5G = false,
  });

  final String? status;
  final String? planName;
  final String? operator;
  final String? simType;
  final bool has5G;

  factory LineInfo.fromJson(Map json) => LineInfo(
    status: jsonTextOrNull(json['etatLigne']),
    planName: jsonTextOrNull(json['ypProductName']),
    operator: jsonTextOrNull(json['operateur']),
    simType: jsonTextOrNull(json['typeSim']),
    has5G: json['isOption5G'] == true,
  );

  bool get isActive => status?.toLowerCase().startsWith('acti') ?? true;

  String? get planLabel => planName?.replaceAllMapped(
    RegExp(r'^(\d+)\s*([KMGT]?o)$', caseSensitive: false),
    (m) =>
        '${m[1]} ${m[2]![0].toUpperCase()}${m[2]!.substring(1).toLowerCase()}',
  );
}
