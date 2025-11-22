//
//  Problem Reporter.swift
//  SailTrips
//
//  Created by jeroen kok on 13/11/2025.
//
import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Problem Input View
struct ProblemInputView: View {
    var item: ChecklistItem?
    @Binding var observationText: String
    @Binding var images: [UIImage]
    var onComplete: ([Data], String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker = false
    @State private var pickerSourceType: UIImagePickerController.SourceType = .camera

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Description")) {
                    TextEditor(text: $observationText)
                        .frame(minHeight: 100)
                }
                Section(header: Text("Pictures")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Already-picked images
                            ForEach(images, id: \.self) { img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                            // “Add Photo” button
                            Button(action: addPhoto) {
                                VStack {
                                    Image(systemName: "camera")
                                        .font(.title2)
                                    Text("Add")
                                        .font(.footnote)
                                }
                                .frame(width: 80, height: 80)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Log a Problem")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let data = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
                        onComplete(data, observationText)
                        dismiss()
                    }
                    .disabled(observationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              && images.isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: pickerSourceType) { image in
                    images.append(image)
                    showImagePicker = false
                }
            }
        }
    }

    private func addPhoto() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            pickerSourceType = .camera
            showImagePicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    pickerSourceType = .camera
                    showImagePicker = true
                }
                // else: you might show an alert guiding the user to Settings
            }
        default:
            // permission denied – you could show an alert here
            break
        }
    }
}
