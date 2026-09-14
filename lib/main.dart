import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'api/youprice_api.dart';
import 'conso_widget.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'storage/secure_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  Intl.defaultLocale = 'fr_FR';
  final api = YoupriceApi(SecureStore());
  final settings = await ThemeSettings.load();
  await Future.wait([api.init(), registerConsoWidget()]);
  runApp(YouConsoApp(api: api, settings: settings));
}

class YouConsoApp extends StatelessWidget {
  const YouConsoApp({super.key, required this.api, required this.settings});

  final YoupriceApi api;
  final ThemeSettings settings;

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      settings: settings,
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) =>
            ValueListenableBuilder<ThemeMode>(
              valueListenable: settings,
              builder: (context, mode, _) => MaterialApp(
                title: 'YouConso',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  colorScheme: lightDynamic ?? youpriceScheme(Brightness.light),
                  useMaterial3: true,
                ),
                darkTheme: ThemeData(
                  colorScheme: darkDynamic ?? youpriceScheme(Brightness.dark),
                  useMaterial3: true,
                ),
                themeMode: mode,
                locale: const Locale('fr', 'FR'),
                supportedLocales: const [Locale('fr', 'FR')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: RootScreen(api: api),
              ),
            ),
      ),
    );
  }
}

/// Affiche l'accueil ou la connexion selon [YoupriceApi.session]. Les écrans
/// n'ont donc jamais à naviguer l'un vers l'autre : connexion, déconnexion et
/// session expirée passent toutes par ce même état.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key, required this.api});

  final YoupriceApi api;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Session>(
      valueListenable: api.session,
      builder: (context, session, _) => session.active
          ? HomeScreen(api: api)
          : LoginScreen(api: api, message: session.message),
    );
  }
}
