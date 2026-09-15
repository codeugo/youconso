import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const youpriceBlue = Color(0xFF3399FE);

ColorScheme youpriceScheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: youpriceBlue,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  return brightness == Brightness.light
      ? scheme.copyWith(primary: youpriceBlue)
      : scheme;
}

class ThemeSettings extends ValueNotifier<ThemeMode> {
  ThemeSettings._(super.value);

  static const _key = 'theme_mode';

  static Future<ThemeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    return ThemeSettings._(
      ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      ),
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == value) return;
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  static String label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Suivre le système',
    ThemeMode.light => 'Clair',
    ThemeMode.dark => 'Sombre',
  };
}

class ThemeScope extends InheritedNotifier<ThemeSettings> {
  const ThemeScope({
    super.key,
    required ThemeSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static ThemeSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.notifier!;
}

Future<void> showThemeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      // ThemeScope is an InheritedNotifier: this builder rebuilds on change.
      final settings = ThemeScope.of(context);
      return AlertDialog(
        title: const Text('Thème'),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SizedBox(
          width: double.maxFinite,
          child: RadioGroup<ThemeMode>(
            groupValue: settings.value,
            onChanged: (value) {
              if (value != null) settings.setMode(value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: m,
                    title: Text(ThemeSettings.label(m)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      );
    },
  );
}
