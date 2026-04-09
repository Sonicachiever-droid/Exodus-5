import Foundation

protocol BackingTrackPlaying {
    var isPlaying: Bool { get }
    func play(url: URL, title: String, loop: Bool)
    func pause()
    func resume()
    func stop()
    func currentBeatPosition() -> Double
    func setBassTransposeSemitones(_ semitones: Int)
}

protocol GuitarNotePlaying {
    func configure(
        preset: GuitarTonePreset,
        reverbLevel: AudioEffectLevel,
        delayLevel: AudioEffectLevel
    )
    func play(string: Int, fret: Int, velocity: Float)
    @discardableResult
    func playChord(midiNotes: [Int], velocity: Float, sustainMultiplier: Double) -> TimeInterval
}

extension SimpleMIDIEngine: BackingTrackPlaying {}
extension GuitarNoteEngine: GuitarNotePlaying {}
