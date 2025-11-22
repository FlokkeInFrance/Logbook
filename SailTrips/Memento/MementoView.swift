import SwiftUI
import SwiftData

/// A sheet view for creating and browsing quick text memos.
struct MementoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Query all mementos, sorted by date ascending
    @Query(sort: \Memento.date, order: .forward) private var mementos: [Memento]

    // Current displayed index
    @State private var currentIndex: Int = 0
    // Toggle for list view
    @State private var showList: Bool = false
    // Delete-all confirmation
    @State private var showDeleteAllConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Display current memo
                if !mementos.isEmpty {
                    let memo = mementos[currentIndex]
                    ZStack(alignment: .topLeading) {
                        if memo.text.isEmpty {
                            Text("Enter memo...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                        }
                        TextEditor(
                            text: Binding(
                                get: { memo.text },
                                set: { newValue in
                                    memo.text = newValue
                                    memo.date = Date()
                                    try? context.save()
                                }
                            )
                        )
                        .padding(4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke()
                    )
                } else {
                    Text("No memos yet.")
                        .italic()
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(RoundedRectangle(cornerRadius: 8).stroke())
                }
               /* if !mementos.isEmpty {
                    let memo = mementos[currentIndex]
                                        TextField(
                                            "Enter memo...",
                                            text: Binding(
                                                get: { memo.text },
                                                set: { newValue in
                                                    memo.text = newValue
                                                    memo.date = Date()
                                                    try? context.save()
                                                }
                                            )
                                        )
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .background(RoundedRectangle(cornerRadius: 8).stroke())
                } else {
                    Text("No memos yet.")
                        .italic()
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .background(RoundedRectangle(cornerRadius: 8).stroke())
                }*/

                // Controls
                HStack(spacing: 12) {
                    Button(action: { showList.toggle() }) {
                        Label("List", systemImage: showList ? "list.bullet.indent" : "list.bullet")
                    }
                    .disabled(mementos.isEmpty)

                    Spacer()

                    Button(action: previous) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentIndex <= 0)

                    Button(action: next) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentIndex >= mementos.count - 1)

                    Spacer()

                    Button(action: add) {
                        Image(systemName: "plus")
                    }

                    Button(action: deleteCurrent) {
                        Image(systemName: "trash")
                    }
                    .disabled(mementos.isEmpty)
                }
                .font(.title2)

                // List of memos
                if showList {
                    List {
                        ForEach(Array(mementos.enumerated()), id: \.element.id) { index, memo in
                            Button(action: {
                                currentIndex = index
                                showList = false
                            }) {
                                HStack {
                                    Text(memo.text)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(memo.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)

                    Button(role: .destructive, action: {
                        showDeleteAllConfirmation = true
                    }) {
                        Text("Delete All")
                    }
                    .confirmationDialog(
                        "Are you sure? This action cannot be undone.",
                        isPresented: $showDeleteAllConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Everything", role: .destructive) {
                            deleteAll()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Mementos")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            // Ensure index is valid on appear
            if currentIndex >= mementos.count {
                currentIndex = max(0, mementos.count - 1)
            }
        }
    }

    // MARK: - Actions

    private func add() {
        let newMemo = Memento()
        newMemo.text = ""
        newMemo.date = Date()
        context.insert(newMemo)
        try? context.save()
        // Jump to new entry
        if let newIndex = mementos.firstIndex(where: { $0.id == newMemo.id }) {
            currentIndex = newIndex
        }
    }

    private func deleteCurrent() {
        guard !mementos.isEmpty else { return }
        let memo = mementos[currentIndex]
        context.delete(memo)
        try? context.save()
        // Adjust index
        if currentIndex >= mementos.count {
            currentIndex = max(0, mementos.count - 1)
        }
    }

    private func deleteAll() {
        for memo in mementos {
            context.delete(memo)
        }
        try? context.save()
        currentIndex = 0
    }

    private func next() {
        if currentIndex < mementos.count - 1 {
            currentIndex += 1
        }
    }

    private func previous() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
}
