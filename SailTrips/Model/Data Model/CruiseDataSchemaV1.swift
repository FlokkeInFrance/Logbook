//
//  CruiseDataSchemaV1.swift
//  SailTrips
//
//  Created by jeroen kok on 05/01/2025.
//

import SwiftUI
import SwiftData

enum CruiseDataSchemaV1: VersionedSchema {
    
    static var versionIdentifier = Schema.Version(1,0,0)
    
    static var models: [any PersistentModel.Type] {
        [BeaufortScale.self,
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
         LogbookSettings.self,
         InventoryItem.self] }
    
    @Model
    final class BeaufortScale {
        @Attribute(.unique) private(set) var id: UUID
        var beaufortScaleInt: Int
        var windVelocityLow: Int    // lower‐limit (m/s) for this Beaufort number
        var windName: String
        var seaState: String

        init(id: UUID = .init(),
             beaufortScaleInt: Int,
             windVelocityLow: Int = 0,
             windName: String="",
             seaState: String="")
        {
            self.id = id
            self.beaufortScaleInt = beaufortScaleInt
            self.windVelocityLow = windVelocityLow
            self.windName = windName
            self.seaState = seaState
        }

        /// A “complete set” of official Beaufort defaults.
        private static let officialDefinitions: [Int:(windVelocityLow: Int, windName: String, seaState: String)] = [
            // Beaufort 0
            0: (windVelocityLow: 0,
                windName:   "Calm",
                seaState:   "Sea like a mirror"),
            // Beaufort 1
            1: (windVelocityLow: 1,
                windName:   "Light Air",
                seaState:   "Ripples with appearance of scales"),
            // Beaufort 2
            2: (windVelocityLow: 4,
                windName:   "Light Breeze",
                seaState:   "Small wavelets, crests glassy"),
            // Beaufort 3
            3: (windVelocityLow: 7,
                windName:   "Gentle Breeze",
                seaState:   "Large wavelets, crests begin to break"),
            // Beaufort 4
            4: (windVelocityLow: 11,
                windName:   "Moderate Breeze",
                seaState:   "Small waves, becoming longer"),
            // Beaufort 5
            5: (windVelocityLow: 17,
                windName:   "Fresh Breeze",
                seaState:   "Moderate waves, some whitecaps"),
            // Beaufort 6
            6: (windVelocityLow: 22,
                windName:   "Strong Breeze",
                seaState:   "Large waves begin to form, foam crests"),
            // Beaufort 7
            7: (windVelocityLow: 28,
                windName:   "Moderate Gale",
                seaState:   "Sea heaps up, white foam from breaking waves"),
            // Beaufort 8
            8: (windVelocityLow: 34,
                windName:   "Fresh Gale",
                seaState:   "Moderately high waves of greater length"),
            // Beaufort 9
            9: (windVelocityLow: 41,
                windName:   "Strong Gale",
                seaState:   "High waves; dense streaks of foam"),
            // Beaufort 10
            10: (windVelocityLow: 48,
                 windName:   "Storm",
                 seaState:   "Very high waves with overhanging crests"),
            // Beaufort 11
            11: (windVelocityLow: 56,
                 windName:   "Violent Storm",
                 seaState:   "Exceptionally high waves; sea covered with white foam patches"),
            12:(windVelocityLow: 64,
                windName:   "Hurricane",
                seaState:   "The air is filled with foam and spray. Sea completely white with driving spray; visibility very seriously affected.")
        ]

