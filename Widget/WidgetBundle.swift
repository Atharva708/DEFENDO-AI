import WidgetKit
import SwiftUI
import AppIntents

@main
struct DefendoWidgetBundle: WidgetBundle {
    var body: some Widget {
        DefendoWidget()
        WidgetControl()
        WidgetLiveActivity()
        SOSWidget()
    }
}
