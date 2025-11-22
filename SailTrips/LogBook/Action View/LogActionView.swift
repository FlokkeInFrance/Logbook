//
//  LogbookActionView.swift
//  SailTrips
//
//  Created by jeroen kok on 25/11/2025.
//

//
//  LogActionView.swift
//  SailTrips
//
//  Created by ChatGPT on 25/11/2025.
//

//
//  LogActionView.swift
//  SailTrips
//
//  Rebuilt version with:
//  - Situation picker (S1, S2… via SituationDefinition)
//  - Fixed AF top bar (AF1..AF17)
//  - 4-per-line grid for situation-dependent actions
//

import SwiftUI
import SwiftData

struct LogActionView: View {
    // MARK: - Inputs

    @Bindable var instances: Instances

    let showBanner: (String) -> Void
    let openDangerSheet: (ActionVariant) -> Void
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext

    private let registry = ActionRegistry.makeDefault()

    // situations come from registry:
    private var situations: [SituationDefinition] { registry.allSituations}

    // MARK: - State

    /// Currently selected situation (for v1, chosen manually).
    @State private var currentSituationID: SituationID

    /// Optional toast/banner text (short feedback after actions).
    @State private var bannerText: String?
    @State private var showBannerView: Bool = false

    // MARK: - Init

    init(
        //registry: ActionRegistry,
        instances: Instances,
        situations: [SituationDefinition],
        initialSituationID: SituationID? = nil,
        showBanner: @escaping (String) -> Void,
        openDangerSheet: @escaping (ActionVariant) -> Void,
        onClose: @escaping () -> Void
    ) {
        //self.registry = registry
        self._instances = Bindable(wrappedValue: instances)
        self.situations = situations
        self.showBanner = showBanner
        self.openDangerSheet = openDangerSheet
        self.onClose = onClose

        // Default to provided initial ID, or first situation, or S1.
        let fallbackID: SituationID = situations.first?.id ?? .s1PreparingTrip
        _currentSituationID = State(initialValue: initialSituationID ?? fallbackID)
    }

    // MARK: - Derived context

    private var actionContext: ActionContext {
        ActionContext(
            instances: instances,
            modelContext: modelContext,
            showBanner: { message in
                // Forward to caller *and* show local banner.
                showBanner(message)
                bannerText = message
                withAnimation {
                    showBannerView = true
                }
                // Auto-hide after a short delay.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showBannerView = false
                    }
                }
            },
            openDangerSheet: openDangerSheet
        )
    }

    /// Current situation definition (if any).
    private var currentDefinition: SituationDefinition? {
        situations.first { $0.id == currentSituationID }
    }

    /// AF tags for the permanent top bar (fixed list).
    private let topAFTags: [String] = [
        "AF1",  // Danger spotted
        "AF2",  // Start motor
        "AF2R", // Stop motor
        "AF21", // Motors (multi-motor sheet)
        "AF3N", // Night
        "AF3D", // Day
        "AF4",  // Failure report
        "AF5",  // Manual log
        "AF6",  // Modify instances
        "AF7",  // Crew incident
        "AF8",  // Run checklist
        "AF9",  // Weather report
        "AF10", // Encounter
        "AF11", // Insert WPT
        "AF12", // Back to trip page
        "AF14", // Change destination
        "AF15", // Log position
        "AF16", // Goto next WPT
        "AF17"  // Extra rigging
    ]

    /// Grid layout: 4 items per row.
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                titleBar
                Divider()
                topFixedAFBar
                Divider()
                actionGrid
                Divider()
                bottomBar
            }
            .background(Color(.systemBackground))

            if showBannerView, let bannerText {
                banner(bannerText)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showBannerView)
    }

    // MARK: - Title bar with situation picker

    private var titleBar: some View {
        HStack {
            Text("Action Log")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            if !situations.isEmpty {
                Menu {
                    Picker("Situation", selection: $currentSituationID) {
                        ForEach(situations, id: \.id) { situation in
                            Text(situation.title)
                                .tag(situation.id)
                        }
                    }
                } label: {
                    Label("Situation", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .padding([.horizontal, .top])
    }

    // MARK: - Fixed AF bar

    private var topFixedAFBar: some View {
        let afVariants = visibleAFVariants()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(afVariants) { variant in
                    Button {
                        runAction(variant)
                    } label: {
                        HStack(spacing: 4) {
                            if let systemImage = variant.systemImage {
                                Image(systemName: systemImage)
                                    .font(.headline)
                            }
                            Text(variant.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(variant.isEmphasised
                                      ? Color.accentColor.opacity(0.2)
                                      : Color.secondary.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(variant.isEmphasised
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.5),
                                        lineWidth: variant.isEmphasised ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Situation-dependent action grid

    private var actionGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let def = currentDefinition {
                    Text(def.title)
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        ForEach(visibleContextualVariants(for: def)) { variant in
                            actionButton(for: variant)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                } else {
                    Text("No situation selected.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(instances.selectedBoat.name)
                    .font(.subheadline).bold()
                Text("COG \(instances.COG)°, SOG \(String(format: "%.1f", instances.SOG)) kn")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onClose()
            } label: {
                Label("Close", systemImage: "xmark.circle.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }

    // MARK: - Single action button (grid cell)

    private func actionButton(for variant: ActionVariant) -> some View {
        Button {
            runAction(variant)
        } label: {
            VStack(spacing: 6) {
                if let systemImage = variant.systemImage {
                    Image(systemName: systemImage)
                        .font(.title2)
                }
                Text(variant.title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(variant.isEmphasised
                          ? Color.accentColor.opacity(0.15)
                          : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(variant.isEmphasised
                            ? Color.accentColor
                            : Color.secondary.opacity(0.4),
                            lineWidth: variant.isEmphasised ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Banner

    private func banner(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 2)
    }

    // MARK: - Helpers: visible variants

    /// AF variants for the fixed bar, filtered by `isVisible`.
    private func visibleAFVariants() -> [ActionVariant] {
        let ctx = actionContext

        let candidates: [ActionVariant] = topAFTags.compactMap { tag in
            registry.variant(for: tag)
        }

        return candidates.filter { variant in
            let runtime = ActionRuntime(context: ctx, variant: variant)
            return variant.isVisible(runtime)
        }
    }

    /// Contextual (situation-based) variants for the grid, filtered by `isVisible`
    /// and excluding AF-tags (they are handled in the top bar).
    private func visibleContextualVariants(for def: SituationDefinition) -> [ActionVariant] {
        let ctx = actionContext
        let afTagSet = Set(topAFTags)

        let tags = def.actionTags.filter { !afTagSet.contains($0) }

        let variants = registry.variants(for: tags)

        return variants.filter { variant in
            let runtime = ActionRuntime(context: ctx, variant: variant)
            return variant.isVisible(runtime)
        }
    }

    // MARK: - Run action

    private func runAction(_ variant: ActionVariant) {
        let ctx = actionContext
        let runtime = ActionRuntime(context: ctx, variant: variant)

        Task {
            await variant.handler(runtime)
        }
    }
}
