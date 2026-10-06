// Point d'entrée pour les captures d'écran : aucune requête réseau,
// réponses simulées avec des données fictives.
//
//   flutter run -t lib/main_screenshots.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'api/youprice_api.dart';
import 'main.dart';
import 'storage/secure_store.dart';
import 'theme.dart';

const _phone = '0612345678';

const _conso = {
  'categories': [
    {
      'libelle': 'En France métropolitaine',
      'sousCategories': [
        {
          'libelle': 'Internet mobile',
          'detais': [
            {
              'libelle': 'En France',
              'valeur': '23,4 GO',
              'valeurRef': "50 GO Ajustable jusqu'à 50 GO",
            },
          ],
        },
        {
          'libelle': 'Appels',
          'detais': [
            {
              'libelle': "Heures d'appel en France",
              'valeur': '02:37:12',
              'valeurRef': null,
            },
          ],
        },
        {
          'libelle': 'SMS / MMS',
          'detais': [
            {'libelle': 'SMS envoyés', 'valeur': '184', 'valeurRef': null},
            {'libelle': 'MMS envoyés', 'valeur': '7', 'valeurRef': null},
          ],
        },
      ],
    },
    {
      'libelle': "Depuis l'international",
      'sousCategories': [
        {
          'libelle': 'Internet mobile',
          'detais': [
            {'libelle': 'Depuis Zone1', 'valeur': '1,2 GO', 'valeurRef': null},
          ],
        },
      ],
    },
  ],
};

const _line = {
  'etatLigne': 'Active',
  'ypProductName': '50Go',
  'operateur': 'SFR',
  'typeSim': 'eSim',
  'isOption5G': true,
};

const _customer = {
  'result': {'firstName': 'Camille', 'lastName': 'Martin'},
};

List<Map<String, Object>> _invoices() {
  final invoices = <Map<String, Object>>[];
  for (var i = 0; i < 8; i++) {
    final date = DateTime(2026, 9 - i, 0); // dernier jour du mois
    invoices.add({
      'id': 10000 + i,
      'invoiceName': 'Facture mensuelle',
      'invoiceDate': DateFormat("yyyy-MM-dd'T'00:00:00").format(date),
      'montantTTC': i == 0 ? 9.99 : 4.99,
      'invoiceStatus': i == 0 ? 'Impayée' : 'Payé',
      'montantRestant': i == 0 ? 9.99 : 0.0,
    });
  }
  return invoices;
}

http.Response _json(Object? body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<http.Response> _stub(http.Request request) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final path = request.url.path.split('/').last;
  return switch (path) {
    'authenticate' => _json({'access_token': 'stub', 'publicKey': 'pk'}),
    'getActiveNumero' => _json([_phone]),
    'GetCustomerBrefInfoById' => _json(_customer),
    'getSuiviConsoInfo' => _json(_conso),
    'getLigneGsm' => _json(_line),
    'getMonthlyInvoices' => _json(_invoices()),
    _ => http.Response('', 404),
  };
}

/// Session en mémoire : l'app démarre toujours sur l'écran de connexion.
class _MemoryStore extends SecureStore {
  final _data = <String, String>{};

  @override
  Future<String?> get token async => _data['token'];
  @override
  Future<String?> get publicKey async => _data['publicKey'];
  @override
  Future<String?> get username async => _data['username'];
  @override
  Future<String?> get password async => _data['password'];

  @override
  Future<void> saveSession({
    required String token,
    required String username,
    required String password,
  }) async {
    _data['token'] = token;
    _data['username'] = username;
    _data['password'] = password;
  }

  @override
  Future<void> setPublicKey(String publicKey) async =>
      _data['publicKey'] = publicKey;

  @override
  Future<void> clearSession() async => _data.clear();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  Intl.defaultLocale = 'fr_FR';
  final api = YoupriceApi(_MemoryStore(), client: MockClient(_stub));
  final settings = await ThemeSettings.load();
  await settings.setMode(ThemeMode.system);
  runApp(YouConsoApp(api: api, settings: settings));
  Timer(const Duration(seconds: 1), _prefillLogin);
}

/// Remplit les champs de connexion avec des identifiants fictifs.
void _prefillLogin() {
  const values = ['camille.martin@example.com', 'motdepasse123'];
  final fields = <EditableText>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is EditableText) fields.add(widget);
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  for (var i = 0; i < fields.length && i < values.length; i++) {
    fields[i].controller.text = values[i];
  }
}
