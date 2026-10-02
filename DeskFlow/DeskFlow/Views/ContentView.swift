import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            DeskControlView()
            Divider()
            ProfilesView()
        }
        // Tiling window managers can stretch the window; the content keeps a readable width
        .frame(maxWidth: 520)
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 560)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
        .tint(.accentOrange)
    }
}
