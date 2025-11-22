//
//  ACrewMember.swift
//  SailTrips
//
//  Created by jeroen kok on 16/02/2025.
//

import SwiftUI
import SwiftData
import PDFKit


struct ACrewMember: View {
    
    @Bindable var crewMember: CrewMember
    @Environment(\.dismiss) private var dismiss
    @State var isFileImporterPresented: Bool = false
    
    var body: some View {
        Button ("Done") {
            dismiss()
        }
        Form{
            //Text ("Details for \(crewMember.FirstName) \(crewMember.LastName)")
            TextField("Last Name",text: $crewMember.LastName).disableAutocorrection(true)
            TextField("First Name", text: $crewMember.FirstName).disableAutocorrection(true)
            DatePicker("Birthdate :", selection: $crewMember.DateOfBirth, in: ...Date(), displayedComponents: .date)
            LabeledContent {
                TextField("Address",text: $crewMember.Address).disableAutocorrection(true)} label: {Text ("Address")}
            HStack
            {
                LabeledContent {TextField("Postcode",text: $crewMember.PostCode).disableAutocorrection(true)} label: {Text ("Postcode")}
                LabeledContent {TextField("Town", text: $crewMember.Town).disableAutocorrection(true)} label: {Text ("Town")}
            }
           
            TextField("Region or State",text: $crewMember.RegionOrState).disableAutocorrection(true)
            TextField("Country",text: $crewMember.Country)
            TextField("Phone Number",text: $crewMember.PhoneNumber).disableAutocorrection(true)
            TextField("Relevant Medical Conditions",text: $crewMember.MedicalConditions)
            TextField("Allergies",text: $crewMember.Allergies)
            TextField("Medications",text: $crewMember.Medications).disableAutocorrection(true)
            TextField("Id or Pass Number",text: $crewMember.PassNumber).disableAutocorrection(true)
            TextField("Emergency Contact Name",text: $crewMember.EmergencyContactName).disableAutocorrection(true)
            TextField("Emergency Phone Number",text: $crewMember.EmergencyPhone).disableAutocorrection(true)
            TextField("Emergency Mail",text: $crewMember.EmergencyMail).disableAutocorrection(true)
            TextField("Emergency Adress",text: $crewMember.EmergencyAdress).disableAutocorrection(true)
            PDFThumbnailView(pdfData: crewMember.IdentityPDF,emptyString: "Put Copy of Id here")

            Button("Select PDF") {
                            isFileImporterPresented = true
                        }
                        .fileImporter(
                            isPresented: $isFileImporterPresented,
                            allowedContentTypes: [.pdf],
                            allowsMultipleSelection: false
                        ) { result in
                            do {
                                let selectedFile = try result.get().first
                                if let fileURL = selectedFile {
                                    crewMember.IdentityPDF = try Data(contentsOf: fileURL)
                                    //print("PDF loaded successfully")
                                }
                            } catch {
                                print("Error loading PDF: \(error)")
                            }
                        }// End of Button ie result
                    }// End of Form
        } //End of body View

}// end of struct
    


#Preview {
    /*
    ACrewMember(crewMember: cCrewMember())
     */
}