        /// Validates a given array of BeaufortScale objects so that at least
        /// Beaufort 0…11 are present. If any integer in that range is missing,
        /// the function returns new BeaufortScale instances for each missing index.
        ///
        /// - Parameter existing: The array of scales you already have (e.g. fetched from DB).
        /// - Returns: A new array containing all existing items plus any newly created defaults
        ///            for missing Beaufort numbers. The caller can then re‐save or re‐use this list.
        static func validatedScales(from existing: [BeaufortScale]) -> [BeaufortScale] {
            // 1) Index existing by beaufortScaleInt
            var seen: [Int: BeaufortScale] = [:]
            for scale in existing {
                seen[scale.beaufortScaleInt] = scale
            }

            // 2) Walk through all required keys (0…11). If a key is absent, create a default.
            var output: [BeaufortScale] = []
            for i in 0...12 {
                if let already = seen[i] {
                    output.append(already)
                } else if let defs = officialDefinitions[i] {
                    // create a “missing” BeaufortScale with defaults
                    let newScale = BeaufortScale(
                        id: UUID(),
                        beaufortScaleInt: i,
                        windVelocityLow: defs.windVelocityLow,
                        windName: defs.windName,
                        seaState: defs.seaState
                    )
                    output.append(newScale)
                    
                } else {
                    // This should never happen if your dictionary is complete,
                    // but you could log or fill with placeholders.
                    let placeholder = BeaufortScale(
                        id: UUID(),
                        beaufortScaleInt: i,
                        windVelocityLow: 0,
                        windName: "Unknown",
                        seaState: "Unknown"
                    )
                    output.append(placeholder)
                }
            }

            // 3) If you had extra entries (e.g. duplicate beaufortScaleInt or > 11),
            //    you can either ignore them or append them at the end. Here we just
            //    discard duplicates and out‐of-range.
            return output
        }
    }

    @Model
    final class Sail  {
        @Attribute(.unique) private(set) var id: UUID
        var nameOfSail : String = ""
        var optional : Bool = false
        var reducedWithReefs : Bool = true
        var reducedWithFurling : Bool = false
        var canBeOutpoled : Bool = false
        var sailArea : Float = 0.0 //total useful surface of the sail
        var currentState : SailState = SailState.down
        var preventer : Bool = false
        var outpoled : Bool = false
        init(id: UUID, nameOfSail: String, reducedWithReefs: Bool, reducedwithFurling: Bool,  currentState: SailState) {
            self.id = id
            self.nameOfSail = nameOfSail
            self.reducedWithReefs = reducedWithReefs
            //self.reducedWithFurling = reducedWithFurling
            self.currentState = currentState
        }
    }
    
    @Model
    final class Motor {
        @Attribute(.unique) private(set) var id: UUID
        var name: String = ""
        var inboard: Bool = true
        var use: MotorUse = MotorUse.inboard
        var energy: MotorEnergy = MotorEnergy.diesel
        var motorBrand: String = ""
        var motorType: String = ""
        var motorPower: String = ""
        var state: MotorState = MotorState.stopped // Current operating state of this motor.
        //digit+unity
        init(id: UUID) {
            self.id = id
        }
    }

    @Model
    final class Boat {
        //internal
        @Attribute(.unique) private(set) var id: UUID
        var instances: Instances?
        var name: String
        var boatType: PropulsionType
        var rigType: BoatType = BoatType.sloop
        var otherType: String = ""
        var status: BoatStatus = BoatStatus.selected
        //indentification
        var hullNumber: String = ""
        var brand: String = ""
        var modelType: String = ""
        var hullColor: String = ""
        //equipment
        var motors: [Motor] = []
        var sails: [Sail] = []
        @Relationship(deleteRule: .cascade) var inventory: [InventoryItem] = []
        var extraRiggingItems: [InventoryItem] {
            inventory.filter { $0.type == .extraRigging }
        }
        //radio
        var callsign: String = ""
        var MMSI: String = ""
        var hasEpirb: Bool = false
        //admin
        var owner: String = ""
        var registrationNumber: String = ""
        var dateOfRegistration: Date = Date()
        var navCategory: String = ""
        var insuranceNumber: String = ""
        var insuranceCompany: String = ""
        var insurancePhoneNumber: String = ""
        var insuranceLink: String = ""
        var usualPort: String = ""
        //dimensions
        var length: Float = 0
        var beam: Float = 0
        var draft: Float = 0
        var airDraft: Float = 0
        var lengthOverall: Float = 0
        var weight: Float = 0
        //Network
        var wifiAxiomIP: String = ""
        var wifiAxiomPort: String = ""
        var wifiNMEAIP: String = ""
        var wifiNMEAPort: String = ""
        var wifiNMEAPW: String = ""
        
        @Attribute(.externalStorage) var RegistrationPDF: Data? //will be nice to have those in the app
        @Attribute(.externalStorage) var InsurancePDF: Data?
        
