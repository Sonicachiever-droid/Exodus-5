import AVFoundation
import Combine

class SimpleAudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    
    private var chordTimer: Timer?
    
    // 12 chords for open strings, transposed for all frets
    private let chords = [
        ["G", "B", "D"],           // G major
        ["E", "G", "B"],           // E minor
        ["G", "B", "D", "E"],      // G6
        ["E", "G", "B", "D"],      // E minor 7
        ["G", "A", "B", "D"],      // G add 9
        ["G", "A", "B", "D", "E"], // G6 9
        ["E", "F#", "G", "B"],     // E minor add 9
        ["E", "G", "A", "B"],      // E minor add 11
        ["E", "F#", "G", "A", "B"], // E minor 11
        ["D", "G", "A"],           // Dsus4
        ["A", "B", "E"],           // Asus2
        ["E", "A", "B", "D"]       // E7sus4
    ]
    
    private var currentChordIndex: Int = 0
    private var currentRound: Int = 0
    
    init() {
        setupAudioEngine()
        loadSounds()
    }
    
    private func setupAudioEngine() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = 0.8
    }
    
    private func loadSounds() {
        // Try to find GeneralUser GS SoundFont in various locations
        let soundFontCandidates: [URL?] = [
            Bundle.main.url(forResource: "GeneralUser GS v1.472", withExtension: "sf2", subdirectory: "GeneralUser GS 1.472"),
            Bundle.main.url(forResource: "GeneralUser GS v1.472", withExtension: "sf2"),
            Bundle.main.url(forResource: "GeneralUser_GS_v1.472", withExtension: "sf2"),
            Bundle.main.url(forResource: "FluidR3_GM", withExtension: "sf2")
        ]
        
        for candidate in soundFontCandidates {
            guard let soundFontURL = candidate else { continue }
            do {
                try sampler.loadSoundBankInstrument(at: soundFontURL, program: 0, bankMSB: 0, bankLSB: 0)
                print("SimpleAudioEngine: Loaded SoundFont from \(soundFontURL.lastPathComponent)")
                return
            } catch {
                print("SimpleAudioEngine: Failed to load \(soundFontURL.lastPathComponent) - \(error)")
                continue
            }
        }
        
        // Fallback to system sounds
        print("SimpleAudioEngine: Using system sound bank")
        let soundBankURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        
        do {
            try sampler.loadSoundBankInstrument(at: soundBankURL, program: 0, bankMSB: 0, bankLSB: 0)
            print("SimpleAudioEngine: Loaded system instruments")
        } catch {
            print("SimpleAudioEngine: Failed to load system sounds - \(error)")
        }
    }
    
    func startAccompaniment(currentRound: Int) {
        stopAccompaniment()
        self.currentRound = currentRound
        
        do {
            if !engine.isRunning {
                try engine.start()
            }
            print("SimpleAudioEngine: Started for round \(currentRound)")
            
            // Start chord progression immediately
            playCurrentChord()
            
            // Change chords every 2 seconds
            chordTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.advanceChord()
            }
            
        } catch {
            print("SimpleAudioEngine: Failed to start - \(error)")
        }
    }
    
    func stopAccompaniment() {
        chordTimer?.invalidate()
        chordTimer = nil
        
        // Stop all notes
        for note in 0...127 {
            sampler.stopNote(UInt8(note), onChannel: 0)
        }
        
        print("SimpleAudioEngine: Stopped")
    }
    
    private func advanceChord() {
        currentChordIndex = (currentChordIndex + 1) % chords.count
        playCurrentChord()
    }
    
    private func playCurrentChord() {
        // Stop previous chord
        for note in 0...127 {
            sampler.stopNote(UInt8(note), onChannel: 0)
        }
        
        let chordNotes = chords[currentChordIndex]
        
        // Convert note names to MIDI note numbers
        let midiNotes = chordNotes.compactMap { noteName -> UInt8? in
            let noteMap: [String: UInt8] = [
                "C": 60, "C#": 61, "D": 62, "D#": 63, "E": 64, "F": 65,
                "F#": 66, "G": 67, "G#": 68, "A": 69, "A#": 70, "B": 71
            ]
            return noteMap[noteName]
        }
        
        // Transpose by current round (half-step per fret)
        let transposedNotes = midiNotes.map { UInt8(Int($0) + currentRound) }
        
        // Play chord notes
        for midiNote in transposedNotes {
            sampler.startNote(midiNote, withVelocity: 70, onChannel: 0)
        }
        
        print("SimpleAudioEngine: Playing chord \(currentChordIndex + 1)/\(chords.count) at fret \(currentRound)")
    }
    
    func playGuitarNote(stringIndex: Int, currentRound: Int) {
        // Ensure engine is running
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("SimpleAudioEngine: Failed to start for guitar - \(error)")
                return
            }
        }
        
        // Guitar string tuning (E-A-D-G-B-E) from low to high
        let openStrings = [40, 45, 50, 55, 59, 64]
        
        guard stringIndex < openStrings.count else { return }
        
        let openNote = openStrings[stringIndex]
        let frettedNote = UInt8(openNote + currentRound)
        
        // Play the note
        sampler.startNote(frettedNote, withVelocity: 90, onChannel: 0)
        
        // Stop note after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sampler.stopNote(frettedNote, onChannel: 0)
        }
        
        print("SimpleAudioEngine: Guitar string \(stringIndex + 1) at fret \(currentRound)")
    }
    
    func updateTransposition(round: Int) {
        self.currentRound = round
        print("SimpleAudioEngine: Updated to round \(round)")
    }
    
    deinit {
        stopAccompaniment()
    }
}
