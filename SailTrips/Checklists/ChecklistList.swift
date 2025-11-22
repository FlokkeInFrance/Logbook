//
//  ContentView.swift
//  SailTrips
//
//  Created by jeroen kok on 01/04/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation

enum ChecklistNav{
    case detail
    case content
    case sectiondetail
    case itemdetail
}

struct ChecklistList: View {
    @Bindable var currentBoat: Boat
    
    @Query private var checklistHeaders: [ChecklistHeader]
    @State private var selectedChecklist: ChecklistHeader?
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var newNavPath: PathManager
    @EnvironmentObject var active: activations
    
    // MARK: – UI State
    @State private var showDeleteConfirmation = false
    @State private var showExportDialog = false
    @State private var showImportDialog = false
    
    // Temporary hold for the XML data to export
    @State private var exportData: Data?
    
    var filteredChecklists: [ChecklistHeader] {
        checklistHeaders.filter {
            $0.boat.id == currentBoat.id || $0.forAllBoats
        }
    }
    
    var body: some View {
        Text("Checklists for: \(currentBoat.name)")
            .font(.headline)
        
        List(filteredChecklists, selection: $selectedChecklist) { header in
            Text(header.name.isEmpty ? "Untitled Checklist" : header.name)
                .tag(header)
        }
        .environmentObject(active)
        .toolbar {
            // ────────────────────────────
            // Add
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    let newHeader = ChecklistHeader(boat: currentBoat)
                    newHeader.name = "New Checklist"
                    modelContext.insert(newHeader)
                    selectedChecklist = newHeader
                    newNavPath.path.append(ChecklistNav.detail)
                } label: {
                    Image(systemName: "plus")
                }
            }
            
            // ────────────────────────────
            // Delete
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .destructive) {
                    guard selectedChecklist != nil else { return }
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(selectedChecklist == nil)
                .alert("Delete Checklist?", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        deleteSelectedChecklist()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete “\(selectedChecklist?.name ?? "")”?")
                }
            }
            
            // ────────────────────────────
            // Detail / View
            ToolbarItem {
                Menu {
                    Button("Modify Checklist's header") {
                        if selectedChecklist != nil {
                            newNavPath.path.append(ChecklistNav.detail)
                        }
                    }
                    Button("Edit content") {
                        if selectedChecklist != nil {
                            active.activeItem = nil
                            active.activeSection = nil
                            newNavPath.path.append(ChecklistNav.content)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            // ────────────────────────────
            // Export / Import submenu
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Export as XML…") {
                        guard let header = selectedChecklist else { return }
                        exportData = xmlString(for: header).data(using: .utf8)
                        showExportDialog = true
                    }
                    Button("Import from XML…") {
                        showImportDialog = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                }
            }
        }
        // ────────────────────────────
        // File exporter
        .fileExporter(
            isPresented: $showExportDialog,
            document: XMLFileDocument(data: exportData ?? Data()),
            contentType: .xml,
            defaultFilename: selectedChecklist?.name ?? "Checklist"
        ) { result in
            // handle success/failure if needed
        }
        // ────────────────────────────
        // File importer
        .fileImporter(
            isPresented: $showImportDialog,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importChecklist(from: url)
            case .failure(let err):
                print("Import failed:", err)
            }
        }
        // ────────────────────────────
        // Navigation
        .navigationDestination(for: ChecklistNav.self) { navVal in
            switch navVal {
            case .detail:
                ChecklistHeaderDetailForm(inHeader: selectedChecklist!)
            case .content:
                ChecklistEditor(header: selectedChecklist!)
            case .sectiondetail:
                ChecklistSectionEditView()
            case .itemdetail:
                ChecklistItemDetailView()
            }
        }
    }
    
    // MARK: – Actions
    
    private func deleteSelectedChecklist() {
        guard let header = selectedChecklist else { return }
        modelContext.delete(header)
        try? modelContext.save()
        selectedChecklist = nil
    }
    
    private func xmlString(for header: ChecklistHeader) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<Checklist name=\"\(header.name.escapedXML)\">\n"
        
        // sections in orderNum order
        for section in header.sections.sorted(by: { $0.orderNum < $1.orderNum }) {
            xml += "  <Section name=\"\(section.nameOfSection.escapedXML)\" order=\"\(section.orderNum)\" color=\"\(section.fontColor.rawValue)\" />\n"
            for item in section.items.sorted(by: { $0.itemNumber < $1.itemNumber }) {
                xml += "    <Item number=\"\(item.itemNumber)\" shortText=\"\(item.itemShortText.escapedXML)\" />\n"
            }
        }
        xml += "</Checklist>\n"
        return xml
    }
    
    private func importChecklist(from url: URL) {
        print ("data importer got to import \(url) ")
        guard let data = try? Data(contentsOf: url) else { return }
        let importer = ChecklistImporter(
            data: data,
            boat: currentBoat,
            context: modelContext
        )
        importer.parse()
    }
}

