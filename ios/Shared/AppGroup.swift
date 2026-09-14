import Foundation

/// Identifiant de l'App Group partagé entre l'app et l'extension widget.
///
/// Compilé dans les deux cibles (Runner et ConsoWidgetExtension). Les outils de
/// sideload (AltStore, Sideloadly…) renomment les groupes d'apps en y ajoutant le
/// Team ID : on lit donc l'identifiant réel dans le profil de provisioning embarqué
/// et on retombe sur la valeur des entitlements du dépôt (build App Store, sans
/// profil embarqué).
enum AppGroup {
  static let fallback = "group.fr.youconso.youconso"

  static let identifier: String = fromProvisioningProfile() ?? fallback

  private static func fromProvisioningProfile() -> String? {
    guard
      let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: url),
      let start = data.range(of: Data("<?xml".utf8)),
      let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
    else { return nil }
    let plist = Data(data[start.lowerBound..<end.upperBound])
    guard
      let root = try? PropertyListSerialization.propertyList(from: plist, format: nil)
        as? [String: Any],
      let entitlements = root["Entitlements"] as? [String: Any],
      let groups = entitlements["com.apple.security.application-groups"] as? [String]
    else { return nil }
    return groups.first
  }
}
