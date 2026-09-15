import SwiftUI
import WidgetKit

// Mirrors the Android widget; data written by lib/conso_widget.dart, same keys.

private let appGroupId = AppGroup.identifier
private let youpriceBlue = Color(red: 0x33 / 255, green: 0x99 / 255, blue: 0xFE / 255)
private let backgroundTop = Color(red: 0x2C / 255, green: 0x36 / 255, blue: 0x44 / 255)
private let backgroundBottom = Color(red: 0x1A / 255, green: 0x20 / 255, blue: 0x29 / 255)

struct ConsoData {
  let title: String
  let used: String
  let quota: String
  let progress: Int
  let time: String

  /// `nil` when logged out ("used" key absent).
  static func load() -> ConsoData? {
    guard let prefs = UserDefaults(suiteName: appGroupId),
      let used = prefs.string(forKey: "used")
    else { return nil }
    return ConsoData(
      title: prefs.string(forKey: "title") ?? "",
      used: used,
      quota: prefs.string(forKey: "quota") ?? "",
      progress: prefs.integer(forKey: "progress"),
      time: prefs.string(forKey: "time") ?? "")
  }

  static let preview = ConsoData(
    title: "06 12 34 56 78",
    used: "12,3 Go",
    quota: "sur 50 Go",
    progress: 25,
    time: "Actualisé à 09:41")
}

struct ConsoEntry: TimelineEntry {
  let date: Date
  let data: ConsoData?
}

struct ConsoProvider: TimelineProvider {
  func placeholder(in context: Context) -> ConsoEntry {
    ConsoEntry(date: Date(), data: .preview)
  }

  func getSnapshot(in context: Context, completion: @escaping (ConsoEntry) -> Void) {
    let data = ConsoData.load() ?? (context.isPreview ? .preview : nil)
    completion(ConsoEntry(date: Date(), data: data))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ConsoEntry>) -> Void) {
    // The app reloads the timeline itself after writing new data.
    let entry = ConsoEntry(date: Date(), data: ConsoData.load())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct ConsoWidgetView: View {
  let entry: ConsoEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let data = entry.data {
        WidgetHeader(title: data.title)
        Spacer(minLength: 0)
        ConsoBody(data: data)
      } else {
        WidgetHeader(title: "YouConso")
        Spacer(minLength: 0)
        Text("Identifiez-vous pour consulter votre suivi conso.")
          .font(.system(size: 14))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity, alignment: .leading)
        Spacer(minLength: 0)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetBackground(
      LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .top,
        endPoint: .bottom))
  }
}

private struct WidgetHeader: View {
  let title: String

  var body: some View {
    HStack(spacing: 8) {
      Image("WidgetLogo")
        .resizable()
        .frame(width: 20, height: 20)
      // Smaller than Android so the whole number fits in the small widget.
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ConsoBody: View {
  let data: ConsoData

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(data.used)
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(youpriceBlue)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(data.quota)
        .font(.system(size: 14))
        .foregroundColor(.white)
        .lineLimit(1)
      ProgressBar(progress: data.progress)
        .frame(height: 6)
        .padding(.top, 8)
      Text(data.time)
        .font(.system(size: 11))
        .foregroundColor(.white.opacity(0.6))
        .lineLimit(1)
        .padding(.top, 6)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ProgressBar: View {
  let progress: Int

  var body: some View {
    GeometryReader { geometry in
      let ratio = CGFloat(min(max(progress, 0), 100)) / 100
      ZStack(alignment: .leading) {
        Capsule().fill(Color.white.opacity(0.2))
        Capsule().fill(youpriceBlue).frame(width: geometry.size.width * ratio)
      }
    }
  }
}

extension View {
  /// iOS 17 requires `containerBackground`.
  @ViewBuilder
  fileprivate func widgetBackground<Background: View>(_ background: Background) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { background }
    } else {
      self.background(background)
    }
  }
}

@main
struct ConsoWidget: Widget {
  // Must match `iOSName` on the Dart side.
  let kind = "ConsoWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ConsoProvider()) { entry in
      ConsoWidgetView(entry: entry)
    }
    .configurationDisplayName("Suivi conso")
    .description("Votre consommation data Youprice.")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabled()
  }
}

struct ConsoWidget_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ConsoWidgetView(entry: ConsoEntry(date: Date(), data: .preview))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
      ConsoWidgetView(entry: ConsoEntry(date: Date(), data: nil))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
      ConsoWidgetView(entry: ConsoEntry(date: Date(), data: .preview))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
  }
}
