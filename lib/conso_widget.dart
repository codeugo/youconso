import 'dart:io';

import 'package:home_widget/home_widget.dart';

import 'models/conso.dart';
import 'models/line_info.dart';

const _keys = ['title', 'value', 'progress'];

Future<void> updateConsoWidget(Conso conso, String number) async {
  if (!Platform.isAndroid) return;
  final detail = conso.groups
      .where((g) => g.kind == ConsoKind.data)
      .expand((g) => g.withQuota)
      .where((i) => !i.international)
      .firstOrNull
      ?.detail;
  final remaining = detail?.remaining;
  final ratio = detail?.ratio;
  if (remaining == null || ratio == null) return clearConsoWidget();
  await HomeWidget.saveWidgetData('title', formatPhone(number));
  await HomeWidget.saveWidgetData('value', remaining);
  await HomeWidget.saveWidgetData('progress', ((1 - ratio) * 100).round());
  await HomeWidget.updateWidget(androidName: 'ConsoWidget');
}

Future<void> clearConsoWidget() async {
  if (!Platform.isAndroid) return;
  for (final key in _keys) {
    await HomeWidget.saveWidgetData<String>(key, null);
  }
  await HomeWidget.updateWidget(androidName: 'ConsoWidget');
}
