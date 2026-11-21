import SwiftUI
import TemplateAppCore

@main
struct TemplateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    private let greeting = Greeting(appName: "TemplateApp")

    var body: some View {
        VStack(spacing: 12) {
            Text(greeting.text)
                .font(.largeTitle.bold())
            Text("EasyApple template")
                .foregroundStyle(.secondary)
        }
        .padding()
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 240)
        #endif
    }
}
