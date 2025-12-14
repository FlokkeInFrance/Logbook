//
//  ChecklistEditor.swift
//  SailTrips
//
//  Created by jeroen kok on 21/04/2025.
//

import SwiftUI
import SwiftData

struct ChecklistEditor: View {
    
    @Bindable var header: ChecklistHeader

    @EnvironmentObject var active: activations
    @EnvironmentObject var navPath: PathManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    @StateObject private var clipboard = Clipboard()
    @State private var newSectionName: String = ""
    @State private var newItemName: String = ""
    @State private var showAddSectionDialog: Bool = false
    @State private var showAddItemDialog: Bool = false
    @State private var canContinue: Bool = false
    @State private var folded: Bool = false
    @State private var showDeleteConfirmation = false
    @State private var foldedStates: [UUID: Bool] = [:]
    @State private var deletionChoice: SectionDeletionChoice?

    enum SectionDeletionChoice: Identifiable {
        case cancel, sectionOnly, sectionAndItems
        var id: Int { hashValue }
    }

    var body: some View {
        Text ("Edit Checklist: \(header.name)")
            .font(.title3)
        List {
            ForEach(header.sections.sorted(by: { $0.orderNum < $1.orderNum }), id: \.id) { section in
              Section(header: sectionHeaderView(for: section)) {
                  innerContent(for: section)
              }
            } //end of checklist forEach : enumeration of sections
            .onMove(perform: moveSection)
        } //end of List
        .listStyle(.plain)
        .onAppear {
            if header.sections.isEmpty {
                newSectionName = "Main Section"
                addSection()
                newSectionName  = ""
                header.completed = false
            }
            header.sections.sort(by: { $0.orderNum < $1.orderNum })
            header.completed = false
        }

        .toolbar {

            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showAddSectionDialog = true
                } label: {
                    Text("+Section")
                }
            }

            ToolbarItem() {
                Button{
                    EditElement()
                } label: {
                    Text("Edit")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddItemDialog = true
                } label: {
                    Text("+Item")
                }
            }

