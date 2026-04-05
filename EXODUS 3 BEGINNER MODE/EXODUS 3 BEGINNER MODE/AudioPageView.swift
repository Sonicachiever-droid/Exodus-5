import SwiftUI

struct AudioPageView: View {
    @Bindable var audioSettings: AudioSettings
    let availableBackingTracks: [BackingTrack]
    let onDone: () -> Void

    private var hasBackingTracks: Bool {
        !availableBackingTracks.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Guitar Sound") {
                    Picker("Preset", selection: $audioSettings.guitarTonePreset) {
                        ForEach(GuitarTonePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                }


                Section("Tempo") {
                    Picker("Increase Per Round", selection: $audioSettings.tempoIncreasePerRound) {
                        ForEach(TempoIncreasePerRound.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("Beginner Round 2") {
                    Picker("Lesson Repeat", selection: $audioSettings.beginnerLessonRepeat) {
                        ForEach(BeginnerLessonRepeat.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }

                    HStack {
                        Picker("Starting Fret", selection: $audioSettings.beginnerStartingFret) {
                            ForEach(0...12, id: \.self) { fret in
                                Text("\(fret)").tag(fret)
                            }
                        }

                        Picker("Direction", selection: $audioSettings.beginnerStartDirection) {
                            ForEach(BeginnerStartDirection.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }
}
