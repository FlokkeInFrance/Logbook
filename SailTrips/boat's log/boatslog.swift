import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Picture Model Extensions
extension Picture {
    /// Convenience init from UIImage
    convenience init(uiImage: UIImage, compressionQuality: CGFloat = 0.8) {
        let jpeg = uiImage.jpegData(compressionQuality: compressionQuality) ?? Data()
        self.init(data: jpeg)
    }
    func uiImage() -> UIImage? { UIImage(data: data) }
}

// MARK: - List View for Boat's Logbook
struct BoatLogListView: View {
    @EnvironmentObject var navPath: PathManager
    let boat: Boat
    @Environment(\.modelContext) private var context

    @State private var startDate: Date? = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date())
    @State private var endDate: Date? = Date()

    @Query private var allLogs: [BoatsLog]

    private var filteredLogs: [BoatsLog] {
        allLogs
            .filter { $0.boat?.id == boat.id }
            .filter { log in
                if let s = startDate, let e = endDate {
                    return log.dateOfEntry >= s && log.dateOfEntry <= e
                } else if let s = startDate {
                    return log.dateOfEntry >= s
                } else if let e = endDate {
                    return log.dateOfEntry <= e
                } else {
                    return true
                }
            }
            .sorted { $0.dateOfEntry > $1.dateOfEntry }
    }

    enum Destination: Hashable {
        case detail(BoatsLog, isNew: Bool)
    }

    // Bindings to handle optional dates
    private var startBinding: Binding<Date> {
        Binding(get: { startDate ?? Date() }, set: { startDate = $0 })
    }
    private var endBinding: Binding<Date> {
        Binding(get: { endDate ?? Date() }, set: { endDate = $0 })
    }

    var body: some View {
       // NavigationStack(path: $navPath.path) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(boat.name)’s logbook")
                    .font(.title2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Shortcut.allCases, id: \.self) { sc in
                            Button(sc.title) { apply(sc) }
                                .buttonStyle(.bordered)
                        }
                    }
                }

                HStack {
                    DatePicker("From", selection: startBinding, displayedComponents: .date)
                    DatePicker("To", selection: endBinding, displayedComponents: .date)
                }

                List(filteredLogs) { log in
                    HStack {
                        Text(log.dateOfEntry, style: .date)
                            .frame(width: 100, alignment: .leading)
                        Text(log.entryText)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        navPath.path.append(Destination.detail(log, isNew: false))
                    }
                }

                HStack {
                    Button("Add") {
                        let newLog = BoatsLog()
                        newLog.boat = boat
                        context.insert(newLog)
                        try? context.save()
                        navPath.path.append(Destination.detail(newLog, isNew: true))
                    }
                    Spacer()
                    Button("Delete") {
                        if let today = filteredLogs.first,
                           Calendar.current.isDateInToday(today.dateOfEntry) {
                            context.delete(today)
                            try? context.save()
                        }
                    }
                    .disabled(!filteredLogs.contains { Calendar.current.isDateInToday($0.dateOfEntry) })
                    Spacer()
                    Button("PDF") { generatePDF() }
                }
                .padding(.top)
            }
            .padding()
            .navigationDestination(for: Destination.self) { dest in
                if case let .detail(log, isNew) = dest {
                    BoatLogDetailView(log: log, isNew: isNew)
                }
            }
        //}
       .onAppear {
            if filteredLogs.isEmpty {
                apply(.last4Weeks)
                if filteredLogs.isEmpty { apply(.currentYear) }
                if filteredLogs.isEmpty { apply(.all) }
            }
        }
    }

    private enum Shortcut: CaseIterable {
        case last7Days, last4Weeks, previousMonth, currentYear, lastYear, all
        var title: String {
            switch self {
            case .last7Days: return "Last 7 Days"
            case .last4Weeks: return "Last 4 Weeks"
            case .previousMonth: return "Previous Month"
            case .currentYear: return "Current Year"
            case .lastYear: return "Last Year"
            case .all: return "All"
            }
        }
    }

    private func apply(_ sc: Shortcut) {
        let cal = Calendar.current
        let now = Date()
        switch sc {
        case .last7Days:
            startDate = cal.date(byAdding: .day, value: -7, to: now)
            endDate = now
        case .last4Weeks:
            startDate = cal.date(byAdding: .weekOfYear, value: -4, to: now)
            endDate = now
        case .previousMonth:
            if let start = cal.date(byAdding: .month, value: -1, to: now),
               let end = cal.date(byAdding: .day, value: -1, to: now) {
                startDate = start
                endDate = end
            }
        case .currentYear:
            if let start = cal.date(from: DateComponents(year: cal.component(.year, from: now))) {
                startDate = start
                endDate = now
            }
        case .lastYear:
            let year = cal.component(.year, from: now) - 1
            if let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
               let end = cal.date(from: DateComponents(year: year, month: 12, day: 31)) {
                startDate = start
                endDate = end
            }
        case .all:
            startDate = nil
            endDate = nil
        }
    }

    private func generatePDF() {
        let pdfFileName = "\(boat.name)'s log.pdf"
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsURL.appendingPathComponent(pdfFileName)

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 size in points
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: fileURL) { context in
                context.beginPage()

                // Draw Title
                let title = "\(boat.name)'s Logbook"
                let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
                let titleSize = title.size(withAttributes: titleAttributes)
                let titlePoint = CGPoint(x: (pageRect.width - titleSize.width) / 2, y: 20)
                title.draw(at: titlePoint, withAttributes: titleAttributes)

                // Draw Subtitle
                let subtitle = "From \(startDate!.formatted(date: .long, time: .omitted)) to \(endDate!.formatted(date: .long, time: .omitted))"
                let subtitleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14)]
                let subtitlePoint = CGPoint(x: 20, y: titlePoint.y + titleSize.height + 10)
                subtitle.draw(at: subtitlePoint, withAttributes: subtitleAttributes)

                var currentY = subtitlePoint.y + 30
                let textAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
                let formatter = DateFormatter()
                formatter.dateStyle = .short

                for log in filteredLogs {
                    let entryText = "\(formatter.string(from: log.dateOfEntry)): \(log.entryText)"
                    let textRect = CGRect(x: 20, y: currentY, width: pageRect.width - 40, height: .infinity)
                    let textHeight = entryText.boundingRect(
                        with: CGSize(width: textRect.width, height: .infinity),
                        options: .usesLineFragmentOrigin,
                        attributes: textAttributes,
                        context: nil
                    ).height
                    entryText.draw(
                        with: CGRect(x: textRect.minX, y: currentY, width: textRect.width, height: textHeight),
                        options: .usesLineFragmentOrigin,
                        attributes: textAttributes,
                        context: nil
                    )
                    currentY += textHeight + 5

                    // Draw pictures
                    for pic in log.pictures {
                        if let uiImage = pic.uiImage() {
                            let maxDim: CGFloat = 100
                            let aspect = uiImage.size.width / uiImage.size.height
                            let imgWidth = aspect > 1 ? maxDim : maxDim * aspect
                            let imgHeight = aspect > 1 ? maxDim / aspect : maxDim
                            let imgRect = CGRect(x: 20, y: currentY, width: imgWidth, height: imgHeight)
                            uiImage.draw(in: imgRect)
                            currentY += imgHeight + 10
                        }
                    }

                    // New page if needed
                    if currentY > pageRect.height - 100 {
                        context.beginPage()
                        currentY = 20
                    }
                }

                // Footer
                let footer = "End of \(boat.name)'s Log"
                let footerAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: 14)]
                let footerSize = footer.size(withAttributes: footerAttributes)
                let footerPoint = CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - footerSize.height - 20)
                footer.draw(at: footerPoint, withAttributes: footerAttributes)
            }
            print("PDF saved to: \(fileURL)")
        } catch {
            print("Failed to create PDF: \(error)")
        }
    }
}

