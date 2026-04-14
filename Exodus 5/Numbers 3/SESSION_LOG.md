# Exodus 5 Session Log

**Session Start:** Apr 14, 2026 at 10:15am UTC+02

## Changes Made This Session

### 1. Maestro Mode Backing Track Fix (Apr 14, 2026)
- **File:** `MaestroGameplayView.swift`
- **Issue:** Backing track didn't play when exiting screensaver via button press
- **Fix:** Added `syncMaestroBackingTrack()` call in `submitAnswer()` DispatchQueue block (line 1837)
- **Pattern:** Matches existing implementation in `handleMaestroStartButton()`

### 2. Maestro Mode Autoplay Toggle (Apr 14, 2026)
- **File:** `MaestroGameplayView.swift`
- **Feature:** Added AUTO toggle in top-leading position (matches Beginner mode placement)
- **Implementation:**
  - Added `@State private var autoPlayEnabled: Bool = false`
  - Added `@State private var autoPlayNextDate: Date? = nil`
  - Added Toggle UI overlay at `.overlay(alignment: .topLeading)`
  - Added `.onChange(of: autoPlayEnabled)` handler
  - Added `handleMaestroAutoPlayIfNeeded(currentDate:)` function
  - Called autoplay handler in timer block
  - Reset `autoPlayNextDate` in `startGameFromBeginning()` and `handleMaestroResetButton()`
  - Reset `autoPlayEnabled = false` in `handleMaestroResetButton()`

### 3. Maestro Mode Neck Shift Simplification (Apr 14, 2026)
- **File:** `MaestroGameplayView.swift`
- **Issue:** Maestro mode had overly complex beat-waiting logic for neck shifts and bass transposition
- **Changes:**
  - **Simplified `advanceGame()`**: Replaced string-6-only condition with Beginner-style round completion (when `roundStringIndex` wraps)
  - **Immediate neck shift**: Added `withAnimation { currentFretStart = max(currentRound, 0) }` directly in advanceGame
  - **Immediate bass transpose**: Added `midiEngine.setBassTransposeSemitones(max(currentRound, 0) % 12)` directly in advanceGame
  - **Removed timer logic**: Deleted the 3-beat waiting block from timer handler
  - **Cleaned up state variables:**
    - Removed `@State private var pendingBassTransposeSemitones: Int?`
    - Removed `@State private var pendingNeckShiftRound: Int?`
    - Removed `@State private var shiftStartBeatPosition: Double?`
    - Removed `@State private var lastProcessedBeatBucket: Int?`
  - **Updated reset functions:** Removed references to deleted state variables in `startGameFromBeginning()` and `handleMaestroResetButton()`

### 4. Maestro Mode Fret Number Indicators (Apr 14, 2026)
- **File:** `MaestroGameplayView.swift`
- **Feature:** Added white fret number indicators on both sides of neck window (matching Beginner mode)
- **Implementation:**
  - Added position calculations: `leftFretIndicatorX`, `rightFretIndicatorX`, `fretIndicatorText`
  - Added `fretIndicatorOverlay()` function with exact Beginner mode styling:
    - Font: `.system(size: 24, weight: .black, design: .monospaced)`
    - Color: `Color.white.opacity(0.96)`
    - Shadow: `Color.black.opacity(0.72), radius: 3, x: 0, y: 1`
  - Placed overlay in view hierarchy at `orangeGreenUnitCenterY` height
  - Hidden during screensaver mode via `isHidden: isCodeScreensaverMode`

### 5. Beginner Mode Guitar Decay & Thumb Button Flash (Apr 14, 2026)
- **Files:** `GuitarNoteEngine.swift`, `BeginnerGameplayView.swift`
- **Issue 1 - Guitar Decay:** Clean electric guitar notes decayed inconsistently in chord mode
  - **Fix:** Added per-note velocity variation in `playChord()`:
    - Each note gets slightly different velocity (-8, 0, or +8 from base)
    - Creates more natural chord sound, masking inconsistent SoundFont decay
