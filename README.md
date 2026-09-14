# YouConso

Application Flutter pour consulter sa consommation et ses factures Youprice.

```
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

## Widget écran d'accueil

Le widget Android (`android/.../ConsoWidget.kt`) et le widget iOS
(`ios/ConsoWidget/ConsoWidget.swift`, extension WidgetKit `ConsoWidgetExtension`)
partagent les mêmes données, écrites par `lib/conso_widget.dart`.

Sur iOS, l'app et l'extension communiquent via l'App Group
`group.fr.youconso.youconso` : pour un build signé, activer la capability
« App Groups » avec cet identifiant sur les deux cibles (`Runner` et
`ConsoWidgetExtension`) dans le compte développeur Apple.