        init(id: UUID=UUID(),name: String="",boatType: PropulsionType)
        {
            self.id = id
            self.name = name
            self.boatType = boatType
        }
    }
    

    
    @Model
    final class CrewMember {
        @Attribute(.unique) private(set) var  id: UUID
        var LastName: String
        var FirstName: String
        var DateOfBirth: Date = Date()
        var Address: String = ""
        var PostCode: String = ""
        var Town: String = ""
        var RegionOrState: String = ""
        var Country: String = ""
        var PhoneNumber: String = ""
        var MedicalConditions: String = ""
        var Allergies: String = ""
        var Medications: String = ""
        var PassNumber: String = ""
        var EmergencyContactName: String = ""
        var EmergencyPhone: String = ""
        var EmergencyMail: String = ""
        var EmergencyAdress: String = ""
        @Attribute(.externalStorage) var IdentityPDF: Data?
         
        init(id: UUID=UUID(), lastName: String, firstName: String) {
            self.id = id
            self.LastName = lastName
            self.FirstName = firstName
        }
    }
    
    @Model
    final class Location {
        @Attribute(.unique) private(set) var  id: UUID
        var Name: String
        var Latitude: Double
        var Longitude: Double
        var typeOfLocation: TypeOfLocation=TypeOfLocation.pOI
        var LastDateVisited: Date?
        
        //contactInfo
        var contactName: String=""
        var contactPhone: String=""
        var vhfContact: String="09"
        var emailContact: String=""
        
        //postalAdress
        var address: String=""
        var cP: String=""
        var town: String=""
        var country: String=""
        var region: String=""
        
        //procedures
        var arrivalProcedures: String=""
        var departureProcedures: String=""
        
        //general Info
        var observations: String=""
        var picture: [Picture] = []
        
        init(id: UUID=UUID(), name: String, latitude: Double, longitude: Double) {
            self.id = id
            self.Name = name
            self.Latitude = latitude
            self.Longitude = longitude
        }
    }
    
    @Model
    final class Landmark{
        @Attribute(.unique) private(set) var id: UUID
        var Name: String=""
        var Latitude: Double=0
        var Longitude: Double=0
        var RangeOfVisibility: Double=20 //given in nautical miles nm
        var LandmarkType: LandmarkCategory=LandmarkCategory.lighthouse
        init (id: UUID=UUID()){
            self.id = id
        }
    }
    
    @Model
    final class Cruise {
        @Attribute(.unique) private(set) var id: UUID
        var Title: String="From..To.."
        var Departure: String=""
        var DateOfStart: Date=Date()
        var DateOfArrival: Date?
        var Crew: [CrewMember]=[]
        var Boat: Boat?
        var CruiseType: TypeOfCruise=TypeOfCruise.round
        var status: CruiseStatus=CruiseStatus.planned
        var basin: String=""
        var legs: [Location]=[]
        
        init (id: UUID=UUID()){
            self.id = id
        }
    }
    
    @Model
    final class Trip {
        @Attribute(.unique) private(set) var id: UUID
        var tripType: TypeOfTrip=TypeOfTrip.roundTrip
        var boat: Boat?
        var dateOfStart: Date=Date()
        var dateOfEnd: Date=Date()
        var tripStatus: TripStatus=TripStatus.preparing
        var cruise: Cruise?
        var crew: [CrewMember]=[]
        var skipper: CrewMember?
        var startPlace: Location?
        var destination: Location?
        var plannedRoute: [Location]=[]
        var comments: String=""
        var phoneToContact: String=""
        var vhfChannelDestination: String=""
        var personAtDestination: String=""
        var weatherAtStart: String=""
        var baroAtStart: Float=0.0
        var weatherForecast: String=""
        var noticesToMariner: String=""
        var tidalInformation: String=""
        var waterLevelAtStart : Float=0.0
        var fuelLevelAtStart : Float=0.0
        var batteryLevelAtStart : Float=0.0
        
        init (id: UUID=UUID()){
            self.id = id
        }
    }
    
