//
//  Exodus_8App.swift
//  Exodus 8
//
//  Created by Thomas Kane on 4/11/26.
//

import SwiftUI
import SwiftData

@main
struct Exodus_8App: App {
    @State private var selectedMenuOption: GameplayMenuOption?
    @State private var layoutMode: LayoutMode? = nil
    @AppStorage("numbers3.progress.walletPoints") private var walletPoints: Int = 0
    @AppStorage("numbers3.progress.balancePoints") private var balancePoints: Int = 0
    @AppStorage("numbers3.setup.startingFret") private var startingFret: Int = 0
    @AppStorage("numbers3.setup.repetitions") private var repetitions: Int = 5
    @AppStorage("numbers3.setup.direction") private var directionRawValue: String = LessonDirection.ascending.rawValue
    @AppStorage("numbers3.setup.enableHighFrets") private var enableHighFrets: Bool = false
    @AppStorage("numbers3.setup.lessonStyle") private var lessonStyleRawValue: String = "chord"
    @AppStorage("numbers3.setup.selectedMode") private var selectedModeRawValue: String = "beginner"

    init() {
        if LessonDirection(rawValue: directionRawValue) == nil {
            directionRawValue = LessonDirection.ascending.rawValue
        }
        if selectedModeRawValue == "beginner" {
            layoutMode = .beginner
        } else if selectedModeRawValue == "maestro" {
            layoutMode = .maestro
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
            Group {
                if let mode = layoutMode {
                    switch mode {
                    case .beginner:
                        BeginnerGameplayView(
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
                    case .maestro:
                        MaestroGameplayView(
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
                    }
                } else {
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                        VStack(spacing: 20) {
                            Text("Choose Console")
                                .font(.title2).bold()
                                .foregroundColor(.white)
                            VStack(spacing: 12) {
                                Button {
                                    layoutMode = .beginner
                                } label: {
                                    Text("Beginner Console")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue.opacity(0.9))
                                        .cornerRadius(12)
                                }
                                Button {
                                    layoutMode = .maestro
                                } label: {
                                    Text("Maestro Console")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.gray.opacity(0.9))
                                        .cornerRadius(12)
                                }
                            }
                            .frame(maxWidth: 320)
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
                    }
                }
            }
            .onChange(of: layoutMode) { _, newMode in
                if newMode == .beginner {
                    selectedModeRawValue = "beginner"
                } else if newMode == .maestro {
                    selectedModeRawValue = "maestro"
                }
            }
            .sheet(item: $selectedMenuOption) { option in
                Exodus8MenuSheet(
                    option: option,
                    walletPoints: $walletPoints,
                    balancePoints: $balancePoints,
                    startingFret: $startingFret,
                    repetitions: $repetitions,
                    directionRawValue: $directionRawValue,
                    enableHighFrets: $enableHighFrets,
                    lessonStyleRawValue: $lessonStyleRawValue,
                    layoutMode: $layoutMode
                )
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct Exodus8MenuSheet: View {
    let option: GameplayMenuOption
    @Binding var walletPoints: Int
    @Binding var balancePoints: Int
    @Binding var startingFret: Int
    @Binding var repetitions: Int
    @Binding var directionRawValue: String
    @Binding var enableHighFrets: Bool
    @Binding var lessonStyleRawValue: String
    @Binding var layoutMode: LayoutMode?
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
                            Text("Ascending").tag(LessonDirection.ascending.rawValue)
                            Text("Descending").tag(LessonDirection.descending.rawValue)
                        }
                        .disabled(directionLockActive)

                        Toggle("Enable High Frets (12+)", isOn: $enableHighFrets)
                    }
                    .onChange(of: enableHighFrets) { _, isEnabled in
                        if !isEnabled {
                            startingFret = min(startingFret, 12)
                        }
                    }

                    Section {
                        Button {
                            if layoutMode == .beginner {
                                layoutMode = .maestro
                            } else {
                                layoutMode = .beginner
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text(layoutMode == .beginner ? "Switch to Maestro Mode" : "Switch to Beginner Mode")
                                    .font(.headline)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
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
