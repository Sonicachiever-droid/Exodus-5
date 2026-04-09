//
//  Numbers_3App.swift
//  Numbers 3
//
//  Created by Thomas Kane on 4/5/26.
//

import SwiftUI
import SwiftData

@main
struct Numbers_3App: App {
    @State private var selectedMenuOption: GameplayMenuOption?
    @AppStorage("numbers3.progress.walletPoints") private var walletPoints: Int = 0
    @AppStorage("numbers3.progress.balancePoints") private var balancePoints: Int = 0
    @AppStorage("numbers3.setup.startingFret") private var startingFret: Int = 0
    @AppStorage("numbers3.setup.repetitions") private var repetitions: Int = 5
    @AppStorage("numbers3.setup.direction") private var directionRawValue: String = LessonDirection.ascending.rawValue
    @AppStorage("numbers3.setup.enableHighFrets") private var enableHighFrets: Bool = false
    @AppStorage("numbers3.setup.lessonStyle") private var lessonStyleRawValue: String = "chord"
    @AppStorage("numbers3.migration.repetitionsV5Applied") private var repetitionsV5MigrationApplied: Bool = false
    @AppStorage("numbers3.migration.startingFretDefaultApplied") private var startingFretDefaultApplied: Bool = false
    @AppStorage("numbers3.migration.playSetupCanonicalV2Applied") private var playSetupCanonicalV2Applied: Bool = false
    @AppStorage("numbers3.migration.lessonStyleResetToChordV2Applied") private var lessonStyleResetToChordV2Applied: Bool = false

    init() {
        if !repetitionsV5MigrationApplied {
            repetitions = 5
            repetitionsV5MigrationApplied = true
        }
        if !startingFretDefaultApplied {
            startingFret = 0
            startingFretDefaultApplied = true
        }
        if LessonDirection(rawValue: directionRawValue) == nil {
            directionRawValue = LessonDirection.ascending.rawValue
        }
        if !playSetupCanonicalV2Applied {
            startingFret = 0
            repetitions = 5
            directionRawValue = LessonDirection.ascending.rawValue
            playSetupCanonicalV2Applied = true
        }
        // Force reset lesson style to chord (fixes v1.0 random default bug)
        if !lessonStyleResetToChordV2Applied {
            lessonStyleRawValue = "chord"
            lessonStyleResetToChordV2Applied = true
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(
                onMenuSelection: { option in
                    selectedMenuOption = option
                },
                playStartingFret: $startingFret,
                playRepetitions: $repetitions,
                playDirectionRawValue: $directionRawValue,
                playEnableHighFrets: $enableHighFrets,
                playLessonStyle: $lessonStyleRawValue,
                walletDollars: $walletPoints,
                balanceDollars: $balancePoints
            )
            .sheet(item: $selectedMenuOption) { option in
                Numbers3MenuSheet(
                    option: option,
                    walletPoints: $walletPoints,
                    balancePoints: $balancePoints,
                    startingFret: $startingFret,
                    repetitions: $repetitions,
                    directionRawValue: $directionRawValue,
                    enableHighFrets: $enableHighFrets,
                    lessonStyleRawValue: $lessonStyleRawValue
                )
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct Numbers3MenuSheet: View {
    let option: GameplayMenuOption
    @Binding var walletPoints: Int
    @Binding var balancePoints: Int
    @Binding var startingFret: Int
    @Binding var repetitions: Int
    @Binding var directionRawValue: String
    @Binding var enableHighFrets: Bool
    @Binding var lessonStyleRawValue: String
    @AppStorage("numbers3.runtime.directionLockActive") private var directionLockActive: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                switch option {
                case .home:
                    Section("Progress") {
                        LabeledContent("Wallet", value: "\(walletPoints)")
                        LabeledContent("Balance", value: "\(balancePoints)")
                    }
                case .learn:
                    Section("Lesson Setup") {
                        Picker("Style", selection: $lessonStyleRawValue) {
                            Text("Random").tag("random")
                            Text("Chord").tag("chord")
                        }
                        
                        Stepper("Repetitions: \(repetitions)", value: $repetitions, in: 1...8)
                        
                        Stepper("Starting Fret: \(startingFret)", value: $startingFret, in: 0...(enableHighFrets ? 19 : 12))
                        
                        Picker("Direction", selection: $directionRawValue) {
                            Text("Phase 1 (Ascending)").tag(LessonDirection.ascending.rawValue)
                            Text("Phase 2 (Descending)").tag(LessonDirection.descending.rawValue)
                        }
                        .disabled(directionLockActive)
                        
                        Toggle("Enable High Frets (12+)", isOn: $enableHighFrets)
                    }
                    .onChange(of: enableHighFrets) { _, isEnabled in
                        if !isEnabled {
                            startingFret = min(startingFret, 12)
                        }
                    }
                    if directionLockActive {
                        Section {
                            Text("Direction is locked during an active run. Press RESET, then START to apply a new direction.")
                        }
                    }
                case .phases:
                    Section("Quick Guide") {
                        switch lessonStyleRawValue {
                        case "random":
                            Text("Random Style: Learn randomized note sequences at each fret position.")
                            Text("Notes appear in randomized order; if the same note appears twice at one fret, you may use either matching location first.")
                            Text("The second occurrence must use the remaining matching location.")
                            Text("Backing track plays root note only (E for open strings, F for fret 1, etc.).")
                            Text("Builds quick note recognition and pattern learning skills.")
                        case "chord":
                            Text("Chord Style: Practice harmonic chord combinations.")
                            Text("Chords automatically adapt to your current fret position.")
                            Text("Educational compatibility scores show how well chords fit available notes.")
                            Text("Backing track plays full chord progressions.")
                            Text("Learn chord construction, fingerings, and harmonic relationships.")
                        default:
                            Text("START begins or resumes. STOP pauses. RESET returns to setup boundary.")
                            Text("Repetitions can change anytime and update live.")
                            Text("Starting Fret can be adjusted anytime; it applies on RESET -> START.")
                        }
                        
                        Text("Transport Controls:")
                        Text("• START begins or resumes. STOP pauses. RESET returns to setup boundary.")
                        Text("• Repetitions can change anytime and update live.")
                        Text("• Starting Fret can be adjusted anytime; it applies on RESET -> START.")
                        Text("• Direction is locked during a run to keep sharp/flat note spelling consistent.")
                        Text("• Use HINT and FRETBOARD as needed for reinforcement.")
                    }
                case .audio:
                    Section("Audio") {
                        Text("Use the in-game AUDIO page for backing track and instrument mix settings.")
                    }
                }
            }
            .navigationTitle(option.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
