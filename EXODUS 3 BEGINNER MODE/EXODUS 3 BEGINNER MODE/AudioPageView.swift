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

                Section("Guitar Effects") {
                    Picker("Reverb", selection: $audioSettings.reverbLevel) {
                        ForEach(AudioEffectLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }

                    Picker("Delay", selection: $audioSettings.delayLevel) {
                        ForEach(AudioEffectLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                Section("Backing Track") {
                    Toggle("Backing Track Enabled", isOn: $audioSettings.backingTrackEnabled)
                        .disabled(!hasBackingTracks)

                    Picker("Arrangement", selection: $audioSettings.selectedBackingArrangement) {
                        ForEach(BackingArrangementPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .disabled(!hasBackingTracks || !audioSettings.backingTrackEnabled)

                    if availableBackingTracks.isEmpty {
                        Text("No bundled backing tracks yet")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Track", selection: Binding(
                            get: { audioSettings.selectedBackingTrackID ?? availableBackingTracks.first?.id ?? "" },
                            set: { audioSettings.selectedBackingTrackID = $0 }
                        )) {
                            ForEach(availableBackingTracks) { track in
                                Text(track.title).tag(track.id)
                            }
                        }
                        .disabled(!audioSettings.backingTrackEnabled)
                    }
                }

                Section("Tempo") {
                    Picker("Increase Per Round", selection: $audioSettings.tempoIncreasePerRound) {
                        ForEach(TempoIncreasePerRound.allCases) { option in
                            Text(option.title).tag(option)
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
