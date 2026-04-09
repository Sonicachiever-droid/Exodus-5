import Foundation
import Combine

// MARK: - Random Note Generator
class RandomNoteGenerator: ObservableObject {
    @Published var currentNoteSequence: [String] = []
    @Published var usedNoteLocations: Set<String> = []
    @Published var sequenceProgressIndex: Int = 0
    
    // Generate random note sequence for current fret - returns all 6 string notes (with duplicates if they exist)
    func generateNoteSequence(for fret: Int, useFlats: Bool = false) {
        let openStrings = ["E", "A", "D", "G", "B", "E"] // low to high
        let chromaticSharps = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let chromaticFlats = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        let chromatic = useFlats ? chromaticFlats : chromaticSharps
        
        // Calculate note for each string at this fret
        var allNotes: [String] = []
        for openNote in openStrings {
            if let openIndex = chromatic.firstIndex(of: openNote) {
                let noteIndex = (openIndex + fret) % 12
                allNotes.append(chromatic[noteIndex])
            }
        }
        
        // Shuffle all 6 notes (including duplicates)
        currentNoteSequence = allNotes.shuffled()
        usedNoteLocations.removeAll()
        sequenceProgressIndex = 0
    }
    
    // Get next note in sequence, respecting duplicate location rules
    func getNextNote(currentFret: Int) -> String? {
        guard sequenceProgressIndex < currentNoteSequence.count else { return nil }
        
        let nextNote = currentNoteSequence[sequenceProgressIndex]
        
        // Check if this note has been used at this location before
        let noteLocationKey = "\(nextNote)-fret\(max(currentFret, 0))"
        
        if usedNoteLocations.contains(noteLocationKey) {
            // Find first unused location for this note
            return findUnusedLocation(for: nextNote)
        } else {
            // Use this location
            usedNoteLocations.insert(noteLocationKey)
            sequenceProgressIndex += 1
            return nextNote
        }
    }
    
    // Find unused location for a given note
    private func findUnusedLocation(for note: String) -> String {
        // This is a simplified version - in practice, this would need
        // to track which string/fret combinations are available
        // For now, return the note with a flag that indicates location conflict
        return note
    }
    
    // Check if sequence is complete
    func isSequenceComplete() -> Bool {
        return sequenceProgressIndex >= currentNoteSequence.count
    }
    
    // Reset for new fret
    func resetForNewFret() {
        currentNoteSequence.removeAll()
        usedNoteLocations.removeAll()
        sequenceProgressIndex = 0
    }
}
