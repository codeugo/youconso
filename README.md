# YouConso

Application Flutter pour consulter sa consommation et ses factures Youprice.

## Environnement de dev

```
brew install --cask flutter
flutter doctor
flutter pub get
```

Xcode pour iOS, Android Studio pour Android. `flutter doctor` indique ce qui manque.

## Lancer et vérifier

```
flutter run
flutter analyze
flutter test
```

## Installer sur iOS

Simulateur ou iPhone branché : `flutter run -d ios`. Pour un iPhone, ouvrir
`ios/Runner.xcworkspace` dans Xcode et choisir une équipe de signature.
Sinon, sideloader l'IPA publié dans les releases GitHub.

## Installer sur Android

```
flutter build apk --release --split-per-abi
```

Installer l'APK de `build/app/outputs/flutter-apk/` sur le téléphone, ou
prendre celui des releases GitHub.