// MARK: – Simple XML FileDocument wrapper

struct XMLFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.xml] }
    var data: Data
    
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        self.data = Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }
}

// MARK: – Helpers

extension String {
    var escapedXML: String {
        // very basic escaping
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

class ChecklistImporter: NSObject, XMLParserDelegate {
    private let currentBoat: Boat
    private let modelContext: ModelContext

    private var header: ChecklistHeader?
    private var currentSection: ChecklistSection?
    private var currentItem: ChecklistItem?
    var data: Data

    init(data: Data, boat: Boat, context: ModelContext) {
        self.data = data
        self.currentBoat = boat
        self.modelContext = context
    }

    func parse() {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        try? modelContext.save()
    }

    // MARK: – XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement name: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
      switch name {
        case "Checklist":
          guard let name = attributeDict["name"], !name.isEmpty else {
            parser.abortParsing()
            return
          }
          header = ChecklistHeader(boat: currentBoat)
          header?.name = name

        case "Section":
          guard let hdr = header else { return }
          let order = Int(attributeDict["order"] ?? "") ?? hdr.sections.count + 1
          let section = ChecklistSection(orderNum: order, header: hdr)
          section.nameOfSection = attributeDict["name"] ?? "Section"
          section.fontColor = SectionColors(rawValue: attributeDict["color"] ?? "") ?? .blue
          hdr.sections.append(section)
          currentSection = section

        case "Item":
          guard let section = currentSection,
                let text = attributeDict["shortText"], !text.isEmpty
          else { return }
          let num = Int(attributeDict["number"] ?? "") ?? section.items.count + 1
          let item = ChecklistItem(itemNumber: num, checklistSection: section)
          item.itemShortText = text
          section.items.append(item)
          // we don’t need to track currentItem since there’s no inner text
        default:
          break
      }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
      print("XML parse error:", parseError)
    }
}

struct ChecklistHeaderDetailForm: View {
    @Bindable var inHeader: ChecklistHeader
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
   
    var body: some View {
        VStack {
            Form {
                VStack {
                    Text("Checklist's features")
                        .font(.headline)
                    Spacer()
                    
                    TextField("Name", text: $inHeader.name)
                    Toggle("For All Boats", isOn: $inHeader.forAllBoats)
                    Toggle("Hide for 24hours after completion", isOn: $inHeader.wait24Hours)
                    Toggle("Emergency Checklist", isOn: $inHeader.emergencyCL)
                    Toggle("Always Show", isOn: $inHeader.alwaysShow)
                    
                    // Show conditions if necessary
                    if (!inHeader.alwaysShow) {
                        VStack(alignment: .leading) {
                            Text("Only show")
                                .frame(alignment: .leading)
                            // Picker for the condition variable
                            Picker("when :", selection: $inHeader.conditionalShow) {
                                ForEach(NavStatus.allCases) { variable in
                                    Text(variable.rawValue)
                                        .tag(variable)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}





