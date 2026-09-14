import 'dart:io';

import 'package:home_widget/home_widget.dart';

import 'api/youprice_api.dart';
import 'models/conso.dart';
import 'models/line_info.dart';
import 'storage/secure_store.dart';

const _keys = ['number', 'title', 'used', 'quota', 'progress', 'time'];

Future<void> registerConsoWidget() async {
  if (Platform.isAndroid) {
    await HomeWidget.registerInteractivityCallback(_refresh);
  }
}

Future<void> updateConsoWidget(Conso conso, String number) async {
  if (!Platform.isAndroid) return;
  final detail = conso.groups
      .where((g) => g.kind == ConsoKind.data)
      .expand((g) => g.withQuota)
      .where((i) => !i.international)
      .firstOrNull
      ?.detail;
  final ratio = detail?.ratio;
  if (detail == null || ratio == null) return clearConsoWidget();
  final now = DateTime.now();
  await HomeWidget.saveWidgetData('number', number);
  await HomeWidget.saveWidgetData('title', formatPhone(number));
  await HomeWidget.saveWidgetData('used', detail.displayValue);
  await HomeWidget.saveWidgetData('quota', 'sur ${detail.quota}');
  await HomeWidget.saveWidgetData('progress', (ratio * 100).round());
  await HomeWidget.saveWidgetData(
    'time',
    'Actualisé à ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
  );
  await HomeWidget.updateWidget(androidName: 'ConsoWidget');
}

Future<void> clearConsoWidget() async {
  if (!Platform.isAndroid) return;
  for (final key in _keys) {
    await HomeWidget.saveWidgetData<String>(key, null);
  }
  await HomeWidget.updateWidget(androidName: 'ConsoWidget');
}

@pragma('vm:entry-point')
Future<void> _refresh(Uri? uri) async {
  final number = await HomeWidget.getWidgetData<String>('number');
  if (number == null) return;
  try {
    await updateConsoWidget(
      await YoupriceApi(SecureStore()).conso(number),
      number,
    );
  } on ApiException catch (e) {
    if (e.sessionLost) await clearConsoWidget();
  }
}
