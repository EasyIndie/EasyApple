import SwiftUI
import EnvDemoCore

struct ContentView: View {
    private let report = EnvironmentProber.probe()

    var body: some View {
        ScrollView {
            Text(report.formatAsText())
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("EnvDemo")
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }
}
