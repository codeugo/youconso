import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'models/conso.dart';
import 'models/line_info.dart';

Future<void> updateConsoWidget(Conso conso, LineInfo? info) async {
  if (!Platform.isAndroid) return;
  final item = conso.groups
      .where((g) => g.kind == ConsoKind.data)
      .expand((g) => g.withQuota)
      .where((i) => !i.international)
      .firstOrNull;
  if (item == null) return;
  final detail = item.detail;
  final plan = info?.planLabel;
  await HomeWidget.saveWidgetData(
    'plan',
    plan != null ? 'Forfait $plan' : 'Internet mobile',
  );
  await HomeWidget.saveWidgetData('used', detail.displayValue);
  await HomeWidget.saveWidgetData('quota', 'sur ${detail.quota}');
  await HomeWidget.saveWidgetData(
    'progress',
    ((detail.ratio ?? 0) * 100).round(),
  );
  await HomeWidget.saveWidgetData(
    'time',
    'Mis à jour à ${DateFormat.Hm().format(DateTime.now())}',
  );
  await HomeWidget.updateWidget(androidName: 'ConsoWidget');
}
