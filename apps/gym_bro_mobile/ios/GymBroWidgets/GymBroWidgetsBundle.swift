import SwiftUI
import WidgetKit

@main
struct GymBroWidgetsBundle: WidgetBundle {
  var body: some Widget {
    StreakWidget()
    WaterWidget()
    TodayWidget()
    if #available(iOSApplicationExtension 16.1, *) {
      RestLiveActivity()
    }
  }
}
