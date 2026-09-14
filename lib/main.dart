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
  final settings = await ThemeSettings.load();
  await registerConsoWidget();
  runApp(YouConsoApp(api: YoupriceApi(SecureStore()), settings: settings));
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
                home: _Root(api: api),
              ),
            ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root({required this.api});

  final YoupriceApi api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: api.hasSession(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? HomeScreen(api: api) : LoginScreen(api: api);
      },
    );
  }
}
