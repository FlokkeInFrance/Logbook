//
//  Untitled.swift
//  SailTrips
//
//  Created by jeroen kok on 13/07/2025.
//

enum DistanceUnit: String, Codable, CaseIterable, Sendable {
  case metric, imperial, nautical
}
enum SpeedUnit: String, Codable, CaseIterable, Sendable {
  case kmh, mps, knots, mph
}
enum SizeUnit: String, Codable, CaseIterable, Sendable {
  case meters, feet
    var shortLabel: String {
        switch self {
        case .meters:  return "m"
        case .feet:    return "ft"
            
        }
    }
}
enum WeightUnit: String, Codable, CaseIterable, Sendable {
  case kilo, pound
    var shortLabel: String {
        switch self {
        case .kilo:    return "kg"
        case .pound: return "lb"
            
        }
    }
}
enum VolumeUnit: String, Codable, CaseIterable, Sendable {
  case liters, gallonsUS, gallonsUK
    var shortLabel: String {
        switch self {
        case .liters:   return "L"
        case .gallonsUS:return "gal"
        case .gallonsUK:return "gal"
        }
    }
}
enum PressureUnit: String, Codable, CaseIterable, Sendable {
  case mmHg, inchHg, mbar, hPa
}
enum TrueWindReference: String, Codable, CaseIterable {
    case water
    case ground
}


enum LogField: String, Codable, CaseIterable, Sendable, Identifiable {
    // Nav Info
    case nextWaypoint
    case distanceToWP
    case SOG
    case COG
    case magCourse
    case SOW
    case distanceSinceLastEntry
    case averageSpeedSinceLastEntry
    //tide and current
    case timeHighTide
    case speedOfCurrent
    case directionOfCurrent
    // WeatherInfo
    case pressure
    case TWS
    case TWD
    case windGust
    case windForce
    case airTemp
    case waterTemp
    case seaState
    case cloudCover
    case precipitation
    case severeWeather
    case visibility
    // EnvironmentInfo
    // Sail info
    case AWA
    case AWS
    case pointOfSail
    case tack
    case propulsion
    case steering
    var id: Self { self }
}

enum InstanceField: String, Codable, CaseIterable, Sendable, Identifiable {
    //boat state
    case fuelLevel
    case waterLevel
    case batteryLevel
    case motorHours
    //sequence

    case mooringUsed
    case currentNavZone
    case propulsion
    case odometerGeneral
    case rigUsed
    case odometerForTrip
    case odometerForCruise
    case dateOfStart
    case startLocationLong
    case startLocationLat
    //navigation
    case gpsCoordinatesLat
    case gpsCoordinatesLong
    case onCourse
    case nextWPT
    case currentLocation
    case lastNavigationTimeStamp
    case lastWPT
    case courseOverGround
    case bearingToNextWPT
    case SOG
    //sailing dynamics
    case tack
    case pointOfSail
    case STW
    case AWS
    case AWA
    case TWA
    case AWD
    case heel
    case comfortOnBoard
    case steering
    case autpilotDirection
    case autopilotMode
    //environment weather
    case daySail
    case weatherTimeStamp
    case TWS
    case TWD
    case windDescription
    case turbulence
    case gustiness
    case seaState
    case pressure
    case visibility
    case cloudiness
    case stateOfSky
    case presenceOfCn
    case precipitations
    case airTemperature
    case waterTemperature
    case severeWeather
    //environment trafic
    case trafficDesription
    //environement other dangers
    case environmentDangers
    case currentSpeed
    case currentDirection
    case nextHT
    case nextLT
    case next2HT
    case next2LT
    var id: Self { self }
  
}