// MARK: - Detail View for a single log entry
struct BoatLogDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var log: BoatsLog
    let isNew: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showFullImage: UIImage? = nil

    init(log: BoatsLog, isNew: Bool) {
        _log = State(initialValue: log)
        self.isNew = isNew
    }

    var canEdit: Bool { isNew || Calendar.current.isDateInToday(log.dateOfEntry) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(log.dateOfEntry, style: .date)
                    .font(.headline)

                if canEdit {
                    TextEditor(text: $log.entryText)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke())
                } else {
                    Text(log.entryText)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                    ForEach(Array(log.pictures.enumerated()), id: \.offset) { idx, pic in
                        if let ui = pic.uiImage() {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .onTapGesture { showFullImage = ui }
                                .contextMenu {
                                    if canEdit {
                                        Button(role: .destructive) {
                                            log.pictures.remove(at: idx)
                                            try? context.save()
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                }

                if canEdit {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("Add Photo", systemImage: "camera")
                    }
                    .onChange(of: selectedPhotoItem) { _, _ in
                        Task {
                            if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                               let ui = UIImage(data: data) {
                                let pic = Picture(uiImage: ui)
                                log.pictures.append(pic)
                                try? context.save()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Log Entry")
        .fullScreenCover(
            isPresented: Binding(
                get: { showFullImage != nil },
                set: { if !$0 { showFullImage = nil } }
            )
        ) {
            if let ui = showFullImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .onTapGesture { showFullImage = nil }
            }
        }
        .onDisappear {
            if canEdit { try? context.save() }
        }
    }
}

