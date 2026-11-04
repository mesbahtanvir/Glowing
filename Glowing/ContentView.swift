import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable {
    case today
    case style
    case you
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "sparkles", value: .today) {
                HomeView()
            }

            Tab("Style", systemImage: "tshirt", value: .style) {
                StyleView()
            }

            Tab("You", systemImage: "person.crop.circle", value: .you) {
                YouView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Routine.self, RoutineStep.self, RoutineLog.self, StepDayVariant.self, ProgressPhoto.self, SkinAnalysis.self], inMemory: true)
}
