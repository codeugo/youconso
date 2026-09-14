# YouConso

Application Flutter pour consulter sa consommation et ses factures Youprice.

```
dart format lib test
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

Le workflow GitHub `CI` rejoue formatage, analyse et tests à chaque push sur
`main` et sur chaque pull request ; `Release` construit les binaires au tag `v*`.

## Session

`YoupriceApi.session` est le seul point de vérité connecté / déconnecté :
`RootScreen` (`lib/main.dart`) l'écoute et affiche l'accueil ou la connexion.
Une réponse 401 déclenche une reconnexion silencieuse avec les identifiants
enregistrés ; si elle échoue, la session est effacée et l'écran de connexion
s'affiche avec le motif. Les tests de `test/app_flow_test.dart` couvrent ces
parcours avec un client HTTP simulé.

## Widget écran d'accueil

Le widget Android (`android/.../ConsoWidget.kt`) et le widget iOS
(`ios/ConsoWidget/ConsoWidget.swift`, extension WidgetKit `ConsoWidgetExtension`)
partagent les mêmes données, écrites par `lib/conso_widget.dart`.

Sur iOS, l'app et l'extension communiquent via l'App Group
`group.fr.youconso.youconso` : pour un build signé, activer la capability
« App Groups » avec cet identifiant sur les deux cibles (`Runner` et
`ConsoWidgetExtension`) dans le compte développeur Apple. Les outils de
sideload renomment ce groupe : `ios/Shared/AppGroup.swift` lit l'identifiant
réel dans le profil de provisioning embarqué, des deux côtés.
