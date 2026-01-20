import SwiftUI
import TavernCore

@main
struct TavernApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Tavern")
                .font(.largeTitle)
            Text("The Proprietor will be with you shortly...")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    ContentView()
}
