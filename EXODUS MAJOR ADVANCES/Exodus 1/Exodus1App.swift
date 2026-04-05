import SwiftUI

@main
struct Exodus1App: App {
    @State private var walletDollars: Int = 0
    @State private var balanceDollars: Int = 0

    var body: some Scene {
        WindowGroup {
            ContentView(
                onMenuSelection: nil,
                selectedMode: .freestyle,
                selectedPhase: 1,
                beatBPM: 80,
                beatVolume: 0.8,
                stringVolume: 0.8,
                walletDollars: $walletDollars,
                balanceDollars: $balanceDollars
            )
        }
    }
}