            ToolbarItem() {
                Button {
                    DeleteElement()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
              Menu {
                Button("Cut",   action: cutAction)
                  .disabled(active.activeItem == nil && active.activeSection == nil)
                Button("Copy",  action: copyAction)
                  .disabled(active.activeItem == nil && active.activeSection == nil)
                Button("Paste", action: pasteAction)
                  .disabled(clipboard.entry == nil)
                Button("Undo",  action: undoAction)
                  .disabled(!clipboard.lastActionWasCut)
              } label: {
                Label("Edit Clipboard", systemImage: "doc.on.clipboard")
              }
            }

        }//end of toolbar
        .alert("Add Section", isPresented: $showAddSectionDialog) {
            TextField("Section Name", text: $newSectionName)
            Button("Add", action: addSection)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Add Item", isPresented: $showAddItemDialog) {
            TextField("Item to add", text : $newItemName)
            Button("Add", action: addItem)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Item?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedItem()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this item?")
        }
        .actionSheet(item: $deletionChoice) { _ in
            ActionSheet(
                title: Text("Delete Section"),
                message: Text("Choose how you'd like to delete the section:"),
                buttons: [
                    .destructive(Text("Section and Items")) {
                        deleteSelectedSection(sectionOnly: false)
                    },
                    .destructive(Text("Section Only (Move Items to Previous)")) {
                        deleteSelectedSection(sectionOnly: true)
                    },
                    .cancel()
                ]
            )
        }//end of actionSheet
        //end of List modifiers
    }//end of body view
    
    //Functions and functionnalities
    
    private func sectionHeaderView(for section: ChecklistSection) -> some View {
      HStack {
        Text(section.nameOfSection)
          .font(.headline)
          .foregroundStyle(section.fontColor.swiftUIColor)
          .background(active.activeSection == section ? Color.gray.opacity(0.35) : Color.gray.opacity(0.12))
          
        Spacer()
        Image(systemName: foldedStates[section.id, default: false]
              ? "chevron.down"
              : "chevron.up")
      }
      .contentShape(Rectangle())
      .onTapGesture {
          if active.activeSection == section {
              foldedStates[section.id, default: false].toggle()
              active.activeItem = nil
          } else {
              if let previousSection = active.activeSection {
                  cleanupEmptyItems(in: previousSection)
              }
              active.activeItem = nil
              active.activeSection = section
          }
      }
    }
    
    private func innerContent(for section: ChecklistSection) -> some View {
        Group {
          if !foldedStates[section.id, default: false] {
            ForEach(section.items.sorted(by: { $0.itemNumber < $1.itemNumber })) { item in
              Text(item.itemShortText)
                    .onTapGesture {
                        active.activeItem = item
                        active.activeSection = section
                    }
                    .background(active.activeItem == item ? Color.blue.opacity(0.2) : Color.clear)
                    .padding(.leading, 10)
            }
            .onMove(perform: moveItem)

            if active.activeSection == section {
              TextField("new item…", text: $newItemName)
                .padding(.leading, 10)
                .onSubmit(addItem)
            }
          }
        }
      }
    
    func EditElement(){
        if active.activeItem == nil {
            if !(active.activeSection == nil) {
                navPath.path.append(ChecklistNav.sectiondetail)
            }
        }
        else{
            navPath.path.append(ChecklistNav.itemdetail)
        }
    }
    
    func DeleteElement() {
        if active.activeItem != nil {
            // Deleting an item directly
            showDeleteConfirmation = true
        } else if active.activeSection != nil {
            // Deleting a section: present choices
            deletionChoice = .cancel // Triggers actionSheet
        }
    }

    func deleteSelectedItem() {
        guard let item = active.activeItem,
              let section = active.activeSection,
              let index = section.items.firstIndex(of: item)
        else {
            print ("couldn't delete item")
            return }

        section.items.remove(at: index)
        modelContext.delete(item)

        try? modelContext.save()
        active.activeItem = nil
    }
    
    func deleteSelectedSection(sectionOnly: Bool) {
        guard let sectionToDelete = active.activeSection else {return}
        let header = sectionToDelete.header // as? ChecklistHeader else { return }

        if sectionOnly {
            // Check if it's not the first section
            guard sectionToDelete.orderNum > 1 else { return }
            
            // Find the previous section
            if let previousSection = header.sections.filter({ $0.orderNum == sectionToDelete.orderNum - 1 }).first {
                // Move items to previous section
                for item in sectionToDelete.items {
                    item.checklistSection = previousSection
                    item.itemNumber += previousSection.items.count
                    previousSection.items.append(item)
                }
                sectionToDelete.items.removeAll()
            }//items are displaced
        }
        // Update the order numbers of subsequent sections
        for sec in header.sections where sec.orderNum > sectionToDelete.orderNum {
            sec.orderNum -= 1
        }

        // Delete the section
        if let index = header.sections.firstIndex(of: sectionToDelete) {
            header.sections.remove(at: index)
        }
        modelContext.delete(sectionToDelete)
        try? modelContext.save()
        
        // Update active selection
        active.activeItem = nil
        active.activeSection = header.sections.filter { $0.orderNum == sectionToDelete.orderNum - 1 }.first
    }
    
    private func cleanupEmptyItems(in section: ChecklistSection) {
        // Remove empty items
        section.items
            .filter { $0.itemShortText.trimmingCharacters(in: .whitespaces).isEmpty }
            .forEach { item in
                if let index = section.items.firstIndex(of: item) {
                    section.items.remove(at: index)
                    modelContext.delete(item)
                }
            }
        // Renumber remaining items correctly
        let sortedItems = section.items.sorted { $0.itemNumber < $1.itemNumber }
        for (index, item) in sortedItems.enumerated() {
            item.itemNumber = index + 1
        }
        // Save changes to your data context
        try? modelContext.save()
    } // end of cleanUpEmpty Items
    
    private func addItem() {
        //Cases : item selected, add after this one
        //        section and no item : add at the end of the section
        //        nothing selected : add at the end of the list
        let trimmedName = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        newItemName = ""
        
        if active.activeSection == nil {//nothing is selected, try to find and select last section
            if !header.sections.isEmpty {
                var lastSection = header.sections.first!
                for section in header.sections {
                    if section.orderNum > lastSection.orderNum {
                        lastSection = section
                    }
                }
                active.activeSection = lastSection
                active.activeItem = nil
               
            }
            else {
                print ("Error in checklist header sections")
                return
            }
        }
        
        let newItem =  ChecklistItem(itemNumber: 1,checklistSection: active.activeSection!)
        newItem.itemShortText = trimmedName
        //first case : there is a selected item
        if let thisItem = active.activeItem {
            guard let section = active.activeSection else { return }
            let nb = thisItem.itemNumber
            for item in section.items {
                if item.itemNumber > nb {
                    item.itemNumber += 1
                }
            }
            newItem.itemNumber = nb+1
            active.activeSection?.items.append(newItem)
            active.activeItem = newItem
            try? modelContext.save()
            return
        }
        //2nd case : there is a selected section but not a selected item
        if let thissection = active.activeSection {
            newItem.itemNumber = thissection.items.count + 1
            thissection.items.append(newItem)
            active.activeItem = newItem
            try? modelContext.save()
            return
        }
    }// end of addItem function

    
    func addSection() {
        guard !newSectionName.isEmpty else { return }
        //cases : (1) an item, and thus a section is selected : add a section after the currentsd, append all items after this one to the new section
        //       (2) a section is selected : add a new empty section after the current
        //       (3) nothing is selected : append a new empty section
        //       (4) last section is selected : append a new empty section
        
        let newSection = ChecklistSection(orderNum: 1, header: header)
        newSection.nameOfSection = newSectionName
        newSectionName = ""
        
        if let oldItem = active.activeItem {
            //case (1)add a new section after the current one, and add all items following the current one
            // to the new section
            if let oldActive = active.activeSection{
                for sections in header.sections{
                    if sections.orderNum > oldActive.orderNum{
                        sections.orderNum = sections.orderNum + 1
                    }
                }
                newSection.orderNum = oldActive.orderNum + 1
                header.sections.append(newSection)
                //going to append items to new section
                let offset = oldItem.itemNumber
                for item in oldActive.items{
                    if item.itemNumber > offset{
                        item.checklistSection = newSection
                        item.itemNumber = item.itemNumber - offset
                        newSection.items.append(item)
                    }
                }
                if !newSection.items.isEmpty{
                    for item in newSection.items{
                        oldActive.items.remove(at: oldActive.items.firstIndex(of: item)!)
                    }
                }
                active.activeItem = nil
                active.activeSection = newSection
                try? modelContext.save()
            }
            return
        }
        if (active.activeSection == nil ||
            active.activeSection?.orderNum == header.sections.count){
            //append a new section at the end of the checklist case (3) and (4)
            newSection.orderNum = header.sections.count + 1
            header.sections.append(newSection)
            active.activeItem = nil
            active.activeSection = newSection
            try? modelContext.save()
        }
        else{
            // case (2)
            let oldActive = active.activeSection!
            for sections in header.sections{
                if sections.orderNum > oldActive.orderNum{
                    sections.orderNum = sections.orderNum + 1
                }
            }
            
            newSection.orderNum = oldActive.orderNum + 1
            header.sections.append(newSection)
            active.activeItem = nil
            active.activeSection = newSection
            try? modelContext.save()
        } // Reset section name after adding
    }
    
    func moveSection(from source: IndexSet, to destination: Int) {
        header.sections.move(fromOffsets: source, toOffset: destination)
        // Update order numbers after moving sections
        for (index, section) in header.sections.enumerated() {
            section.orderNum = index + 1
        }
        try? modelContext.save()
    }

    private func moveItem(from source: IndexSet, to destination: Int) {
        if let section = active.activeSection{
            var sortedItems = section.items.sorted(by: { $0.itemNumber < $1.itemNumber })
            
            sortedItems.move(fromOffsets: source, toOffset: destination)
            
            for (index, item) in sortedItems.enumerated() {
                item.itemNumber = index + 1
            }
            
            try? modelContext.save()
        }
    }
    
    // 1️⃣COPY
    func copyAction() {
      guard !(active.activeSection == nil && active.activeItem == nil) else { return }
        
      clipboard.lastActionWasCut = false

      if let item = active.activeItem {
        let data = ChecklistItemData(
          itemShortText: item.itemShortText,
          itemLongText:  item.itemLongText,
          itemNormalCheck: item.itemNormalCheck,
          textAlt1: item.textAlt1,
          textAlt2: item.textAlt2
        )
        let sectionOrder = item.checklistSection.orderNum
        let index = item.checklistSection.items.firstIndex(of: item)!
        clipboard.entry = .item(data: data,
                                originalSectionOrder: sectionOrder,
                                originalIndex: index)

      } else if let section = active.activeSection {
        let itemsData = section.items
          .sorted(by: { $0.itemNumber < $1.itemNumber })
          .map { itm in
            ChecklistItemData(
              itemShortText: itm.itemShortText,
              itemLongText:  itm.itemLongText,
              itemNormalCheck: itm.itemNormalCheck,
              textAlt1: itm.textAlt1,
              textAlt2: itm.textAlt2
            )
          }
        let index = header.sections.firstIndex(of: section)!
        clipboard.entry = .section(
          name: section.nameOfSection,
          fontColor: section.fontColor,
          items: itemsData,
          originalIndex: index
        )
      }
    }

    // 2️⃣ CUT
    func cutAction() {
    guard !(active.activeSection == nil && active.activeItem == nil) else { return }
        
      copyAction()
      clipboard.lastActionWasCut = true

      if let item = active.activeItem {
        // remove the model object
        let section = item.checklistSection
        section.items.removeAll { $0.id == item.id }
        modelContext.delete(item)

      } else if let section = active.activeSection {
        header.sections.removeAll { $0.id == section.id }
        modelContext.delete(section)
      }

      // re-number everything
      for (i, sec) in header.sections.enumerated() {
        sec.orderNum = i + 1
      }

      active.activeItem = nil
      active.activeSection = nil
      try? modelContext.save()
    }

    // 3️⃣ PASTE
    func pasteAction() {
      guard let entry = clipboard.entry else { return }
      clipboard.lastActionWasCut = false

      switch entry {
      case let .item(data, _, _):
        // decide target section + position
        let targetSection: ChecklistSection
        let insertIndex: Int

        if let selItem = active.activeItem {
          targetSection = selItem.checklistSection
          insertIndex = targetSection.items.firstIndex(of: selItem)! + 1

        } else if let selSection = active.activeSection {
          targetSection = selSection
          insertIndex = selSection.items.count

        } else {
          // no selection: last section
          targetSection = header.sections.last!
          insertIndex = targetSection.items.count
        }

        let newItem = ChecklistItem(itemNumber: insertIndex+1,
                                    checklistSection: targetSection)
        newItem.itemShortText = data.itemShortText
        newItem.itemLongText  = data.itemLongText
        newItem.itemNormalCheck = data.itemNormalCheck
        newItem.textAlt1 = data.textAlt1
        newItem.textAlt2 = data.textAlt2

        targetSection.items.insert(newItem, at: insertIndex)
        // renumber
        for (i, itm) in targetSection.items.enumerated() {
          itm.itemNumber = i + 1
        }

      case let .section(name, fontColor, itemsData, _)://_ was origIndex
        // decide insertion index
        let insertIndex: Int
        if let selSection = active.activeSection,
           let idx = header.sections.firstIndex(of: selSection) {
          insertIndex = idx + 1
        } else {
          insertIndex = header.sections.count
        }

        let newSection = ChecklistSection(orderNum: insertIndex+1,
                                          header: header)
        newSection.nameOfSection = name
        newSection.fontColor = fontColor

        // clone its items
        for (i, data) in itemsData.enumerated() {
          let itm = ChecklistItem(itemNumber: i+1,
                                  checklistSection: newSection)
          itm.itemShortText = data.itemShortText
          itm.itemLongText  = data.itemLongText
          itm.itemNormalCheck = data.itemNormalCheck
          itm.textAlt1 = data.textAlt1
          itm.textAlt2 = data.textAlt2
          newSection.items.append(itm)
        }

        header.sections.insert(newSection, at: insertIndex)
        // renumber all
        for (i, sec) in header.sections.enumerated() {
          sec.orderNum = i + 1
        }
      }
      // after paste, clear selection & save
      active.activeItem = nil
      active.activeSection = nil
      try? modelContext.save()
    }

    // 4️⃣ UNDO (only restores the last cut)
    func undoAction() {
      guard clipboard.lastActionWasCut,
            let entry = clipboard.entry else { return }

      switch entry {
      case let .item(data, sectionOrder, index):
        // re-insert the cut item
        let targetSection = header.sections.first { $0.orderNum == sectionOrder }!
        let itm = ChecklistItem(itemNumber: index+1,
                                 checklistSection: targetSection)
        itm.itemShortText  = data.itemShortText
        itm.itemLongText   = data.itemLongText
        itm.itemNormalCheck = data.itemNormalCheck
        itm.textAlt1 = data.textAlt1
        itm.textAlt2 = data.textAlt2
        targetSection.items.insert(itm, at: index)
        for (i, it) in targetSection.items.enumerated() {
          it.itemNumber = i + 1
        }

      case let .section(name, fontColor, itemsData, origIndex):
        let newSection = ChecklistSection(orderNum: origIndex+1,
                                          header: header)
        newSection.nameOfSection = name
        newSection.fontColor = fontColor
        for (i, data) in itemsData.enumerated() {
          let itm = ChecklistItem(itemNumber: i+1,
                                  checklistSection: newSection)
          itm.itemShortText  = data.itemShortText
          itm.itemLongText   = data.itemLongText
          itm.itemNormalCheck = data.itemNormalCheck
          itm.textAlt1 = data.textAlt1
          itm.textAlt2 = data.textAlt2
          newSection.items.append(itm)
        }
        header.sections.insert(newSection, at: origIndex)
        for (i, sec) in header.sections.enumerated() {
          sec.orderNum = i + 1
        }
      }

      clipboard.lastActionWasCut = false
      active.activeItem = nil
      active.activeSection = nil
      try? modelContext.save()
    }

}// End of ChecklistEditor

