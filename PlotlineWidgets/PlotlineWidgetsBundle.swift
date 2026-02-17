import SwiftUI
import WidgetKit

@main
struct PlotlineWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TrendingWidget()
        WatchlistProgressWidget()
        DailyPickWidget()
    }
}
