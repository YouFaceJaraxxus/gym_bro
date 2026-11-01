import SwiftUI
import WidgetKit

/// Shared by the app (Flutter, through home_widget / live_activities) and this
/// extension. Must match `kAppGroupId` in lib/services/home_widget_service.dart
/// and the App Group in both targets' entitlements.
let gymBroAppGroup = "group.com.example.gymBroMobile"

enum GB {
  static let card = Color(red: 0x14 / 255, green: 0x16 / 255, blue: 0x1B / 255)
  static let cardRaised = Color(red: 0x22 / 255, green: 0x25 / 255, blue: 0x2C / 255)
  static let flame = Color(red: 0xFF / 255, green: 0x7A / 255, blue: 0x1A / 255)
  static let water = Color(red: 0x19 / 255, green: 0x76 / 255, blue: 0xD2 / 255)
  static let waterLight = Color(red: 0x7C / 255, green: 0xC4 / 255, blue: 0xFA / 255)
  static let risk = Color(red: 0xFF / 255, green: 0x5A / 255, blue: 0x5F / 255)
  static let muted = Color.white.opacity(0.62)
}

/// What the app last wrote for the widgets (see HomeWidgetService).
struct GymBroData {
  var signedIn = false
  var day = ""

  var streak = 0
  var streakLit = false
  var streakRisk = false
  var streakTier = ""
  var streakTitle = "Streak"
  var streakLabel = "workouts in a row"
  var streakRiskLabel = "Train today to keep it"

  var waterMl = 0
  var waterGoalMl = 0
  var waterTitle = "Water"
  var waterText = ""

  var todayTitle = "Today"
  var workoutName = ""
  var workoutStatus = ""
  var workoutDone = false
  var workoutFree = false

  var signedOutLabel = "Sign in to Gym Bro"
  var staleLabel = "Open Gym Bro to refresh"

  static func load() -> GymBroData {
    var d = GymBroData()
    guard let defaults = UserDefaults(suiteName: gymBroAppGroup) else { return d }
    func str(_ key: String, _ fallback: String) -> String {
      let v = defaults.string(forKey: key) ?? ""
      return v.isEmpty ? fallback : v
    }
    d.signedIn = defaults.bool(forKey: "gb_signed_in")
    d.day = defaults.string(forKey: "gb_day") ?? ""
    d.streak = defaults.integer(forKey: "gb_streak")
    d.streakLit = defaults.bool(forKey: "gb_streak_lit")
    d.streakRisk = defaults.bool(forKey: "gb_streak_risk")
    d.streakTier = defaults.string(forKey: "gb_streak_tier") ?? ""
    d.streakTitle = str("gb_streak_title", d.streakTitle)
    d.streakLabel = str("gb_streak_label", d.streakLabel)
    d.streakRiskLabel = str("gb_streak_risk_label", d.streakRiskLabel)
    d.waterMl = defaults.integer(forKey: "gb_water_ml")
    d.waterGoalMl = defaults.integer(forKey: "gb_water_goal_ml")
    d.waterTitle = str("gb_water_title", d.waterTitle)
    d.waterText = defaults.string(forKey: "gb_water_text") ?? ""
    d.todayTitle = str("gb_today_title", d.todayTitle)
    d.workoutName = defaults.string(forKey: "gb_workout_name") ?? ""
    d.workoutStatus = defaults.string(forKey: "gb_workout_status") ?? ""
    d.workoutDone = defaults.bool(forKey: "gb_workout_done")
    d.workoutFree = defaults.bool(forKey: "gb_workout_free")
    d.signedOutLabel = str("gb_signed_out_label", d.signedOutLabel)
    d.staleLabel = str("gb_stale_label", d.staleLabel)
    return d
  }

  /// Written on an earlier day: today's water and plan aren't known yet.
  var isStale: Bool {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return day != f.string(from: Date())
  }

  var waterFraction: Double {
    guard waterGoalMl > 0, !isStale else { return 0 }
    return min(1, Double(waterMl) / Double(waterGoalMl))
  }

  var waterPercent: Int {
    guard waterGoalMl > 0, !isStale else { return 0 }
    return Int((Double(waterMl) * 100 / Double(waterGoalMl)).rounded())
  }

  /// "Train today" only means something on the day it was worked out.
  var atRisk: Bool { streakRisk && !isStale }
}

struct GymBroEntry: TimelineEntry {
  let date: Date
  let data: GymBroData
}

/// One entry from the stored data; refreshed when the app calls
/// `updateWidget`, and again after midnight so water starts from zero.
struct GymBroProvider: TimelineProvider {
  func placeholder(in context: Context) -> GymBroEntry {
    var d = GymBroData()
    d.signedIn = true
    d.streak = 12
    d.streakLit = true
    d.streakTier = "Bronze"
    d.waterMl = 1500
    d.waterGoalMl = 2500
    d.waterText = "1.5 l / 2.5 l"
    d.workoutName = "Push day"
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    d.day = f.string(from: Date())
    return GymBroEntry(date: Date(), data: d)
  }

  func getSnapshot(in context: Context, completion: @escaping (GymBroEntry) -> Void) {
    if context.isPreview {
      completion(placeholder(in: context))
    } else {
      completion(GymBroEntry(date: Date(), data: GymBroData.load()))
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GymBroEntry>) -> Void) {
    let now = Date()
    let midnight = Calendar.current.nextDate(
      after: now, matching: DateComponents(hour: 0, minute: 0, second: 5), matchingPolicy: .nextTime
    ) ?? now.addingTimeInterval(3600)
    completion(Timeline(entries: [GymBroEntry(date: now, data: GymBroData.load())], policy: .after(midnight)))
  }
}

extension View {
  /// The dark card behind every widget (iOS 17 wants it as the container
  /// background so the system can tint / remove it).
  @ViewBuilder
  func gymBroCard() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(for: .widget) { GB.card }
    } else {
      self.padding(16).background(GB.card)
    }
  }
}

/// Deep links the app understands (see HomeWidgetService.openLink). The
/// `homeWidget` query item is how home_widget recognises a widget tap.
func gymBroLink(_ page: String) -> URL {
  URL(string: "gymbroo://widget/\(page)?homeWidget")!
}

/// The orange flame, greyed out while there's no streak.
struct FlameIcon: View {
  var lit: Bool
  var size: CGFloat

  var body: some View {
    Image(systemName: "flame.fill")
      .font(.system(size: size, weight: .bold))
      .foregroundStyle(
        lit
          ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.29), GB.flame], startPoint: .top, endPoint: .bottom))
          : AnyShapeStyle(Color.white.opacity(0.3))
      )
  }
}

/// Today's water as a ring with the percentage in it.
struct WaterRing: View {
  var fraction: Double
  var percent: Int
  var lineWidth: CGFloat
  var fontSize: CGFloat

  var body: some View {
    ZStack {
      Circle().stroke(GB.water.opacity(0.25), lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: max(0.001, fraction))
        .stroke(
          AngularGradient(colors: [GB.water, GB.waterLight], center: .center),
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
      VStack(spacing: 0) {
        Image(systemName: "drop.fill")
          .font(.system(size: fontSize * 0.55))
          .foregroundColor(GB.waterLight)
        Text("\(percent)%")
          .font(.system(size: fontSize, weight: .heavy, design: .rounded))
          .foregroundColor(.white)
          .minimumScaleFactor(0.6)
          .lineLimit(1)
      }
    }
  }
}
