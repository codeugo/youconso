import 'dart:io';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'api/youprice_api.dart';
import 'models/conso.dart';
import 'models/line_info.dart';
import 'storage/secure_store.dart';

const _keys = ['number', 'title', 'used', 'quota', 'progress', 'time'];

/// Nom du widget : classe `ConsoWidget` sur Android, `kind` WidgetKit sur iOS.
const _widgetName = 'ConsoWidget';

/// App Group partagé entre l'app iOS et l'extension widget
/// (ios/Runner/Runner.entitlements, ios/ConsoWidget/ConsoWidget.entitlements).
/// Valeur de repli : le natif renvoie l'identifiant réel, qui peut être renommé
/// par un outil de sideload (voir ios/Shared/AppGroup.swift).
const _appGroupId = 'group.fr.youconso.youconso';

const _appGroupChannel = MethodChannel('fr.youconso.youconso/app_group');

bool get _supported => Platform.isAndroid || Platform.isIOS;

Future<void> registerConsoWidget() async {
  if (Platform.isAndroid) {
    await HomeWidget.registerInteractivityCallback(_refresh);
  } else if (Platform.isIOS) {
    String? groupId;
    try {
      groupId = await _appGroupChannel.invokeMethod<String>('appGroupId');
    } on PlatformException {
      groupId = null;
    } on MissingPluginException {
      groupId = null;
    }
    await HomeWidget.setAppGroupId(groupId ?? _appGroupId);
  }
}

Future<void> updateConsoWidget(Conso conso, String number) async {
  if (!_supported) return;
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
  await _reload();
}

Future<void> clearConsoWidget() async {
  if (!_supported) return;
  for (final key in _keys) {
    await HomeWidget.saveWidgetData<String>(key, null);
  }
  await _reload();
}

Future<void> _reload() =>
    HomeWidget.updateWidget(androidName: _widgetName, iOSName: _widgetName);

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