    @Model
    final class Instances {
        @Attribute(.unique) private(set) var id: UUID
        var selectedBoat: Boat
        //boat state
        var fuelLevel : Int = 100 //in %
        var waterLevel : Int = 100 //in %
        var batteryLevel : Int = 100 //in %
        var motorHours : Float = 10.0
        var odometerGeneral : Float = 0.0
        var rigUsed: [InventoryItem] = []
        //Trip (logged at start or end)
        var currentCruise : Cruise?
        var currentTrip : Trip?
        var odometerForTrip : Float = 0.0
        var odometerForCruise : Float = 0.0
        var dateOfStart : Date = Date () //with time
        var tripDays : Int = 0
        var startLocationLong : Double = 0.0
        var startLocationLat : Double = 0.0
        //sequence
        var mooringUsed : MooringType = MooringType.mooredOnShore
        var navStatus : NavStatus = NavStatus.stopped
        var currentNavZone : NavZone = NavZone.harbour
        var propulsion : PropulsionTool = PropulsionTool.none
  
        //navigation
        var gpsCoordinatesLat : Double = 0.0
        var gpsCoordinatesLong : Double = 0.0
        var onCourse : Bool = true
        var nextWPT : Location?
        var currentLocation : Location?
        var lastNavigationTimeStamp : Date = Date()
        var lastWPT : Location?
        var COG : Int = 0
        var bearingToNextWPT : Int = 0
        var magHeading : Int = 0
        var SOG : Float = 0.0
        //Sail parameters
        var tack : Tack = Tack.none
        var pointOfSail : PointOfSail = PointOfSail.stopped
        var STW : Float = 0.0 //speed through water, needs loch to be clean
        var AWS : Int = 0 //apparent wind speed
        var AWA : Int = 0 //apparent wind angle (with regard to the boat,cannot exceed 180°, neg is port)
        var TWA : Int = 0 //true wind angle (with regard to the boat, cannot exceed 180°, neg is port)
        var AWD : Int = 0 //apparent wind direction, cardinal direction 0-359
        var wingOnWing = Bool(false)
        //Dynamics
        var heel : Float = 0.0
        var comfortOnBoard : String = ""
        //Controls
        var steering : Steering = Steering.byHand
        var autopilotMode : Autopilot = Autopilot.off
        var autopilotDirection : Int = 0 //AWA,TWA, magnetic heading, GPS WP or COG
        //environment weather sky
        var daySail: Bool = true
        var weatherTimestamp : Date = Date()
        var TWS : Int = 0
        var TWD : Int = 0 //true wind direction, cardinal direction 0-359
        var windDescription : Int = 0 //Beaufort
        var turbulence : Int = 0
        var gustiness : Int = 0
        var pressure : Float = 0.0
        var visibility : String = ""
        var cloudiness : Int = 0 // integers from 0 (no clouds) to 8 (overcast)
        var stateOfSky : String = "clear"
        var presenceOfCn : Bool = false
        var precipitations : Precipitations = Precipitations.none
        var airTemperature : Int = 15
        var waterTemperature : Int = 15
        var severeWeather : SevereWeather = SevereWeather.none
        //Sea State
        var seaState : String = ""
        var currentSpeed : Float = 0.0
        var currentDirection : Int = 0
        var nextHT : Date?
        var nextLT : Date?
        var next2HT : Date?
        var next2LT : Date?
        //environment traffic
        var trafficDescription : String = ""
        //environement other dangers
        var environmentDangers: [EnvironmentDangers] = [EnvironmentDangers.none]
        //emergency states
        var emergencyState : Bool = false
        var emergencyLevel : EmergencyLevel = EmergencyLevel.none
        var emergencyNature : Emergencies = Emergencies.none
        var emergencyStart : Date?
        var emergencyEnd : Date?
        var emergencyDescription : String = ""
        
        init(boat: Boat){
            self.id = UUID()
            self.selectedBoat = boat
        }
    }
    
