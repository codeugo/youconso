import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youconso/api/youprice_api.dart';
import 'package:youconso/main.dart';
import 'package:youconso/models/conso.dart';
import 'package:youconso/screens/home_screen.dart';
import 'package:youconso/screens/login_screen.dart';
import 'package:youconso/storage/home_cache.dart';
import 'package:youconso/storage/secure_store.dart';
import 'package:youconso/widgets/conso_card.dart';
import 'package:youconso/widgets/invoice_tile.dart';

import 'fixtures.dart';

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Future<http.Response> happyBackend(http.Request request) async {
  final path = request.url.path.split('/').last;
  return switch (path) {
    'authenticate' => json({'access_token': 'tok', 'publicKey': 'pk'}),
    'getActiveNumero' => json([phoneNumber]),
    'GetCustomerBrefInfoById' => json(realCustomer),
    'getSuiviConsoInfo' => json(realConso),
    'getLigneGsm' => json(realLine),
    'getMonthlyInvoices' => json([realInvoice]),
    _ => http.Response('', 404),
  };
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<YoupriceApi> pumpApp(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    Map<String, String> stored = const {},
    Map<String, Object> prefs = const {},
  }) async {
    // Tall enough for every conso card: the list builds only visible ones.
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({...stored});
    SharedPreferences.setMockInitialValues({...prefs});
    final api = YoupriceApi(SecureStore(), client: MockClient(handler));
    await api.init();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr', 'FR'),
        home: RootScreen(api: api),
      ),
    );
    return api;
  }

  testWidgets('connexion puis accueil avec conso et factures', (tester) async {
    final api = await pumpApp(tester, happyBackend);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identifiant (e-mail)'),
      'jean@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'secret',
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(api.session.value.active, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(find.text('06 12 34 56 78'), findsOneWidget);
    expect(find.text('Forfait 50 Go'), findsOneWidget);
    expect(find.byType(ConsoCard), findsNWidgets(2));

    await tester.tap(find.text('Factures'));
    await tester.pumpAndSettle();
    expect(find.byType(InvoiceTile), findsOneWidget);
    expect(find.text('Août 2026'), findsOneWidget);
  });

  testWidgets('connexion avec code de vérification', (tester) async {
    var codeAccepted = false;
    final api = await pumpApp(tester, (request) async {
      final path = request.url.path.split('/').last;
      if (path == 'authenticate') return json({});
      if (path == 'authenticateWithCode') {
        codeAccepted = jsonDecode(request.body)['code'] == '1234';
        return codeAccepted ? json({'access_token': 'tok'}) : json({});
      }
      return happyBackend(request);
    });

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identifiant (e-mail)'),
      'jean@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'secret',
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.textContaining('code de vérification'), findsOneWidget);
    expect(api.session.value.active, isFalse);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Code de vérification'),
      '1234',
    );
    await tester.tap(find.text('Valider le code'));
    await tester.pumpAndSettle();
    expect(codeAccepted, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('session enregistrée : accueil direct', (tester) async {
    await pumpApp(
      tester,
      happyBackend,
      stored: {'user_token': 'tok', 'username': 'u', 'password': 'p'},
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Jean Dupont'), findsOneWidget);
  });

  testWidgets('session expirée : retour à la connexion avec le motif', (
    tester,
  ) async {
    final api = await pumpApp(
      tester,
      (request) async => http.Response('', 401),
      stored: {'user_token': 'old', 'username': 'u', 'password': 'p'},
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpAndSettle();

    expect(api.session.value.active, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Session expirée, veuillez vous reconnecter.'),
      findsOneWidget,
    );
  });

  testWidgets('erreur serveur au démarrage : bouton Réessayer', (tester) async {
    var failing = true;
    await pumpApp(
      tester,
      (request) async =>
          failing ? http.Response('', 503) : happyBackend(request),
      stored: {'user_token': 'tok', 'username': 'u', 'password': 'p'},
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    failing = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Jean Dupont'), findsOneWidget);
  });

  testWidgets('déconnexion confirmée : écran de connexion', (tester) async {
    final api = await pumpApp(
      tester,
      happyBackend,
      stored: {'user_token': 'tok', 'username': 'u', 'password': 'p'},
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Se déconnecter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
    await tester.pumpAndSettle();

    expect(api.session.value.active, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await SecureStore().token, isNull);
  });

  group('cache local', () {
    const session = {'user_token': 'tok', 'username': 'u', 'password': 'p'};

    Map<String, Object> cacheFor(String account) => {
      'home_cache': jsonEncode({
        'account': account,
        'data': HomeSnapshot(
          customerName: 'Jean Dupont',
          numbers: [phoneNumber],
          selectedNumber: phoneNumber,
          lines: {
            phoneNumber: CachedLine(
              conso: Conso.fromJson(realConso),
              updatedAt: DateTime(2026, 10, 1, 9, 30),
            ),
          },
        ).toJson(),
      }),
    };

    testWidgets('affiché tout de suite, avant la réponse du serveur', (
      tester,
    ) async {
      final pending = Completer<http.Response>();
      await pumpApp(
        tester,
        (_) => pending.future,
        stored: session,
        prefs: cacheFor('u'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Jean Dupont'), findsOneWidget);
      expect(find.text('06 12 34 56 78'), findsOneWidget);
      expect(find.byType(ConsoCard), findsNWidgets(2));
      expect(find.textContaining('Actualisé le 1 oct.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.complete(http.Response('', 503));
      await tester.pumpAndSettle();
    });

    testWidgets("ignoré s'il appartient à un autre compte", (tester) async {
      final pending = Completer<http.Response>();
      await pumpApp(
        tester,
        (_) => pending.future,
        stored: session,
        prefs: cacheFor('autre'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Jean Dupont'), findsNothing);
      expect(find.text('YouConso'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(http.Response('', 503));
      await tester.pumpAndSettle();
    });

    testWidgets('mis à jour après actualisation, effacé à la déconnexion', (
      tester,
    ) async {
      await pumpApp(tester, happyBackend, stored: session);
      await tester.pumpAndSettle();
      expect(await HomeCache().load('u'), isNotNull);
      expect((await HomeCache().load('u'))!.invoices, hasLength(1));

      await tester.tap(find.byTooltip('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
      await tester.pumpAndSettle();
      expect(await HomeCache().load('u'), isNull);
    });

    testWidgets('erreur réseau : les données en cache restent affichées', (
      tester,
    ) async {
      await pumpApp(
        tester,
        (_) async => http.Response('', 503),
        stored: session,
        prefs: cacheFor('u'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConsoCard), findsNWidgets(2));
      expect(find.textContaining('Actualisation impossible'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
    });
  });
}
