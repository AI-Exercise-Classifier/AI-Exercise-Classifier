# AI Exercise Classifier (Exercise Tracker) 🏋️‍♂️📱⌚️
**Kurs:** HI1033 – Mobila applikationer och trådlösa nät

En iOS-app byggd i **SwiftUI** som använder **Core ML** för att klassificera träningsövningar baserat på rörelsedata (accelerometer/gyro/gravity).
Appen kan ta sensordata från **iPhone** eller streama från en **Apple Watch** via **WatchConnectivity**.

## Funktioner
- **Live workout-läge**
  - Tar emot rörelsedata (från Watch i realtid) och kör ML-prediktioner
  - Grundläggande rep-detektering och set-logik
  - Visar prediktion + confidence
- **Workout History**
  - Sparar pass lokalt och visar summering (sets/reps/volym)
- **Data Collection (för träningsdata)**
  - Spela in **labelad** rörelsedata till **CSV**
  - Val mellan datakälla: **Phone** eller **Watch**
  - Export/delning av CSV direkt från appen
- **watchOS-app**
  - Streamar motion i batchar till iPhone (reachability + köad fallback)
  - Kan spela in CSV på klockan och skicka filen till iPhone (transferFile)

## Teknik
- Swift + SwiftUI
- CoreMotion (rörelsedata)
- Core ML (ML-modeller: `AI2_1.mlmodel`, `AI2_2.mlmodel`)
- WatchConnectivity (kommunikation iPhone ↔︎ Apple Watch)
- (Delvis) HealthKit-stöd för träningssessioner (för att kunna fortsätta samla sensordata)

## Projektstruktur (översikt)
- `AI/AI.xcodeproj` – Xcode-projekt
- `AI/AI/` – iOS-appens kod
  - `View/` – UI (Home, LiveWorkout, DataCollection, History, Summary)
  - `ViewModel/` – logik för live tracking + datainsamling
  - `Services/` – MotionService, DataRecordingService, ExerciseClassifierService, m.m.
  - `Model/` – ExerciseType, PhonePlacement, MotionSample, WorkoutSummary
  - `AI2_1.mlmodel`, `AI2_2.mlmodel` – ML-modeller
- `AI/watchkitapp Watch App/` – watchOS-appens kod
  - Streaming + Recording + filöverföring till iPhone

## Kom igång
### Krav
- macOS + Xcode
- iPhone (simulator funkar för UI, men sensorer/Watch kräver fysisk enhet)
- Apple Watch (om ni vill använda watchOS-streaming/recording)

### Kör i Xcode
1. Öppna `AI/AI.xcodeproj`
2. Välj target **AI** och kör på iPhone (helst fysisk enhet)
3. För watchOS:
   - Välj target **watchkitapp Watch App**
   - Kör med en pairad Watch (simulatorpair eller fysisk)

## Hur det funkar (kort)
### ML-klassificering (iOS)
- Appen matar modellen med en rullande “window” av motion-samples (standard **200** samples).
- Inputkanaler som används:
  - `userAcceleration` (ax, ay, az)
  - `rotationRate` (gx, gy, gz)
  - `gravity` (grx, gry, grz)
- Prediktionen ger label + sannolikhet (confidence). Modellen `AI2_2` används som standard.

### Watch → iPhone (realtidsström)
- Watch samlar motion och skickar batchar med:
  `timestamp, ax, ay, az, gx, gy, gz, grx, gry, grz`
- Om iPhone är reachable används `sendMessage`, annars köas via `transferUserInfo`.

### Data Collection (CSV)
- **Phone-läge:** iPhone spelar in motion + label och sparar CSV lokalt.
- **Watch-läge:** Watch spelar in CSV och skickar filen till iPhone via `transferFile`.
- CSV-format innehåller kolumner för timestamp/acc/gyro/gravity (och label på iPhone-CSV).

## Övningar (labels)
Appen innehåller bl.a. dessa labels:
- Idle, Squat, Push-up, Bicep curl
- Bench press, Pull-ups, Cable rows
- Walking, Unknown

## Vanliga problem / tips
- **Ingen data från Watch?**
  - Kontrollera att Watch-appen är installerad + pairad
  - Kör på fysisk iPhone + Watch för bäst resultat
- **CSV från Watch kommer sent**
  - `transferFile` kan levereras efter en stund (bakgrundsöverföring)
- **Byt sampling rate**
  - I Data Collection kan ni välja 50 Hz eller 100 Hz

## Förslag för GitHub-repot (rekommenderat)
- Lägg till en `.gitignore` för Xcode (så ni inte committar DerivedData, user settings, etc.)
- Ta bort skräpfiler innan ni pushar:
  - `.DS_Store`
  - `__MACOSX/`
  - eventuell medföljande `.git/`-mapp i zippen (ni vill ha er egen git-historik i repot)

## Team
- *[Lägg in era namn här]*

## Licens
Utbildningsprojekt för kursen HI1033.
