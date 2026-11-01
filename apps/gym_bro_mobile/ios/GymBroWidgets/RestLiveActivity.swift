import ActivityKit
import SwiftUI
import WidgetKit

// The rest timer on the Lock Screen and in the Dynamic Island. Started,
// extended (+30 s) and ended by RestActivityService through live_activities.
// The countdown is `Text(timerInterval:)`, so it ticks without updates.

/// live_activities requires exactly this name and shape; the values the app
/// sends are read from the App Group under "<id>_<key>".
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {}

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

/// One rest, as the app last sent it.
struct RestState {
  var title = "Rest"
  var exercise = ""
  var next = ""
  var start = Date()
  var end = Date()

  init(_ attributes: LiveActivitiesAppAttributes) {
    guard let defaults = UserDefaults(suiteName: gymBroAppGroup) else { return }
    title = defaults.string(forKey: attributes.prefixedKey("title")) ?? title
    exercise = defaults.string(forKey: attributes.prefixedKey("exercise")) ?? ""
    next = defaults.string(forKey: attributes.prefixedKey("next")) ?? ""
    let startMs = defaults.double(forKey: attributes.prefixedKey("startMs"))
    let endMs = defaults.double(forKey: attributes.prefixedKey("endMs"))
    if startMs > 0 { start = Date(timeIntervalSince1970: startMs / 1000) }
    // A closed range can't run backwards.
    end = max(start, endMs > 0 ? Date(timeIntervalSince1970: endMs / 1000) : start)
  }

  var interval: ClosedRange<Date> { start...end }
}

@available(iOSApplicationExtension 16.1, *)
struct RestLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      RestLockScreenView(rest: RestState(context.attributes))
        .activityBackgroundTint(GB.card)
        .activitySystemActionForegroundColor(.white)
        .widgetURL(gymBroLink("rest"))
    } dynamicIsland: { context in
      let rest = RestState(context.attributes)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label {
            Text(rest.title)
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(GB.flame)
          } icon: {
            Image(systemName: "timer")
              .foregroundColor(GB.flame)
          }
          .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(timerInterval: rest.interval, countsDown: true)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundColor(.white)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 110, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            if !rest.exercise.isEmpty {
              Text(rest.exercise)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            }
            if !rest.next.isEmpty {
              Text(rest.next)
                .font(.system(size: 13))
                .foregroundColor(GB.muted)
                .lineLimit(1)
            }
            ProgressView(timerInterval: rest.interval, countsDown: true) {
              EmptyView()
            } currentValueLabel: {
              EmptyView()
            }
            .tint(GB.flame)
          }
          .padding(.horizontal, 4)
        }
      } compactLeading: {
        Image(systemName: "timer")
          .foregroundColor(GB.flame)
      } compactTrailing: {
        Text(timerInterval: rest.interval, countsDown: true)
          .monospacedDigit()
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(GB.flame)
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 44)
      } minimal: {
        Image(systemName: "timer")
          .foregroundColor(GB.flame)
      }
      .widgetURL(gymBroLink("rest"))
      .keylineTint(GB.flame)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
struct RestLockScreenView: View {
  let rest: RestState

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      ZStack {
        Circle().fill(GB.flame.opacity(0.18))
        Image(systemName: "timer")
          .font(.system(size: 22, weight: .bold))
          .foregroundColor(GB.flame)
      }
      .frame(width: 48, height: 48)
      VStack(alignment: .leading, spacing: 3) {
        Text(rest.title.uppercased())
          .font(.system(size: 12, weight: .heavy))
          .foregroundColor(GB.flame)
        if !rest.exercise.isEmpty {
          Text(rest.exercise)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1)
        }
        if !rest.next.isEmpty {
          Text(rest.next)
            .font(.system(size: 13))
            .foregroundColor(GB.muted)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 8)
      Text(timerInterval: rest.interval, countsDown: true)
        .font(.system(size: 40, weight: .heavy, design: .rounded))
        .monospacedDigit()
        .foregroundColor(.white)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 120, alignment: .trailing)
    }
    .padding(16)
  }
}
