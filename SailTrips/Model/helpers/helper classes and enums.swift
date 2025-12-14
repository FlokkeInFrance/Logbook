//
//  helper classes and enums.swift
//  SailTrips
//
//  Created by jeroen kok on 30/05/2025.
//
import SwiftUI
import SwiftData


class PathManager:ObservableObject{
    @Published var path = NavigationPath()
}

class activations: ObservableObject {
    @Published var activeItem: ChecklistItem? = nil
    @Published var activeSection: ChecklistSection? = nil
    @Published var lastNumberChecked: Int? = nil
    @Published var lastLatitude: Double? = nil
    @Published var lastLongitude: Double? = nil
    @Published var selectedTripID: UUID? = nil
    @Published var selectedTripDetailsID: UUID? = nil  
}

class observedString: ObservableObject {
    @Published var oString: String = ""
}

enum ClipboardEntry {
  case section(
    name: String,
    fontColor: SectionColors,
    items: [ChecklistItemData],
    originalIndex: Int
  )
  case item(
    data: ChecklistItemData,
    originalSectionOrder: Int,
    originalIndex: Int
  )
}

struct ChecklistItemData: Identifiable {
  let id = UUID()
  var itemShortText: String
  var itemLongText: String
  var itemNormalCheck: Bool
  var textAlt1: String
  var textAlt2: String
}

final class Clipboard: ObservableObject {
  @Published var entry: ClipboardEntry?
  @Published var lastActionWasCut = false
}

// MARK: - LogQueue (stack with move-to-top semantics)
final class LogQueue: ObservableObject {
    struct Item: Identifiable, Equatable {
        static func == (lhs: LogQueue.Item, rhs: LogQueue.Item) -> Bool {
           return( lhs.id == rhs.id)
        }
        
let id = UUID()
let key: String // variable key (e.g., "mooringUsed") for de-dup/move-to-top
let text: String // prepared log line
// optional payload changes to copy into Logs model when flushing
let apply: ((inout Logs) -> Void)?
}

@Published private(set) var items: [Item] = []

func enqueue(key: String, text: String, apply: ((inout Logs) -> Void)? = nil) {
// Remove any prior entry with same key, then push to top
items.removeAll { $0.key == key }
items.insert(Item(key: key, text: text, apply: apply), at: 0)
}

func clear() { items.removeAll() }
}



