//
//  Situation ID.swift
//  SailTrips
//
//  Created by jeroen kok on 29/11/2025.
//

enum SituationID: String, CaseIterable, Identifiable, Codable {
    case s1PreparingTrip        = "S1"
    case s2TripStarted          = "S2"
    case s3InHarbourArea        = "S3"

    case s41CoastalMotor        = "S41"
    case s42ProtectedMotor      = "S42"
    case s43WaterwayMotor       = "S43"
    case s44OpenSeaMotor        = "S44"

    case s51CoastalSail         = "S51"
    case s52ProtectedSail       = "S52"
    case s53WaterwaySail        = "S53"
    case s54OpenSeaSail         = "S54"

    case s51wCoastalSailStrong  = "S51w"
    case s52wProtectedSailStrong = "S52w"
    case s53wWaterwaySailStrong = "S53w"
    case s54wOpenSeaSailStrong  = "S54w"

    case s6ApproachMotor        = "S6"
    case s6sApproachSail        = "S6s"
    case s7HarbourLikeS3        = "S7"
    case s8Storm                = "S8"
    case s9DangerSpotLightWind  = "S9"
    case s9wDangerSpotStrongWind = "S9w"

    // Emergency "situations" for layout:
    case e1MOB                  = "E1"
    case e2Fire                 = "E2"
    case e3Medical              = "E3"
    case e4OtherEmergency       = "E4"

    var id: String { rawValue }
}