//Detail views

struct ChecklistItemDetailView: View {

    @EnvironmentObject var active: activations
    @Environment(\.modelContext) private var modelContext

    
    var body: some View {
        if let anItem = Binding($active.activeItem) {
            Form {
                    Text("Item Details")
                    TextField("Short Text", text: anItem.itemShortText)
                    TextField("Long Text", text: anItem.itemLongText)
                    Toggle("Normal Check", isOn: anItem.itemNormalCheck)
                if !anItem.itemNormalCheck.wrappedValue {
                        TextField("Alt 1", text: anItem.textAlt1)
                        TextField("Alt 2", text: anItem.textAlt2)
                }
            }
                .onDisappear {
                if anItem.itemShortText.wrappedValue == "" {
                    anItem.itemShortText.wrappedValue = "Item"
                }
                try? modelContext.save() }
        }
    }
}

struct ChecklistSectionEditView: View {
    @EnvironmentObject var active: activations
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if let sSection = Binding($active.activeSection){
            
            Form {
               
                //Text("Section appears at number: \(sSection.orderNum.wrappedValue)")
                //Spacer()
                Text(" Section's name:")
                TextField(text: sSection.nameOfSection, prompt: Text("Section Name")){
                    Text("Section's Name:")
                }
                .padding(6) // Padding inside the border
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                Picker("Color:", selection: sSection.fontColor) {
                    ForEach(SectionColors.allCases) { color in
                        Text(color.rawValue.capitalized)
                        .tag(color)
                    }
                }
            }
            .onDisappear {
                if sSection.nameOfSection.wrappedValue == "" {
                    sSection.nameOfSection.wrappedValue = "Section"
                }
                try? modelContext.save() }
        }
        else{
            Text("got error in Checklist Section Editor View")
        }
    }
}