    @Model
    final class Logs {
        @Attribute(.unique) private(set) var id: UUID
        var logEntry: String = ""
        var trip: Trip
        var dateOfLog: Date=Date.now
        var posLat: Double=0.0
        var posLong: Double=0.0
        // Nav Info
        var nextWaypoint: String = ""
        var distanceToWP: Float = 0.0
        var SOG: Float = 0.0
        var COG: Int = 0
        var magHeading: Int = 0 //direct read from compass
        var STW: Float = 0.0
        var distanceSinceLastEntry: Float = 0.0
        var averageSpeedSinceLastEntry: Float = 0.0
        //tide and current
        var timeHighTide: Float = 0.0
        var speedOfCurrent: Float = 0.0
        var directionOfCurrent: Float = 0.0
        // WeatherInfo
        var pressure: Float=0.0
        var TWS: Int = 0
        var TWD: Int = 0
        var windGust: Float = 0.0
        var windForce: Int = 0
        var airTemp: Int=0
        var waterTemp: Int=0
        var seaState: String = ""
        var cloudCover: String = ""
        var precipitation: Precipitations = Precipitations.none
        var severeWeather: SevereWeather = SevereWeather.none
        var visibility: String = ""
        // EnvironmentInfo
        // Sail info
        var AWA: Int=0
        var AWS: Int=0
        var pointOfSail: String = ""
        var tack: Tack = Tack.none
        var propulsion: PropulsionTool = PropulsionTool.none
        var steering: Steering = Steering.byHand
        init (id: UUID=UUID(), trip: Trip){
            self.id = id
            self.trip = trip
        }
    }
    
    @Model
    final class Picture {
        @Attribute(.unique) var id: UUID
        
        @Attribute(.externalStorage) var data: Data

        init(id: UUID = .init(), data: Data) {
            self.id = id
            self.data = data
        }
    }

    @Model
    final class ToService {
        @Attribute(.unique) private(set) var id: UUID
        var boat: Boat
        var dateOfEntry: Date=Date.now
        var observation: String = ""
        var actiontoTake: String = ""
        var fixed: Bool = false
        var dateFixed: Date = Date()
        var parts: String = ""
        var suppliers: String = ""
        var cost: Double = 0
        var correctiveAction: String = ""
        @Relationship(deleteRule: .cascade) var pictures: [Picture] = []

        init(id: UUID = .init(), boat: Boat) {
            self.id = id
            self.boat = boat
        }
    }
    
    @Model
    final class ChecklistHeader {
        @Attribute(.unique) private(set) var id: UUID
        var boat: Boat
        var forAllBoats: Bool = false
        var name: String = ""
        @Relationship(deleteRule: .cascade) var sections: [ChecklistSection] = []
        var emergencyCL: Bool = false //false=normal, true= emergency
        var alwaysShow: Bool = true
        var conditionalShow: NavStatus = NavStatus.none
        var canBeLogged: Bool = true
        var latestRunDate: Date = Date()
        var wait24Hours: Bool = true
        var aborted: Bool = false
        var completed: Bool = false
        
        init (id: UUID=UUID(),boat: Boat){
            self.id = id
            self.boat = boat
        }
    }
    
    @Model
    final class ChecklistSection {
        @Attribute(.unique) private(set) var id: UUID
        var orderNum: Int
        var nameOfSection: String = ""
        var header: ChecklistHeader
        var fontColor: SectionColors = SectionColors.blue
       @Relationship(deleteRule: .cascade) var items: [ChecklistItem] = []
        init (orderNum: Int, header: ChecklistHeader){
            self.id = UUID()
            self.orderNum = orderNum
            self.header = header
        }
    }
    
    @Model
    final class ChecklistItem {
        @Attribute(.unique) private(set) var id: UUID
        var itemNumber: Int
        var itemShortText: String = ""
        var itemLongText: String = ""
        var itemNormalCheck: Bool = true // true : normal check, false : Alt1/Alt2,
        var textAlt1: String = ""
        var textAlt2: String = ""
        var choiceAlt1: Bool = true
        var checklistSection: ChecklistSection
        var altCheckList : ChecklistHeader?
        var checked : Bool = false
        var problem : Bool = false
        
        init (itemNumber: Int, checklistSection: ChecklistSection,id: UUID=UUID()){
            self.id = id
            self.itemNumber = itemNumber
            self.checklistSection = checklistSection
        }
    }
    
    @Model
    final class BoatsLog {
        @Attribute(.unique) private(set) var id: UUID
        var boat: Boat?
        var dateOfEntry : Date = Date.now
        var entryText : String = ""
        var picture : [Picture] = [] //a jpg or HEIF of issue
        init (id: UUID=UUID()){
            self.id = id
        }
    }
    