- **Issue 2 - Button Flash:** Only 2 main thumb buttons flashed green in armed mode
  - **Fix:** Added armed state check to all 6 beginner console buttons:
    - Check `isCodeScreensaverMode && startupState.phase == .armed`
    - Return `.green` for all 6 buttons when armed
    - Preserves existing pressed button feedback (green/red on answer)

### 6. Beginner Thumb & Start Button Pulse Synchronization (Apr 14, 2026)
- **File:** `BeginnerGameplayView.swift`
- **Issue:** Thumb buttons and START button did not pulse simultaneously with "BEGINNER MODE ARMED" text
- **Root Cause:**
  - Thumb buttons: Static green when armed (no pulsing)
  - 6 console buttons: Static green when armed (no pulsing)
  - START button: Used separate 0.45-second blink timer
  - Text: Used `startupSequenceElapsed` with 1-second period
- **Fix:**
  - Modified `screensaverThumbState` to check `startupState.isVisible` for each phase (systemOnline, phaseOne, armed)
  - Modified 6 console buttons to check `startupState.isVisible` when armed (not just static green)
  - START button: Hybrid timing - uses 0.45s timer before activation, then 1s cycle with `startupState.isVisible` during armed phase
  - Timer logic only active when `!startupSequenceActivated`
  - Removed `.disabled(startupStartButtonAttentionActive)` from 6 console buttons (they should always work)
- **Result:**
  - Thumb buttons (2) pulse with 1-second cycle using `startupState.isVisible`
  - Console buttons (6) pulse with 1-second cycle using `startupState.isVisible` and are always enabled
  - START button: flashes with 0.45s timer before activation (to indicate how to start), then synchronizes with 1s cycle during armed phase

### 7. Guitar Tone Preset Change Fix (Apr 14, 2026)
- **File:** `GuitarNoteEngine.swift`
- **Issue:** Notes didn't play after changing guitar tone from acoustic to electric clean until reset
- **Fix:** Added `stopAll()` call before `loadInstrument()` in `setToneConfiguration()` to ensure sampler is in clean state when preset changes
- **Result:** Preset changes now properly reinitialize the sampler without requiring reset

### 8. Stop Button Note Play Fix (Apr 14, 2026)
- **File:** `BeginnerGameplayView.swift`
- **Issue:** Notes didn't play when stop button was pressed
- **Fix:** Removed `guard !isRoundPaused else { return }` from `handleBeginnerConsoleButtonPress()`
- **Result:** Thumb buttons now work regardless of round pause state

### 9. Electric Clean Note Length Fix (Apr 14, 2026)
- **File:** `GuitarNoteEngine.swift`
- **Issue:** Low E and high E notes had different lengths on electric clean tone (SoundFont decay variation)
- **Fix:** Removed per-note velocity variation from `playChord()` (was causing inconsistent decay)
- **Note:** Attempted release delay compensation was removed as it didn't work (SoundFont decay is baked into samples)
- **Result:** Removed velocity variation; SoundFont sample decay variation remains (requires new SoundFont for true fix)

### 10. Answer Window Display in Beginner Mode When Stopped (Apr 14, 2026)
- **File:** `BeginnerGameplayView.swift`
- **Issue:** Answer window didn't appear when playing thumb buttons while game was stopped
- **Fix:** Modified `shouldShowWhiteAnswerBox` logic to show answer box when note is selected (`hasBeginnerSelectedNote && answerBoxReady`) regardless of game state, bypassing pentatonic reveal count check
- **Result:** Answer window now appears whenever a note is sounded in beginner mode, even when game is stopped

### 11. Code Cleanup - Junk Code Removal (Apr 14, 2026)
- **File:** `GuitarNoteEngine.swift`
- **Issue:** Electric clean note length compensation code (lines 110-119) was dead code that didn't work
- **Fix:** Removed compensation logic for electric clean notes
- **Result:** Code is cleaner; SoundFont decay variation acknowledged as sample-level issue

---

## Pending Changes
- [ ] Additional changes to be documented...

## Backup Plan
After all changes complete, back up to other identical projects (Exodus 1, Exodus 7, etc.)
