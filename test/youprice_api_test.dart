import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youconso/api/youprice_api.dart';
import 'package:youconso/storage/secure_store.dart';

import 'fixtures.dart';

typedef Handler = Future<http.Response> Function(http.Request request);

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

const storedSession = {
  'user_token': 'old-token',
  'username': 'jean@example.com',
  'password': 'secret',
  'public_key': 'pk',
};

void main() {
  late List<http.Request> requests;
  late SecureStore store;

  YoupriceApi api(Handler handler, {Map<String, String> stored = const {}}) {
    FlutterSecureStorage.setMockInitialValues({...stored});
    store = SecureStore();
    return YoupriceApi(
      store,
      client: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  setUp(() => requests = []);

  group('login', () {
    test('réussie : session active et identifiants enregistrés', () async {
      final client = api(
        (r) async => json({'access_token': 'tok', 'publicKey': 'new-pk'}),
      );
      expect(
        await client.login('jean@example.com', 'secret'),
        LoginResult.loggedIn,
      );
      expect(client.session.value.active, isTrue);
      expect(await store.token, 'tok');
      expect(await store.username, 'jean@example.com');
      expect(await store.password, 'secret');
      expect(await store.publicKey, 'new-pk');

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/Auth/authenticate'));
      expect(jsonDecode(request.body), {
        'username': 'jean@example.com',
        'password': 'secret',
        'publicKey': '',
      });
    });

    test('renvoie la publicKey connue pour éviter le code', () async {
      final client = api(
        (r) async => json({'access_token': 'tok'}),
        stored: {'public_key': 'pk'},
      );
      await client.login('u', 'p');
      expect(jsonDecode(requests.single.body)['publicKey'], 'pk');
    });

    test('code requis : 200 sans jeton', () async {
      final client = api((r) async => json({'message': 'code envoyé'}));
      expect(await client.login('u', 'p'), LoginResult.codeRequired);
      expect(client.session.value.active, isFalse);
      expect(await store.token, isNull);
    });

    test('refusée : message de l\'API', () async {
      final client = api(
        (r) async => json({'errorDescription': 'Compte bloqué'}, 401),
      );
      expect(
        () => client.login('u', 'p'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Compte bloqué')
              .having((e) => e.sessionLost, 'sessionLost', isFalse),
        ),
      );
    });

    test('refusée : message par défaut selon le statut', () async {
      final client = api((r) async => http.Response('', 401));
      expect(
        () => client.login('u', 'p'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Identifiant ou mot de passe incorrect.',
          ),
        ),
      );
    });

    test('loginWithCode : code invalide', () async {
      final client = api((r) async => json({}));
      expect(
        () => client.loginWithCode('u', 'p', '0000'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Code invalide ou expiré.',
          ),
        ),
      );
    });

    test('loginWithCode : succès', () async {
      final client = api((r) async => json({'access_token': 'tok'}));
      await client.loginWithCode('u', 'p', '1234');
      expect(client.session.value.active, isTrue);
      expect(jsonDecode(requests.single.body)['code'], '1234');
    });
  });

  group('init / logout', () {
    test('init lit la session enregistrée', () async {
      final client = api((r) async => json(null), stored: storedSession);
      expect(client.session.value.active, isFalse);
      await client.init();
      expect(client.session.value.active, isTrue);
    });

    test('logout efface la session mais garde la publicKey', () async {
      final client = api((r) async => json(null), stored: storedSession);
      await client.init();
      await client.logout();
      expect(client.session.value.active, isFalse);
      expect(client.session.value.message, isNull);
      expect(await store.token, isNull);
      expect(await store.password, isNull);
      expect(await store.publicKey, 'pk');
    });
  });

  group('requêtes authentifiées', () {
    test('envoient le jeton et un identifiant de requête', () async {
      final client = api(
        (r) async => json([phoneNumber]),
        stored: storedSession,
      );
      expect(await client.activeNumbers(), [phoneNumber]);
      final headers = requests.single.headers;
      expect(headers['authorization'], 'Bearer old-token');
      expect(headers['x-requestid'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('sans jeton : non connecté', () async {
      final client = api((r) async => json([]));
      await expectLater(
        client.activeNumbers(),
        throwsA(
          isA<ApiException>().having((e) => e.sessionLost, 'sessionLost', true),
        ),
      );
      expect(requests, isEmpty);
    });

    test(
      'jeton expiré : reconnexion silencieuse puis nouvelle tentative',
      () async {
        final client = api((r) async {
          if (r.url.path.endsWith('/Auth/authenticate')) {
            return json({'access_token': 'new-token'});
          }
          return r.headers['authorization'] == 'Bearer new-token'
              ? json([phoneNumber])
              : http.Response('', 401);
        }, stored: storedSession);
        await client.init();

        expect(await client.activeNumbers(), [phoneNumber]);
        expect(requests.map((r) => r.url.path.split('/').last), [
          'getActiveNumero',
          'authenticate',
          'getActiveNumero',
        ]);
        expect(jsonDecode(requests[1].body), {
          'username': 'jean@example.com',
          'password': 'secret',
          'publicKey': 'pk',
        });
        expect(await store.token, 'new-token');
        expect(client.session.value.active, isTrue);
      },
    );

    test('jetons expirés en parallèle : une seule reconnexion', () async {
      final client = api((r) async {
        if (r.url.path.endsWith('/Auth/authenticate')) {
          return json({'access_token': 'new-token'});
        }
        return r.headers['authorization'] == 'Bearer new-token'
            ? json([phoneNumber])
            : http.Response('', 401);
      }, stored: storedSession);
      await client.init();

      final results = await Future.wait([
        client.activeNumbers(),
        client.activeNumbers(),
      ]);
      expect(results, [
        [phoneNumber],
        [phoneNumber],
      ]);
      expect(
        requests.where((r) => r.url.path.endsWith('/Auth/authenticate')),
        hasLength(1),
      );
      expect(client.session.value.active, isTrue);
    });

    for (final (label, authResponse) in [
      ('identifiants refusés', http.Response('', 401)),
      ('code de vérification exigé', json({})),
    ]) {
      test('reconnexion impossible ($label) : session perdue', () async {
        final client = api((r) async {
          if (r.url.path.endsWith('/Auth/authenticate')) return authResponse;
          return http.Response('', 401);
        }, stored: storedSession);
        await client.init();

        await expectLater(
          client.activeNumbers(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.sessionLost, 'sessionLost', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  'Session expirée, veuillez vous reconnecter.',
                ),
          ),
        );
        expect(client.session.value.active, isFalse);
        expect(
          client.session.value.message,
          'Session expirée, veuillez vous reconnecter.',
        );
        expect(await store.token, isNull);
        expect(await store.password, isNull);
        expect(requests, hasLength(2), reason: 'pas de boucle de relance');
      });
    }

    test('erreur HTTP : message sans perdre la session', () async {
      final client = api(
        (r) async => http.Response('', 503),
        stored: storedSession,
      );
      await client.init();
      await expectLater(
        client.activeNumbers(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.sessionLost, 'sessionLost', isFalse)
              .having((e) => e.message, 'message', contains('503')),
        ),
      );
      expect(client.session.value.active, isTrue);
    });

    test('erreur réseau', () async {
      final client = api(
        (r) async => throw const SocketException('down'),
        stored: storedSession,
      );
      expect(
        () => client.activeNumbers(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Pas de connexion réseau.',
          ),
        ),
      );
    });
  });

  group('lectures', () {
    test('customerName', () async {
      final client = api(
        (r) async => json(realCustomer),
        stored: storedSession,
      );
      expect(await client.customerName(), 'Jean Dupont');
    });

    test('conso : POST avec le numéro en query et en corps', () async {
      final client = api((r) async => json(realConso), stored: storedSession);
      final conso = await client.conso(phoneNumber);
      expect(conso.groups, hasLength(2));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.queryParameters, {'phoneNumber': phoneNumber});
      expect(request.body, jsonEncode(phoneNumber));
    });

    test('lineInfo', () async {
      final client = api((r) async => json(realLine), stored: storedSession);
      expect((await client.lineInfo(phoneNumber)).operator, 'SFR');
      expect(requests.single.url.queryParameters, {'phoneNumber': phoneNumber});
    });

    test('invoices : triées de la plus récente à la plus ancienne', () async {
      final client = api(
        (r) async => json({
          'result': [
            {...realInvoice, 'id': 1, 'invoiceDate': '2026-06-30T00:00:00'},
            {...realInvoice, 'id': 2, 'invoiceDate': '2026-08-31T00:00:00'},
            {...realInvoice, 'id': 3, 'invoiceDate': '2026-07-31T00:00:00'},
          ],
        }),
        stored: storedSession,
      );
      final invoices = await client.invoices();
      expect(invoices.map((i) => i.id), ['2', '3', '1']);
    });

    test('invoicePdf : renvoie les octets d\'un vrai PDF', () async {
      final client = api(
        (r) async => http.Response.bytes('%PDF-1.4 ...'.codeUnits, 200),
        stored: storedSession,
      );
      final bytes = await client.invoicePdf('42');
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(requests.single.headers['accept'], 'application/pdf');
      expect(requests.single.url.queryParameters, {'id': '42'});
    });

    test('invoicePdf : refuse une réponse qui n\'est pas un PDF', () async {
      final client = api(
        (r) async => json({'error': 'nope'}),
        stored: storedSession,
      );
      expect(
        () => client.invoicePdf('42'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('PDF'),
          ),
        ),
      );
    });
  });
}