    @Model
    final class MagVar{
        @Attribute(.unique) private(set) var id: UUID
        var boat: Boat?
        var realHeading: Double = 0.0
        var observedHeading: Double = 0.0
        var magneticVariation: Double = 0.0
        var computedDeviation: Double = 0.0
        init (id: UUID=UUID()){
            self.id = id
        }
    }
    
    @Model
    final class Memento{
        @Attribute(.unique) private(set) var id: UUID
        var text: String = ""
        var date: Date = Date.now
        init (id: UUID=UUID()){
            self.id = id
        }
    }
    
    @Model
    final class InventoryItem {
        @Attribute(.unique) private(set) var id: UUID
        var boat: Boat?

        var name: String              // “Walder”, “Removable forestay”, “Spare halyard”
        var category: InventoryCategory
        var subcategory: String       // free text or an enum later
        var type: InventoryType       // “extra rigging”, “safety”, “tools”, …

        var dateOfEntry: Date
        var dateOfReplacement: Date?
        var storageSite: String       // “Forepeak locker”, “Starboard cockpit locker”

        /// Should usage of this item be tracked in the logbook?
        var tracksUsageInLogbook: Bool = false

        /// Optional link back to your enum for canonical items.
        var extraRiggingKind: ExtraRigging?
        var quantity: Int = 0
        var brand: String = ""
        var retailer: String = ""
        var checkPeriodicity: Int = 0
        var nextCheck: Date = Date()

        init(
            id: UUID = UUID(),
            boat: Boat? = nil,
            name: String,
            category: InventoryCategory,
            subcategory: String = "",
            type: InventoryType,
            dateOfEntry: Date = .now,
            dateOfReplacement: Date? = nil,
            storageSite: String = "",
            tracksUsageInLogbook: Bool = false,
            extraRiggingKind: ExtraRigging? = nil
        ) {
            self.id = id
            self.boat = boat
            self.name = name
            self.category = category
            self.subcategory = subcategory
            self.type = type
            self.dateOfEntry = dateOfEntry
            self.dateOfReplacement = dateOfReplacement
            self.storageSite = storageSite
            self.tracksUsageInLogbook = tracksUsageInLogbook
            self.extraRiggingKind = extraRiggingKind
        }
    }


    
    @Model
    final class LogbookSettings {
      @Attribute(.unique) private(set) var id: UUID
      // unit preferences
      var distanceUnit: DistanceUnit = DistanceUnit.nautical
      var speedUnit: SpeedUnit = SpeedUnit.knots
      var sizeUnit: SizeUnit = SizeUnit.meters
      var weightUnit: WeightUnit = WeightUnit.kilo
      var volumeUnit: VolumeUnit = VolumeUnit.liters
      var pressureUnit: PressureUnit = PressureUnit.hPa
      var autoReadposition: Bool = true
      var autoUpdatePosition: Bool = false
      var autoUpdatePeriodicity: Int = 60
      var trueWindSpeedFromSOW: Bool = true
      var readNMEA2000: Bool = true
        

      // which fields to _hide_ or _show_ (we’ll store the hidden set)

      var hiddenLogFields: [LogField] = []

      var hiddenInstanceFields: [InstanceField] = []

      init(id: UUID = .init()) {
        self.id = id
      }

      // helpers for UI binding
      func isLogFieldVisible(_ f: LogField) -> Bool {
        !hiddenLogFields.contains(f)
      }
      func setLogField(_ f: LogField, visible: Bool) {
        if visible {if let index = hiddenLogFields.firstIndex(of: f) {
            hiddenLogFields.remove(at: index)
         }
            }
          else       { hiddenLogFields.insert(f, at: 0) }
      }
        
        func isInstanceFieldVisible(_ f: InstanceField) -> Bool {
          !hiddenInstanceFields.contains(f)
        }
        func setInstanceField(_ f: InstanceField, visible: Bool) {
          if visible {if let index = hiddenInstanceFields.firstIndex(of: f) {
              hiddenInstanceFields.remove(at: index)
           }
              }
            else       { hiddenInstanceFields.insert(f, at: 0) }
        }
    }
}



