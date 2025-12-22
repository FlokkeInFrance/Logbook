//
//  ChecklistEditor.swift
//  SailTrips
//
//  Created by jeroen kok on 21/04/2025.
//  V2 created on 21/12/2025 with the help of ChatGPT 5.2
//
//
//
//  ChecklistEditorV2.swift
//  SailTrips
//
//  Modern inline editor for ChecklistHeader/Section/Item with collapsible option panels,
//  draft-first creation (no DB writes until Save), inline add rows, swipe actions,
//  and Expand/Collapse all.
//
//  POLISH:
//  - "Next" / Return advances focus (draft + existing)
//  - Existing checklists show a subtle unsaved-dot + explicit Save when needed
//

import SwiftUI
import SwiftData

// MARK: - Public host

struct ChecklistEditorV2Host: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let boat: Boat
    let existingHeader: ChecklistHeader?

    // Draft state (only used when existingHeader == nil)
    @State private var draft = DraftHeader.makeEmpty()
    @State private var showDiscardAlert = false
    @State private var showValidationAlert = false
    @State private var validationMessage: String = ""

    // Fold state is UI-only (not in model)
    @State private var expandedIDs: Set<UUID> = []
    @State private var expandAll: Bool = false

    // Edit mode enables drag reorder
    @State private var editMode: EditMode = .inactive

    // Focus handling
    @FocusState private var focusDraft: FocusDraftField?
    @FocusState private var focusExisting: FocusExistingField?

    init(boat: Boat, existingHeader: ChecklistHeader? = nil) {
        self.boat = boat
        self.existingHeader = existingHeader
    }

    var body: some View {
        Group {
            if let header = existingHeader {
                ChecklistEditorV2Existing(
                    header: header,
                    expandedIDs: $expandedIDs,
                    expandAll: $expandAll,
                    editMode: $editMode,
                    focusExisting: $focusExisting
                )
            } else {
                ChecklistEditorV2Draft(
                    boat: boat,
                    draft: $draft,
                    expandedIDs: $expandedIDs,
                    expandAll: $expandAll,
                    editMode: $editMode,
                    focusDraft: $focusDraft,
                    onCancelRequested: {
                        if draft.isEffectivelyEmpty {
                            dismiss()
                        } else {
                            showDiscardAlert = true
                        }
                    },
                    onSaveRequested: {
                        doSaveDraft()
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            // Leading close
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    if existingHeader != nil {
                        // For existing: just dismiss (edits may still be pending; user can Save explicitly)
                        dismiss()
                    } else {
                        if draft.isEffectivelyEmpty { dismiss() }
                        else { showDiscardAlert = true }
                    }
                }
            }

            // Center title with subtle unsaved dot (existing only)
            if let header = existingHeader {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text(header.name.isEmpty ? "Checklist" : header.name)
                            .lineLimit(1)

                        if modelContext.hasChanges {
                            Text("•")
                                .font(.title3)
                                .baselineOffset(1)
                                .accessibilityLabel("Unsaved changes")
                        }
                    }
                }
            } else {
                ToolbarItem(placement: .principal) {
                    Text(draft.name.isEmpty ? "New checklist" : draft.name)
                        .lineLimit(1)
                }
            }

            // Trailing controls
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    toggleExpandAll()
                } label: {
                    Image(systemName: expandAll ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                }
                .accessibilityLabel(expandAll ? "Collapse all" : "Expand all")

                // Explicit Save for EXISTING only (appears when needed)
                if existingHeader != nil, modelContext.hasChanges {
                    Button("Save") {
                        try? modelContext.save()
                    }
                }

                EditButton()
            }

            // Draft-only bottom bar
            if existingHeader == nil {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Cancel", role: .cancel) {
                        if draft.isEffectivelyEmpty { dismiss() }
                        else { showDiscardAlert = true }
                    }

                    Spacer()

                    Button("Save") {
                        doSaveDraft()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .alert("Discard changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Continue Editing", role: .cancel) { }
        } message: {
            Text("This checklist hasn’t been saved yet.")
        }
        .alert("Can’t save yet", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .onAppear {
            if existingHeader == nil {
                expandAll = false
                expandedIDs = [
                    draft.id,
                    draft.sections.first?.id ?? UUID(),
                    draft.sections.first?.items.first?.id ?? UUID()
                ]
                focusDraft = .headerName(draft.id)
            } else {
                expandAll = false
                expandedIDs = []
            }
        }
    }

    // MARK: - Expand/collapse helpers

    private func toggleExpandAll() {
        expandAll.toggle()

        if let header = existingHeader {
            if expandAll {
                var all: Set<UUID> = [header.id]
                for s in header.sections.sorted(by: { $0.orderNum < $1.orderNum }) {
                    all.insert(s.id)
                    for i in s.items.sorted(by: { $0.itemNumber < $1.itemNumber }) {
                        all.insert(i.id)
                    }
                }
                expandedIDs = all
            } else {
                expandedIDs.removeAll()
            }
        } else {
            if expandAll {
                var all: Set<UUID> = [draft.id]
                for s in draft.sections {
                    all.insert(s.id)
                    for i in s.items {
                        all.insert(i.id)
                    }
                }
                expandedIDs = all
            } else {
                expandedIDs.removeAll()
            }
        }
    }

    // MARK: - Draft saving

    private func doSaveDraft() {
        draft.normalizeNumbers()

        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            validationMessage = "Please enter a name for the checklist."
            showValidationAlert = true
            focusDraft = .headerName(draft.id)
            return
        }
        if draft.sections.isEmpty {
            validationMessage = "Please add at least one section."
            showValidationAlert = true
            return
        }

        let badSection = draft.sections.first(where: { $0.nameOfSection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        if let badSection {
            validationMessage = "Please enter a name for each section."
            showValidationAlert = true
            focusDraft = .sectionName(badSection.id)
            return
        }

        let newHeader = ChecklistHeader(boat: boat)
        newHeader.name = trimmedName
        newHeader.emergencyCL = draft.emergencyCL
        newHeader.alwaysShow = draft.alwaysShow
        newHeader.conditionalShow = draft.conditionalShow
        newHeader.canBeLogged = draft.canBeLogged
        newHeader.wait24Hours = draft.wait24Hours
        newHeader.latestRunDate = draft.latestRunDate
        newHeader.forAllBoats = false

        modelContext.insert(newHeader)

        for (sIndex, dSection) in draft.sections.enumerated() {
            let section = ChecklistSection(orderNum: sIndex, header: newHeader)
            section.nameOfSection = dSection.nameOfSection
            section.fontColor = dSection.fontColor
            modelContext.insert(section)
            newHeader.sections.append(section)

            for (iIndex, dItem) in dSection.items.enumerated() {
                let item = ChecklistItem(itemNumber: iIndex, checklistSection: section)
                item.itemShortText = dItem.itemShortText
                item.itemLongText = dItem.itemLongText
                item.itemNormalCheck = dItem.itemNormalCheck
                item.textAlt1 = dItem.textAlt1
                item.textAlt2 = dItem.textAlt2
                item.choiceAlt1 = dItem.choiceAlt1
                item.altCheckList = nil
                modelContext.insert(item)
                section.items.append(item)
            }
        }

        try? modelContext.save()
        dismiss()
    }


// MARK: - Existing checklist editor (live SwiftData editing)

    private struct ChecklistEditorV2Existing: View {
    @Environment(\.modelContext) private var modelContext

    let header: ChecklistHeader
    @Binding var expandedIDs: Set<UUID>
    @Binding var expandAll: Bool
    @Binding var editMode: EditMode

    @FocusState.Binding var focusExisting: FocusExistingField?

    var body: some View {
        List {
            headerBlock
            
            ForEach(sortedSections, id: \.id) { section in
                Section {
                    sectionRow(section)
                    
                    if isExpanded(section.id) {
                        sectionOptions(section)
                    }
                    
                    ForEach(sortedItems(in: section), id: \.id) { item in
                        itemRow(item)
                        
                        if isExpanded(item.id) {
                            itemOptions(item)
                        }
                    }
                    .onMove { indices, newOffset in
                        moveItems(in: section, from: indices, to: newOffset)
                    }
                    
                    Button {
                        let newID = addItem(to: section)
                        //expandedIDs.insert(newID) //put it back if finally it is better to have new item expanded
                        focusExisting = .itemShort(newID)
                    } label: {
                        Label("Add item", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            .onMove(perform: moveSections)
            
            Button {
                let newID = addSection()
                expandedIDs.insert(newID)
                focusExisting = .sectionName(newID)
            } label: {
                Label("Add section", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .onChange(of: focusExisting) { old, new in
                handleFocusChange(old: old, new: new)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }// End of existing editor

    // MARK: Header UI

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                expandChevron(id: header.id)
                TextField("Checklist name…", text: bindingHeaderName)
                    .submitLabel(.next)
                    .onSubmit {
                        if let first = sortedSections.first {
                            expandedIDs.insert(first.id)
                            focusExisting = .sectionName(first.id)
                        }
                    }
                    .focused($focusExisting, equals: .headerName(header.id))
                    .textInputAutocapitalization(.sentences)
            }

            if isExpanded(header.id) {
                headerOptions
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                modelContext.delete(header)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var bindingHeaderName: Binding<String> {
        Binding(
            get: { header.name },
            set: { header.name = $0 }
        )
    }

    private var headerOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Emergency checklist", isOn: Binding(get: { header.emergencyCL }, set: { header.emergencyCL = $0 }))
            Toggle("Always show", isOn: Binding(get: { header.alwaysShow }, set: { header.alwaysShow = $0 }))
            Picker("Show only when", selection: Binding(get: { header.conditionalShow }, set: { header.conditionalShow = $0 })) {
                Text("None").tag(NavStatus.none)
                ForEach(NavStatus.allCases, id: \.self) { st in
                    Text(st.displayString).tag(st)
                }
            }
            Toggle("Can be logged", isOn: Binding(get: { header.canBeLogged }, set: { header.canBeLogged = $0 }))
            Toggle("Hide for 24h after completion", isOn: Binding(get: { header.wait24Hours }, set: { header.wait24Hours = $0 }))
        }
        .font(.subheadline)
        .padding(.leading, 28)
        .padding(.top, 4)
    }

    // MARK: Section UI

    private func sectionRow(_ section: ChecklistSection) -> some View {
        HStack(spacing: 10) {
            expandChevron(id: section.id)

            TextField("Section name…", text: Binding(
                get: { section.nameOfSection },
                set: { section.nameOfSection = $0 }
            ))
            .focused($focusExisting, equals: .sectionName(section.id))
            .submitLabel(.next)
            .onSubmit {
                expandedIDs.insert(section.id)
                if let firstItem = sortedItems(in: section).first {
                    expandedIDs.insert(firstItem.id)
                    focusExisting = .itemShort(firstItem.id)
                } else {
                    let newID = addItem(to: section)
                    //expandedIDs.insert(newID)
                    focusExisting = .itemShort(newID)
                }
            }
            .textInputAutocapitalization(.sentences)

            Spacer()

            Circle()
                .fill(section.fontColor.swiftUIColor)
                .frame(width: 10, height: 10)
                .opacity(0.9)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteSection(section)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                duplicateSection(section)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
        }
    }

    private func sectionOptions(_ section: ChecklistSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Color", selection: Binding(get: { section.fontColor }, set: { section.fontColor = $0 })) {
                ForEach(SectionColors.allCases, id: \.self) { c in
                    Text(c.rawValue.capitalized).tag(c)
                }
            }

            Button(role: .destructive) {
                deleteSection(section)
            } label: {
                Label("Delete section", systemImage: "trash")
            }
        }
        .font(.subheadline)
        .padding(.leading, 28)
        .padding(.top, 2)
    }

    // MARK: Item UI

    private func itemRow(_ item: ChecklistItem) -> some View {
        HStack(spacing: 10) {
            expandChevron(id: item.id)

            TextField("New item…", text: Binding(
                get: { item.itemShortText },
                set: { item.itemShortText = $0 }
            ))
            .focused($focusExisting, equals: .itemShort(item.id))
            .submitLabel(.next)
            .onSubmit {
                let section = item.checklistSection
                let newID = addItem(to: section)
                //expandedIDs.insert(section.id)
                //expandedIDs.insert(newID) put back if it is better to have items expanded
                focusExisting = .itemShort(newID)
            }
            .textInputAutocapitalization(.sentences)

            Spacer()

            if !item.itemNormalCheck {
                Text("ALT")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                duplicateItem(item)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
        }
    }

    private func itemOptions(_ item: ChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Normal check", isOn: Binding(
                get: { item.itemNormalCheck },
                set: { item.itemNormalCheck = $0 }
            ))

            if item.itemNormalCheck {
                TextField("Long text (optional)…", text: Binding(
                    get: { item.itemLongText },
                    set: { item.itemLongText = $0 }
                ), axis: .vertical)
                .lineLimit(2...6)
            } else {
                TextField("Alt 1 text…", text: Binding(get: { item.textAlt1 }, set: { item.textAlt1 = $0 }))
                TextField("Alt 2 text…", text: Binding(get: { item.textAlt2 }, set: { item.textAlt2 = $0 }))
                Toggle("Default choice: Alt 1", isOn: Binding(get: { item.choiceAlt1 }, set: { item.choiceAlt1 = $0 }))
            }

            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label("Delete item", systemImage: "trash")
            }
        }
        .font(.subheadline)
        .padding(.leading, 28)
        .padding(.top, 2)
    }

    // MARK: Expand helpers

    private func isExpanded(_ id: UUID) -> Bool { expandedIDs.contains(id) }

    @ViewBuilder
    private func expandChevron(id: UUID) -> some View {
        Button {
            if isExpanded(id) { expandedIDs.remove(id) }
            else { expandedIDs.insert(id) }
        } label: {
            Image(systemName: isExpanded(id) ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 18)
        }
        .buttonStyle(.plain)
    }

    // MARK: Sorting

    private var sortedSections: [ChecklistSection] {
        header.sections.sorted(by: { $0.orderNum < $1.orderNum })
    }

    private func sortedItems(in section: ChecklistSection) -> [ChecklistItem] {
        section.items.sorted(by: { $0.itemNumber < $1.itemNumber })
    }

    // MARK: Mutations

    @discardableResult
    private func addSection() -> UUID {
        let nextOrder = (sortedSections.last?.orderNum ?? -1) + 1
        let s = ChecklistSection(orderNum: nextOrder, header: header)
        s.nameOfSection = ""
        s.fontColor = .blue
        modelContext.insert(s)
        header.sections.append(s)
        renumberSections()
        try? modelContext.save()
        return s.id
    }

    private func deleteSection(_ section: ChecklistSection) {
        modelContext.delete(section)
        renumberSections()
        try? modelContext.save()
    }

    private func duplicateSection(_ section: ChecklistSection) {
        let nextOrder = (sortedSections.last?.orderNum ?? -1) + 1
        let copy = ChecklistSection(orderNum: nextOrder, header: header)
        copy.nameOfSection = section.nameOfSection
        copy.fontColor = section.fontColor
        modelContext.insert(copy)
        header.sections.append(copy)

        let items = sortedItems(in: section)
        for (idx, it) in items.enumerated() {
            let newItem = ChecklistItem(itemNumber: idx, checklistSection: copy)
            newItem.itemShortText = it.itemShortText
            newItem.itemLongText = it.itemLongText
            newItem.itemNormalCheck = it.itemNormalCheck
            newItem.textAlt1 = it.textAlt1
            newItem.textAlt2 = it.textAlt2
            newItem.choiceAlt1 = it.choiceAlt1
            modelContext.insert(newItem)
            copy.items.append(newItem)
        }

        renumberSections()
        try? modelContext.save()
    }

    @discardableResult
    private func addItem(to section: ChecklistSection) -> UUID {
        let next = (sortedItems(in: section).last?.itemNumber ?? -1) + 1
        let item = ChecklistItem(itemNumber: next, checklistSection: section)
        item.itemShortText = ""
        modelContext.insert(item)
        section.items.append(item)
        renumberItems(in: section)
        try? modelContext.save()
        return item.id
    }

    private func deleteItem(_ item: ChecklistItem) {
        let section = item.checklistSection
        modelContext.delete(item)
        renumberItems(in: section)
        try? modelContext.save()
    }

    private func duplicateItem(_ item: ChecklistItem) {
        let section = item.checklistSection
        let next = (sortedItems(in: section).last?.itemNumber ?? -1) + 1
        let copy = ChecklistItem(itemNumber: next, checklistSection: section)
        copy.itemShortText = item.itemShortText
        copy.itemLongText = item.itemLongText
        copy.itemNormalCheck = item.itemNormalCheck
        copy.textAlt1 = item.textAlt1
        copy.textAlt2 = item.textAlt2
        copy.choiceAlt1 = item.choiceAlt1
        modelContext.insert(copy)
        section.items.append(copy)
        renumberItems(in: section)
        try? modelContext.save()
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        var arr = sortedSections
        arr.move(fromOffsets: source, toOffset: destination)
        for (i, s) in arr.enumerated() { s.orderNum = i }
        try? modelContext.save()
    }

    private func moveItems(in section: ChecklistSection, from source: IndexSet, to destination: Int) {
        var arr = sortedItems(in: section)
        arr.move(fromOffsets: source, toOffset: destination)
        for (i, it) in arr.enumerated() { it.itemNumber = i }
        try? modelContext.save()
    }

    private func renumberSections() {
        let arr = sortedSections
        for (i, s) in arr.enumerated() { s.orderNum = i }
    }

    private func renumberItems(in section: ChecklistSection) {
        let arr = sortedItems(in: section)
        for (i, it) in arr.enumerated() { it.itemNumber = i }
    }
    
    private func findItem(by id: UUID) -> ChecklistItem? {
        for s in header.sections {
            if let it = s.items.first(where: { $0.id == id }) { return it }
        }
        return nil
    }
    
    private func handleFocusChange(old: FocusExistingField?, new: FocusExistingField?) {
        // If we are leaving an itemShort field, decide whether to delete it.
        guard case .itemShort(let oldID) = old else { return }
        // If focus stays on same item, do nothing.
        if case .itemShort(let newID) = new, newID == oldID { return }
        
        guard let item = findItem(by: oldID) else { return }
        
        // Only delete if it’s empty
        guard item.isEffectivelyEmpty else { return }
        
        // Optionally: avoid deleting the only item in a section (keeps a placeholder row).
        let section = item.checklistSection
        if section.items.count <= 1 {
            // keep one placeholder item; just ensure it’s blank
            item.itemShortText = ""
            item.itemLongText = ""
            item.textAlt1 = ""
            item.textAlt2 = ""
            try? modelContext.save()
            return
        }
        
        // Dismiss keyboard first (clearing focus)
        focusExisting = nil
        
        // Delete & renumber
        modelContext.delete(item)
        renumberItems(in: section)
        try? modelContext.save()
    }
}

// MARK: - Draft checklist editor (no DB writes until Save)

    private struct ChecklistEditorV2Draft: View {
        let boat: Boat
        
        @Binding var draft: DraftHeader
        @Binding var expandedIDs: Set<UUID>
        @Binding var expandAll: Bool
        @Binding var editMode: EditMode
        
        @FocusState.Binding var focusDraft: FocusDraftField?
        
        let onCancelRequested: () -> Void
        let onSaveRequested: () -> Void
        
        var body: some View {
            List {
                draftHeaderBlock
                
                ForEach(draft.sections) { section in
                    Section {
                        draftSectionRow(section)
                        
                        if isExpanded(section.id) {
                            draftSectionOptions(section)
                        }
                        
                        ForEach(section.items) { item in
                            draftItemRow(sectionID: section.id, item: item)
                            
                            if isExpanded(item.id) {
                                draftItemOptions(sectionID: section.id, item: item)
                            }
                        }
                        .onMove { indices, newOffset in
                            moveDraftItems(sectionID: section.id, from: indices, to: newOffset)
                        }
                        
                        Button {
                            let newID = addDraftItem(to: section.id)
                            //expandedIDs.insert(newID)
                            focusDraft = .itemShort(newID)
                        } label: {
                            Label("Add item", systemImage: "plus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove(perform: moveDraftSections)
                
                Button {
                    let newID = addDraftSection()
                    expandedIDs.insert(newID)
                    focusDraft = .sectionName(newID)
                } label: {
                    Label("Add section", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
            }
            .onChange(of: focusDraft) { old, new in
                handleDraftFocusChange(old: old, new: new)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        
        
        // MARK: Draft header UI
        
        private var draftHeaderBlock: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    expandChevron(id: draft.id)
                    TextField("Checklist name…", text: $draft.name)
                        .focused($focusDraft, equals: .headerName(draft.id))
                        .submitLabel(.next)
                        .onSubmit {
                            if let firstSection = draft.sections.first {
                                expandedIDs.insert(firstSection.id)
                                focusDraft = .sectionName(firstSection.id)
                            } else {
                                let newID = addDraftSection()
                                expandedIDs.insert(newID)
                                focusDraft = .sectionName(newID)
                            }
                        }
                        .textInputAutocapitalization(.sentences)
                }
                
                if isExpanded(draft.id) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Emergency checklist", isOn: $draft.emergencyCL)
                        Toggle("Always show", isOn: $draft.alwaysShow)
                        Picker("Show only when", selection: $draft.conditionalShow) {
                            Text("None").tag(NavStatus.none)
                            ForEach(NavStatus.allCases, id: \.self) { st in
                                Text(st.displayString).tag(st)
                            }
                        }
                        Toggle("Can be logged", isOn: $draft.canBeLogged)
                        Toggle("Hide for 24h after completion", isOn: $draft.wait24Hours)
                    }
                    .font(.subheadline)
                    .padding(.leading, 28)
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 6)
        }
        
        private func handleDraftFocusChange(old: FocusDraftField?, new: FocusDraftField?) {
            guard case .itemShort(let oldID) = old else { return }
            if case .itemShort(let newID) = new, newID == oldID { return }
            
            // Find where it lives
            for sIdx in draft.sections.indices {
                if let iIdx = draft.sections[sIdx].items.firstIndex(where: { $0.id == oldID }) {
                    let item = draft.sections[sIdx].items[iIdx]
                    guard item.isEffectivelyEmpty else { return }
                    
                    // Optional: keep a placeholder if it's the last one
                    if draft.sections[sIdx].items.count <= 1 {
                        // keep one placeholder (blank)
                        draft.sections[sIdx].items[iIdx] = DraftItem.makeEmpty(itemNumber: 0)
                        draft.normalizeNumbers()
                        return
                    }
                    
                    // Dismiss keyboard, delete row
                    focusDraft = nil
                    draft.sections[sIdx].items.remove(at: iIdx)
                    draft.normalizeNumbers()
                    return
                }
            }
        }
        // MARK: Draft section UI
        
        private func draftSectionRow(_ section: DraftSection) -> some View {
            HStack(spacing: 10) {
                expandChevron(id: section.id)
                
                TextField("Section name…", text: bindingSectionName(section.id))
                    .focused($focusDraft, equals: .sectionName(section.id))
                    .submitLabel(.next)
                    .onSubmit {
                        expandedIDs.insert(section.id)
                        if let firstItem = draft.sections.first(where: { $0.id == section.id })?.items.first {
                            expandedIDs.insert(firstItem.id)
                            focusDraft = .itemShort(firstItem.id)
                        } else {
                            let newID = addDraftItem(to: section.id)
                            expandedIDs.insert(newID)
                            focusDraft = .itemShort(newID)
                        }
                    }
                    .textInputAutocapitalization(.sentences)
                
                Spacer()
                
                Circle()
                    .fill(section.fontColor.swiftUIColor)
                    .frame(width: 10, height: 10)
                    .opacity(0.9)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteDraftSection(section.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    duplicateDraftSection(section.id)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
            }
        }
        
        private func draftSectionOptions(_ section: DraftSection) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Color", selection: bindingSectionColor(section.id)) {
                    ForEach(SectionColors.allCases, id: \.self) { c in
                        Text(c.rawValue.capitalized).tag(c)
                    }
                }
                
                Button(role: .destructive) {
                    deleteDraftSection(section.id)
                } label: {
                    Label("Delete section", systemImage: "trash")
                }
            }
            .font(.subheadline)
            .padding(.leading, 28)
            .padding(.top, 2)
        }
        
        // MARK: Draft item UI
        
        private func draftItemRow(sectionID: UUID, item: DraftItem) -> some View {
            HStack(spacing: 10) {
                expandChevron(id: item.id)
                
                TextField("New item…", text: bindingItemShortText(sectionID: sectionID, itemID: item.id))
                    .focused($focusDraft, equals: .itemShort(item.id))
                    .submitLabel(.next)
                    .onSubmit {
                        // Notes/Reminders-style: Return creates the next item in the same section
                        let newID = addDraftItem(to: sectionID)
                        //expandedIDs.insert(sectionID)
                        //expandedIDs.insert(newID)
                        focusDraft = .itemShort(newID)
                    }
                    .textInputAutocapitalization(.sentences)
                
                Spacer()
                
                if !item.itemNormalCheck {
                    Text("ALT")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteDraftItem(sectionID: sectionID, itemID: item.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    duplicateDraftItem(sectionID: sectionID, itemID: item.id)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
            }
        }
        
        private func draftItemOptions(sectionID: UUID, item: DraftItem) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Normal check", isOn: bindingItemNormal(sectionID: sectionID, itemID: item.id))
                
                if item.itemNormalCheck {
                    TextField("Long text (optional)…",
                              text: bindingItemLongText(sectionID: sectionID, itemID: item.id),
                              axis: .vertical)
                    .lineLimit(2...6)
                } else {
                    TextField("Alt 1 text…", text: bindingItemAlt1(sectionID: sectionID, itemID: item.id))
                    TextField("Alt 2 text…", text: bindingItemAlt2(sectionID: sectionID, itemID: item.id))
                    Toggle("Default choice: Alt 1", isOn: bindingItemChoiceAlt1(sectionID: sectionID, itemID: item.id))
                }
                
                Button(role: .destructive) {
                    deleteDraftItem(sectionID: sectionID, itemID: item.id)
                } label: {
                    Label("Delete item", systemImage: "trash")
                }
            }
            .font(.subheadline)
            .padding(.leading, 28)
            .padding(.top, 2)
        }
        
        // MARK: Expand helpers
        
        private func isExpanded(_ id: UUID) -> Bool { expandedIDs.contains(id) }
        
        @ViewBuilder
        private func expandChevron(id: UUID) -> some View {
            Button {
                if isExpanded(id) { expandedIDs.remove(id) }
                else { expandedIDs.insert(id) }
            } label: {
                Image(systemName: isExpanded(id) ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
        }
        
        // MARK: Draft mutations
        
        @discardableResult
        private func addDraftSection() -> UUID {
            draft.sections.append(DraftSection.makeEmpty(orderNum: draft.sections.count))
            draft.normalizeNumbers()
            return draft.sections.last?.id ?? UUID()
        }
        
        private func deleteDraftSection(_ id: UUID) {
            draft.sections.removeAll(where: { $0.id == id })
            draft.normalizeNumbers()
        }
        
        private func duplicateDraftSection(_ id: UUID) {
            guard let idx = draft.sections.firstIndex(where: { $0.id == id }) else { return }
            let original = draft.sections[idx]
            var copy = original
            copy.id = UUID()
            copy.items = original.items.map { it in
                var c = it
                c.id = UUID()
                return c
            }
            draft.sections.insert(copy, at: idx + 1)
            draft.normalizeNumbers()
        }
        
        @discardableResult
        private func addDraftItem(to sectionID: UUID) -> UUID {
            guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return UUID() }
            draft.sections[sIdx].items.append(DraftItem.makeEmpty(itemNumber: draft.sections[sIdx].items.count))
            draft.normalizeNumbers()
            return draft.sections[sIdx].items.last?.id ?? UUID()
        }
        
        private func deleteDraftItem(sectionID: UUID, itemID: UUID) {
            guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            draft.sections[sIdx].items.removeAll(where: { $0.id == itemID })
            draft.normalizeNumbers()
        }
        
        private func duplicateDraftItem(sectionID: UUID, itemID: UUID) {
            guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            guard let iIdx = draft.sections[sIdx].items.firstIndex(where: { $0.id == itemID }) else { return }
            var copy = draft.sections[sIdx].items[iIdx]
            copy.id = UUID()
            draft.sections[sIdx].items.insert(copy, at: iIdx + 1)
            draft.normalizeNumbers()
        }
        
        private func moveDraftSections(from source: IndexSet, to destination: Int) {
            draft.sections.move(fromOffsets: source, toOffset: destination)
            draft.normalizeNumbers()
        }
        
        private func moveDraftItems(sectionID: UUID, from source: IndexSet, to destination: Int) {
            guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            draft.sections[sIdx].items.move(fromOffsets: source, toOffset: destination)
            draft.normalizeNumbers()
        }
        
        // MARK: Draft bindings (unchanged)
        
        private func bindingSectionName(_ sectionID: UUID) -> Binding<String> {
            Binding(
                get: { draft.sections.first(where: { $0.id == sectionID })?.nameOfSection ?? "" },
                set: { newValue in
                    guard let idx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
                    draft.sections[idx].nameOfSection = newValue
                }
            )
        }
        
        private func bindingSectionColor(_ sectionID: UUID) -> Binding<SectionColors> {
            Binding(
                get: { draft.sections.first(where: { $0.id == sectionID })?.fontColor ?? .blue },
                set: { newValue in
                    guard let idx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
                    draft.sections[idx].fontColor = newValue
                }
            )
        }
        
        private func bindingItemShortText(sectionID: UUID, itemID: UUID) -> Binding<String> {
            Binding(
                get: {
                    draft.sections.first(where: { $0.id == sectionID })?
                        .items.first(where: { $0.id == itemID })?.itemShortText ?? ""
                },
                set: { newValue in
                    guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
                    guard let iIdx = draft.sections[sIdx].items.firstIndex(where: { $0.id == itemID }) else { return }
                    draft.sections[sIdx].items[iIdx].itemShortText = newValue
                }
            )
        }
        
        private func bindingItemLongText(sectionID: UUID, itemID: UUID) -> Binding<String> {
            Binding(
                get: {
                    draft.sections.first(where: { $0.id == sectionID })?
                        .items.first(where: { $0.id == itemID })?.itemLongText ?? ""
                },
                set: { newValue in
                    guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
                    guard let iIdx = draft.sections[sIdx].items.firstIndex(where: { $0.id == itemID }) else { return }
                    draft.sections[sIdx].items[iIdx].itemLongText = newValue
                }
            )
        }
        
        private func bindingItemNormal(sectionID: UUID, itemID: UUID) -> Binding<Bool> {
            Binding(
                get: {
                    draft.sections.first(where: { $0.id == sectionID })?
                        .items.first(where: { $0.id == itemID })?.itemNormalCheck ?? true
                },
                set: { newValue in
                    guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
                    guard let iIdx = draft.sections[sIdx].items.firstIndex(where: { $0.id == itemID }) else { return }
                    draft.sections[sIdx].items[iIdx].itemNormalCheck = newValue
                }
            )
        }
        
        private func bindingItemAlt1(sectionID: UUID, itemID: UUID) -> Binding<String> {
            Binding(
                get: {
                    draft.sections.first(where: { $0.id == sectionID })?
                        .items.first(where: { $0.id == itemID })?.textAlt1 ?? ""
                },
                set: { newValue in
                    guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
                    guard let iIdx = draft.sections[sIdx].items.firstIndex(where: { $0.id == itemID }) else { return }
                    draft.sections[sIdx].items[iIdx].textAlt1 = newValue
                }
            )
        }
        
        private func bindingItemAlt2(sectionID: UUID, itemID: UUID) -> Binding<String> {
            Binding(
                get: {
                    draft.sections.first(where: { $0.id == sectionID })?
                        .items.first(where: { $0.id == itemID })?.textAlt2 ?? ""
                },
                set: { newValue in
                    guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
                    guard let iIdx = draft.sections[sIdx].items.firstIndex(where: { $0.id == itemID }) else { return }
                    draft.sections[sIdx].items[iIdx].textAlt2 = newValue
                }
            )
        }
        
        private func bindingItemChoiceAlt1(sectionID: UUID, itemID: UUID) -> Binding<Bool> {
            Binding(
                get: {
                    draft.sections.first(where: { $0.id == sectionID })?
                        .items.first(where: { $0.id == itemID })?.choiceAlt1 ?? true
                },
                set: { newValue in
                    guard let sIdx = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
                    guard let iIdx = draft.sections[sIdx].items.firstIndex(where: { $0.id == itemID }) else { return }
                    draft.sections[sIdx].items[iIdx].choiceAlt1 = newValue
                }
            )
        }
    } // ✅ end ChecklistEditorV2Draft
    
    // MARK: - Draft models
    
    private struct DraftHeader: Identifiable {
        var id: UUID = UUID()
        
        var name: String = ""
        
        var emergencyCL: Bool = false
        var alwaysShow: Bool = true
        var conditionalShow: NavStatus = .none
        var canBeLogged: Bool = true
        var latestRunDate: Date = .distantPast
        var wait24Hours: Bool = false
        
        var sections: [DraftSection] = []
        
        static func makeEmpty() -> DraftHeader {
            var h = DraftHeader()
            h.sections = [DraftSection.makeEmpty(orderNum: 0)]
            return h
        }
        
        mutating func normalizeNumbers() {
            for (sIdx, _) in sections.enumerated() {
                sections[sIdx].orderNum = sIdx
                for (iIdx, _) in sections[sIdx].items.enumerated() {
                    sections[sIdx].items[iIdx].itemNumber = iIdx
                }
            }
        }
        
        var isEffectivelyEmpty: Bool {
            let nameEmpty = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let allSectionsEmpty = sections.allSatisfy { $0.isEffectivelyEmpty }
            return nameEmpty && allSectionsEmpty
        }
    }
    
    private struct DraftSection: Identifiable {
        var id: UUID = UUID()
        var orderNum: Int = 0
        var nameOfSection: String = ""
        var fontColor: SectionColors = .blue
        var items: [DraftItem] = []
        
        static func makeEmpty(orderNum: Int) -> DraftSection {
            var s = DraftSection()
            s.orderNum = orderNum
            s.items = [DraftItem.makeEmpty(itemNumber: 0)]
            return s
        }
        
        var isEffectivelyEmpty: Bool {
            let nameEmpty = nameOfSection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let allItemsEmpty = items.allSatisfy { $0.isEffectivelyEmpty }
            return nameEmpty && allItemsEmpty
        }
    }
    
    private struct DraftItem: Identifiable {
        var id: UUID = UUID()
        var itemNumber: Int = 0
        var itemShortText: String = ""
        var itemLongText: String = ""
        
        var itemNormalCheck: Bool = true
        var textAlt1: String = ""
        var textAlt2: String = ""
        var choiceAlt1: Bool = true
        
        static func makeEmpty(itemNumber: Int) -> DraftItem {
            var i = DraftItem()
            i.itemNumber = itemNumber
            return i
        }
        
        var isEffectivelyEmpty: Bool {
            itemShortText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            itemLongText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            textAlt1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            textAlt2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - Focus types
    
    private enum FocusDraftField: Hashable {
        case headerName(UUID)
        case sectionName(UUID)
        case itemShort(UUID)
    }
    
    private enum FocusExistingField: Hashable {
        case headerName(UUID)
        case sectionName(UUID)
        case itemShort(UUID)
    }
}
    
private extension ChecklistItem {
    var isEffectivelyEmpty: Bool {
        itemShortText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        itemLongText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        textAlt1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        textAlt2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
