import SwiftUI

struct DataCollectionView: View {
    @EnvironmentObject var vm: WorkoutSessionViewModel

    // ✅ Rätt case-namn
    @State private var selectedExercise: ExerciseType = .pushUp

    // ⚠️ Se till att dessa cases finns i din PhonePlacement enum.
    // Om du får fel här: byt defaulten till ett case som finns.
    @State private var selectedPlacement: PhonePlacement = .upperArm

    @State private var personID: String = ""
    @State private var sessionID: String = UUID().uuidString

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                header

                // Labels
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Labels").font(.headline)

                        // Exercise (använd recordableCases)
                        HStack {
                            Text("Exercise")
                                .foregroundStyle(AppTheme.subtext)
                            Spacer()
                            Picker("Exercise", selection: $selectedExercise) {
                                ForEach(ExerciseType.recordableCases, id: \.self) { ex in
                                    Text(ex.displayName).tag(ex)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.accent)
                        }

                        Divider().opacity(0.2)

                        // Placement
                        HStack {
                            Text("Placement")
                                .foregroundStyle(AppTheme.subtext)
                            Spacer()
                            Picker("Placement", selection: $selectedPlacement) {
                                ForEach(PhonePlacement.allCases, id: \.self) { p in
                                    // Om PhonePlacement saknar displayName: byt till String(describing: p)
                                    Text(p.displayName).tag(p)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.accent)
                        }

                        Divider().opacity(0.2)

                        // Person ID
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Person ID")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.subtext)

                            TextField("Person ID (e.g. P01)", text: $personID)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(AppTheme.card.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Divider().opacity(0.2)

                        // Session ID
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session ID")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.subtext)

                            HStack {
                                Text(sessionID)
                                    .font(.system(.footnote, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(AppTheme.subtext)

                                Spacer()

                                Button("New") { sessionID = UUID().uuidString }
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .padding(12)
                            .background(AppTheme.card.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }

                // Sampling + stats
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sampling").font(.headline)

                        Picker("Sampling", selection: $vm.selectedHz) {
                            Text("50 Hz").tag(50.0)
                            Text("100 Hz").tag(100.0)
                        }
                        .pickerStyle(.segmented)
                        .disabled(vm.isCollectingData)

                        HStack(spacing: 12) {
                            StatPill(title: "Samples", value: "\(vm.sampleCount)", systemImage: "waveform")
                            StatPill(title: "Estimated Hz", value: String(format: "%.1f", vm.estimatedHz), systemImage: "speedometer")
                        }
                    }
                }

                // Recording
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recording").font(.headline)

                        Button {
                            if vm.isCollectingData {
                                vm.stopDataCollection()
                            } else {
                                vm.startDataCollection(
                                    label: selectedExercise,
                                    placement: selectedPlacement,
                                    sessionID: sessionID,
                                    personID: personID.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                            }
                        } label: {
                            Label(
                                vm.isCollectingData ? "Stop Recording" : "Start Recording",
                                systemImage: vm.isCollectingData ? "stop.fill" : "record.circle"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(recordButtonStyle)
                        
                        .disabled(!vm.isCollectingData && personID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if !vm.isCollectingData && personID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Fyll i Person ID för att starta.")
                                .font(.footnote)
                                .foregroundStyle(.red.opacity(0.85))
                        }

                        if let url = vm.lastSavedRecordingURL {
                            Divider().opacity(0.2)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last saved file")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.subtext)

                                Text(url.lastPathComponent)
                                    .font(.system(.footnote, design: .monospaced))

                                ShareLink(item: url) {
                                    Label("Share CSV", systemImage: "square.and.arrow.up")
                                        .font(.footnote.weight(.semibold))
                                }
                                .foregroundStyle(AppTheme.accent)
                                .padding(.top, 6)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Data Collection")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Data Collection").font(.title.bold())
            Text("Record labeled motion data for training.")
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var recordButtonStyle: AnyButtonStyle {
        if vm.isCollectingData {
            return AnyButtonStyle(style: SecondaryButtonStyle())
        } else {
            return AnyButtonStyle(style: PrimaryButtonStyle())
        }
    }
}
