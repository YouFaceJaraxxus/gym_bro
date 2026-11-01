import SwiftUI
import WidgetKit

// Home-screen widgets: streak, water and today's workout. The app writes the
// numbers and the (already translated) labels into the App Group through
// home_widget, then reloads these by kind.

// ── Streak ─────────────────────────────────────────────────────────────────────

struct StreakWidgetView: View {
  let data: GymBroData

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .top) {
        FlameIcon(lit: data.streakLit, size: 30)
        Spacer()
        if !data.streakTier.isEmpty {
          Text(data.streakTier.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(GB.flame)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(GB.flame.opacity(0.18)))
        }
      }
      Spacer(minLength: 0)
      if data.signedIn {
        Text("\(data.streak)")
          .font(.system(size: 40, weight: .black, design: .rounded))
          .foregroundColor(.white)
          .minimumScaleFactor(0.5)
          .lineLimit(1)
        Text(data.atRisk ? data.streakRiskLabel : data.streakLabel)
          .font(.system(size: 12, weight: data.atRisk ? .bold : .medium))
          .foregroundColor(data.atRisk ? GB.risk : GB.muted)
          .lineLimit(2)
      } else {
        Text(data.signedOutLabel)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(GB.muted)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

struct StreakWidget: Widget {
  let kind = "StreakWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GymBroProvider()) { entry in
      StreakWidgetView(data: entry.data)
        .gymBroCard()
        .widgetURL(gymBroLink("streak"))
    }
    .configurationDisplayName("Streak")
    .description("Your workout streak, and a heads-up when today's workout keeps it alive.")
    .supportedFamilies([.systemSmall])
  }
}

// ── Water ──────────────────────────────────────────────────────────────────────

struct WaterWidgetView: View {
  @Environment(\.widgetFamily) var family
  let data: GymBroData

  var body: some View {
    if family == .systemMedium {
      HStack(spacing: 16) {
        WaterRing(fraction: data.waterFraction, percent: data.waterPercent, lineWidth: 12, fontSize: 22)
          .frame(width: 104, height: 104)
        VStack(alignment: .leading, spacing: 6) {
          Text(data.waterTitle)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(GB.waterLight)
          Text(caption)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
          bar
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      VStack(spacing: 6) {
        WaterRing(fraction: data.waterFraction, percent: data.waterPercent, lineWidth: 10, fontSize: 20)
          .frame(width: 92, height: 92)
        Text(caption)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(GB.muted)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var caption: String {
    if !data.signedIn { return data.signedOutLabel }
    if data.isStale || data.waterText.isEmpty { return data.staleLabel }
    return data.waterText
  }

  private var bar: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(GB.water.opacity(0.25))
        Capsule()
          .fill(LinearGradient(colors: [GB.water, GB.waterLight], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(6, geo.size.width * data.waterFraction))
      }
    }
    .frame(height: 8)
  }
}

struct WaterWidget: Widget {
  let kind = "WaterWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GymBroProvider()) { entry in
      WaterWidgetView(data: entry.data)
        .gymBroCard()
        .widgetURL(gymBroLink("water"))
    }
    .configurationDisplayName("Water")
    .description("Today's water against your goal.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// ── Today's workout ────────────────────────────────────────────────────────────

struct TodayWidgetView: View {
  @Environment(\.widgetFamily) var family
  let data: GymBroData

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: data.workoutDone ? "checkmark.seal.fill" : (data.workoutFree ? "leaf.fill" : "dumbbell.fill"))
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(data.workoutDone ? Color.green : GB.flame)
        Text(data.todayTitle.uppercased())
          .font(.system(size: 11, weight: .heavy))
          .foregroundColor(GB.muted)
        Spacer(minLength: 0)
        HStack(spacing: 2) {
          FlameIcon(lit: data.streakLit, size: 13)
          Text("\(data.streak)")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
        }
      }
      Spacer(minLength: 0)
      Text(title)
        .font(.system(size: family == .systemMedium ? 22 : 18, weight: .heavy))
        .foregroundColor(.white)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
      if !subtitle.isEmpty {
        Text(subtitle)
          .font(.system(size: 12, weight: data.atRisk ? .bold : .medium))
          .foregroundColor(data.atRisk ? GB.risk : GB.muted)
          .lineLimit(family == .systemMedium ? 2 : 3)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  private var title: String {
    if !data.signedIn { return data.signedOutLabel }
    if data.isStale || data.workoutName.isEmpty { return data.staleLabel }
    return data.workoutName
  }

  private var subtitle: String {
    if !data.signedIn || data.isStale { return "" }
    if data.atRisk && !data.workoutDone { return data.streakRiskLabel }
    return data.workoutStatus
  }
}

struct TodayWidget: Widget {
  let kind = "TodayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GymBroProvider()) { entry in
      TodayWidgetView(data: entry.data)
        .gymBroCard()
        .widgetURL(gymBroLink("today"))
    }
    .configurationDisplayName("Today's workout")
    .description("What's planned today, and your streak.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
