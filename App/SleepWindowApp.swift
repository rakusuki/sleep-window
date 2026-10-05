import SwiftUI

@main
struct SleepWindowApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(model).tint(.mint).preferredColorScheme(.dark)
        }
    }
}
