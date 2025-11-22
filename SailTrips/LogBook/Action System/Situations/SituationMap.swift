//
//  ActionRegistry+Situation.swift
//  SailTrips
//
//  Created by jeroen kok on 29/11/2025.
//

extension ActionRegistry {
    static let situationMap: [SituationID: SituationDefinition] = [
        
        // S1 – preparing the trip
        .s1PreparingTrip: SituationDefinition(
            id: .s1PreparingTrip,
            title: "Preparing the trip",
            actionTags: [
                "A1",                // Start trip
                "A3", "A5", "A4", "A6", // Motor regime
                "A1A"               // Abort trip
            ]
        ),
        
        // S2 – trip started
        .s2TripStarted: SituationDefinition(
            id: .s2TripStarted,
            title: "Trip started",
            actionTags: [
                "A7M", "A7A",       // Cast off (mutually exclusive)
                "A3", "A5", "A4", "A6", // Motor regime
                "A1R"              // Stop the trip
            ]
        ),
        
        // S3 – in harbour/anchorage/buoy field
        .s3InHarbourArea: SituationDefinition(
            id: .s3InHarbourArea,
            title: "In harbour / anchorage / buoy field",
            actionTags: [
                "A11H", "A11A", "A11B", // Leave zone
                "A9",                   // Tank fuel
                "A3", "A5", "A4", "A6", // Motor regime
                "A10",                  // Relocate without leaving
                "A8M", "A8A"            // Stop boat (mutually exclusive)
            ]
        ),
        
        // S41 – coastal, under motor
        .s41CoastalMotor: SituationDefinition(
            id: .s41CoastalMotor,
            title: "Coastal area, under motor",
            actionTags: [
                "A3", "A5", "A4", "A6",         // Motor regime
                "A27", "A30", "A29", "A28",     // Add sails
                "A50", "A24", "A21", "A23", "A20", // Navigation (A24 if WPT)
                "A25", "A25R", "A26",           // Steering / AP
                "A13", "A14", "A15",            // Change zone
                "A16"                           // Approach
            ]
        ),
        
        // S42 – protected water, under motor
        .s42ProtectedMotor: SituationDefinition(
            id: .s42ProtectedMotor,
            title: "Protected water, under motor",
            actionTags: [
                "A3", "A5", "A4", "A6",         // Motor regime
                "A27", "A30", "A29", "A28",     // Add sails
                "A50", "A24", "A21", "A23", "A20", // Navigation
                "A25", "A25R", "A26",           // Steering / AP
                "A12", "A14",                   // Change zone
                "A16"                           // Approach
            ]
        ),
        
        // S43 – intercoastal waterway, under motor
        .s43WaterwayMotor: SituationDefinition(
            id: .s43WaterwayMotor,
            title: "Intercostal waterway, under motor",
            actionTags: [
                "A3", "A5", "A4", "A6",         // Motor regime
                "A50", "A24",                   // Navigation
                "A25", "A25R", "A26",           // Steering
                "A27", "A30", "A29", "A28",     // Add sails
                "A12", "A15",                   // Change zone
                "A16"                           // Approach
            ]
        ),
        
        // S44 – open sea, under motor
        .s44OpenSeaMotor: SituationDefinition(
            id: .s44OpenSeaMotor,
            title: "Open sea, under motor",
            actionTags: [
                "A3", "A5", "A4", "A6",         // Motor regime
                "A25", "A25R", "A26",           // Steering
                "A27", "A30", "A29", "A28",     // Add sails
                "A23", "A24",                   // Navigate (A24 if WPT)
                "A21",                          // Forced navigation
                "A12"                           // Change zone
            ]
        ),
        
        // S51 – coastal area, under sail / motorsail, ≤4 Bft
        .s51CoastalSail: SituationDefinition(
            id: .s51CoastalSail,
            title: "Coastal area, under sail (≤4 Bft)",
            actionTags: [
                "A39", "A40", "A43", "A44",     // Modify AWA
                "A41", "A42", "A27W", "A27WR",          // Modify sail shape
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R",
                "A28",                          // Modify sail plan
                "A50", "A24", "A21", "A23", "A20", // Navigation
                "A25", "A25R", "A26",           // Steering
                "A33R", "A33F", "A34", "A35F", "A35R", "A36", // Reef
                "A13", "A14", "A15",            // Change zone
                "A16",                          // Approach
                "A3", "A5", "A4", "A6"          // Motor regime (if motorsail)
            ]
        ),
        
        // S52 – protected water, under sail / motorsail, ≤4 Bft
        .s52ProtectedSail: SituationDefinition(
            id: .s52ProtectedSail,
            title: "Protected water, under sail (≤4 Bft)",
            actionTags: [
                "A39", "A40", "A43", "A44",     // Modify AWA
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R",
                "A28",                          // Modify sail plan
                "A41", "A42", "A27W", "A27WR",          // Modify sail shape
                "A25", "A25R", "A26",           // Steering
                "A33R", "A33F", "A34", "A35F", "A35R", "A36",
                "A50", "A24", "A21", "A23", "A20", // Navigation
                "A12", "A14",                   // Change zone
                "A16",                          // Approach
                "A3", "A5", "A4", "A6"          // Motor regime (if motorsail)
            ]
        ),
        
        // S53 – intercoastal waterway, under sail / motorsail, ≤4 Bft
        .s53WaterwaySail: SituationDefinition(
            id: .s53WaterwaySail,
            title: "Intercostal waterway, under sail (≤4 Bft)",
            actionTags: [
                "A39", "A40", "A43", "A44",     // Modify AWA
                "A25", "A25R", "A26",           // Steering
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R",
                "A28",                          // Modify sail plan
                "A41", "A42", "A27W", "A27WR",           // Modify sail shape
                "A33R", "A33F", "A34", "A35F", "A35R", "A36",
                "A50", "A24", "A21", "A23", "A20", // Navigation
                "A12", "A15",                   // Change zone
                "A16",                          // Approach
                "A3", "A5", "A4", "A6"          // Motor regime (if motorsail)
            ]
        ),
        
        // S54 – open sea, under sail / motorsail, ≤4 Bft
        .s54OpenSeaSail: SituationDefinition(
            id: .s54OpenSeaSail,
            title: "Open sea, under sail (≤4 Bft)",
            actionTags: [
                "A39", "A40", "A43", "A44",     // Modify AWA
                "A25", "A25R", "A26",           // Steering
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R",
                "A28",                          // Modify sail plan
                "A33R", "A33F", "A34", "A35F", "A35R", "A36", // Reef
                "A41", "A42", "A27W", "A27WR",           // Modify sail shape
                "A24", "A21", "A23", "A20",     // Navigate
                "A12"                           // Change zone
            ]
        ),
        
        // S51w..S54w – same as S51..S54, but reef line shown first (same tags)
        .s51wCoastalSailStrong: SituationDefinition(
            id: .s51wCoastalSailStrong,
            title: "Coastal area, under sail, strong wind",
            actionTags:  [
                "A33R", "A33F", "A34", "A35F", "A35R", "A36", // Reef
                "A39", "A40", "A43", "A44",     // Modify AWA
                "A41", "A42",  "A27W", "A27WR",                  // Modify sail shape
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R",
                "A28",                          // Modify sail plan
                "A50", "A24", "A21", "A23", "A20", // Navigation
                "A25", "A25R", "A26",           // Steering
                "A13", "A14", "A15",            // Change zone
                "A16",                          // Approach
                "A3", "A5", "A4", "A6"          // Motor regime (if motorsail)
            ]
        ),
        .s52wProtectedSailStrong: SituationDefinition(
            id: .s52wProtectedSailStrong,
            title: "Protected water, under sail, strong wind",
            actionTags: [
                "A33R", "A33F", "A34", "A35F", "A35R", "A36", //Reef
                "A39", "A40", "A43", "A44",     // Modify AWA
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R",
                "A28",                          // Modify sail plan
                "A41", "A42",  "A27W", "A27WR",                  // Modify sail shape
                "A25", "A25R", "A26",           // Steering
                "A50", "A24", "A21", "A23", "A20", // Navigation
                "A12", "A14",                   // Change zone
                "A16",                          // Approach
                "A3", "A5", "A4", "A6"          // Motor regime (if motorsail)
            ]
        ),
        .s53wWaterwaySailStrong: SituationDefinition(
            id: .s53wWaterwaySailStrong,
            title: "Waterway, under sail, strong wind",
            actionTags: [
                "A33R", "A33F", "A34", "A35F", "A35R", "A36",
                "A39", "A40", "A43", "A44",     // Modify AWA
                "A25", "A25R", "A26",           // Steering
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R",
                "A28",                          // Modify sail plan
                "A41", "A42",  "A27W", "A27WR",                  // Modify sail shape
                "A50", "A24", "A21", "A23", "A20", // Navigation
                "A12", "A15",                   // Change zone
                "A16",                          // Approach
                "A3", "A5", "A4", "A6"          // Motor regime (if motorsail)
            ]
        ),
        .s54wOpenSeaSailStrong: SituationDefinition(
            id: .s54wOpenSeaSailStrong,
            title: "Open sea, under sail, strong wind",
            actionTags: [
                "A33R", "A33F", "A34", "A35F", "A35R", "A36", // Reef
                "A39", "A40", "A43", "A44",     // Modify AWA
                "A25", "A25R", "A26",           // Steering
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R",
                "A28",                          // Modify sail plan
                "A41", "A42",  "A27W", "A27WR",                  // Modify sail shape
                "A24", "A21", "A23", "A20",     // Navigate
                "A12"                           // Change zone
            ]
        ),
        
        // S6 – approach under motor
        .s6ApproachMotor: SituationDefinition(
            id: .s6ApproachMotor,
            title: "Approach (motor)",
            actionTags: [
                "A3", "A5", "A4", "A6",         // Motor regime
                "A11HR", "A11AR", "A11BR",      // Enter zone
                "A25", "A25R", "A26",           // Steering
                "A12"                           // Abort approach
            ]
        ),
        
        // S6s – approach under sail
        .s6sApproachSail: SituationDefinition(
            id: .s6sApproachSail,
            title: "Approach (sail)",
            actionTags: [
                "A27R", "A28", "A29R", "A30R", "A31R", "A32R", // Modify sail plan
                "A11HR", "A11AR", "A11BR",      // Enter zone
                "A25", "A25R", "A26",           // Steering
                "A12",                          // Abort approach
                "A3", "A5", "A4", "A6"          // Motor regime (if motorsail)
            ]
        ),
        
        // S7 – in harbour/anchorage/buoy field – same as S3
        /*.s7HarbourLikeS3: SituationDefinition(
         id: .s7HarbourLikeS3,
         title: "In harbour / anchorage / buoy field",
         actionTags: situationMap["S3"]?.actionTags ?? [
         "A11H", "A11A", "A11B", "A9", "A3", "A5", "A4", "A6", "A10", "A8M", "A8A"
         ]
         ),*/
        
        // S8 – storm manoeuvre
            .s8Storm: SituationDefinition(
                id: .s8Storm,
                title: "Storm manoeuvre",
                actionTags: [
                    "A33R", "A33F", "A34", "A35F", "A35R", "A36", // Reef
                    "A29", "A29R", "A30", "A30R", "A31", "A31R", "A32", "A32R", "A28", // Sail plan
                    "A39", "A40", "A43", "A44", "A41", "A42", // AWA, shape
                    "A25", "A25R", "A26",             // Steering
                    "A27R", "A17", "A18",             // Storm manoeuvres
                    "A45", "A46", "A47", "A48",       // Storm tactics
                    "A20",                            // Improving conditions
                    "A19"                             // Clear storm
                ]
            ),
        
        // S9 – dangers spotted, ≤4 Bft
        .s9DangerSpotLightWind: SituationDefinition(
            id: .s9DangerSpotLightWind,
            title: "Dangers spotted (≤4 Bft)",
            actionTags: [
                "A19",                           // Clear dangers
                "A23", "A21", "A20", "A24",      // Circumnavigate (A24 if WPT)
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R", "A28", // Sail plan
                "A39", "A40", "A43", "A44",     // AWA
                "A41", "A42",  "A27W", "A27WR",                  // Sail shape
                "A33R", "A33F", "A34", "A35F", "A35R", "A36", // Reef
                "A25", "A25R", "A26",           // Steering
                "A16",                          // Approach
                "A3", "A5", "A4", "A6"          // Motor regime
            ]
        ),
        
        // S9w – dangers spotted, >4 Bft
        .s9wDangerSpotStrongWind: SituationDefinition(
            id: .s9wDangerSpotStrongWind,
            title: "Dangers spotted (>4 Bft)",
            actionTags: [
                "A19",                           // Clear dangers
                "A23", "A21", "A20", "A24",      // Circumnavigate
                "A29", "A29R", "A30", "A30R",
                "A31", "A31R", "A32", "A32R", "A28",
                "A33R", "A33F", "A34", "A35F", "A35R", "A36",
                "A39", "A40", "A43", "A44",
                "A41", "A42", "A27W", "A27WR",
                "A25", "A25R", "A26",
                "A16",
                "A3", "A5", "A4", "A6"
            ]
        ),
        
        // Emergency layouts – E1..E4 -> EM* actions
        
            .e1MOB: SituationDefinition(
                id: .e1MOB,
                title: "MOB emergency",
                actionTags: [
                    "EM1", "EM4", "EM7", "EM8", "EM14"
                ]
            ),
        
            .e2Fire: SituationDefinition(
                id: .e2Fire,
                title: "Fire emergency",
                actionTags: [
                    "EM1", "EM8", "EM4", "EM7", "EM12", "EM14"
                ]
            ),
        
            .e3Medical: SituationDefinition(
                id: .e3Medical,
                title: "Medical emergency (distress or PanPan)",
                actionTags: [
                    "EM13",
                    "EM1", "EM2",
                    "EM4",
                    "EM5",
                    "EM8",
                    "EM9",
                    "EM7",
                    "EM13",
                    "EM14"
                ]
            ),
        
            .e4OtherEmergency: SituationDefinition(
                id: .e4OtherEmergency,
                title: "Other emergencies (distress / PanPan / sécurité / relay)",
                actionTags: [
                    // PAN PAN (not medical)
                    "EM2", "EM4", "EM8", "EM6", "EM10", "EM11", "EM13", "EM14",
                    // Distress (not medical)
                    "EM1", "EM4", "EM8", "EM6", "EM7", "EM12", "EM14",
                    // Mayday relay / assistance to others
                    "EM1R", "EM2", "EM3", "EM8", "EM4", "EM7", "EM11T", "EM14"
                ]
            )
    ]
}
