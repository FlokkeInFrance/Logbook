//
//  SailTripsApp.swift
//  SailTrips
//
//  Created by jeroen kok on 05/01/2025.
//

import SwiftUI
import SwiftData

@main
struct SailTripsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(        [BeaufortScale.self,
                                     Motor.self,
                                     Sail.self,
                                     Boat.self,
                                     Instances.self,
                                     CrewMember.self,
                                     Trip.self,
                                     Location.self,
                                     Cruise.self,
                                     Logs.self,
                                     BoatsLog.self,
                                     ChecklistItem.self,
                                     ChecklistHeader.self,
                                     ChecklistSection.self,
                                     Picture.self,
                                     ToService.self,
                                     MagVar.self,
                                     Memento.self,
                                     LogbookSettings.self] )
        let dataUrl = URL.applicationSupportDirectory.appending(path: "LogBookByJK.sqlite")
           print ("data model location : \(dataUrl)")
           let modelConfiguration = ModelConfiguration(
               schema: schema,
               url: dataUrl,
               allowsSave: true)

           do {
               return try ModelContainer(
                   for: schema,
                   migrationPlan: nil,
                   configurations: [modelConfiguration])
           } catch {
               fatalError("Could not create ModelContainer: \(error)")
           }
       }()

       var body: some Scene {
           WindowGroup {
               HomePage()
           }
           .modelContainer(sharedModelContainer)
       }
   }

