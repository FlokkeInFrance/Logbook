//
//  LogActionSituation.swift
//  SailTrips
//
//  Created by jeroen kok on 25/11/2025.
//

//
//  LogActionSituation.swift
//  SailTrips
//
//  Created by ChatGPT on 25/11/2025.
//

import Foundation
import SwiftUI

/// High-level situations S1, S2, S41… based on your spec.
/// For v1 we’ll switch them manually; later they’ll be derived from Trip/Instances.
///

struct SituationDefinition {
    let id: SituationID
    let title: LocalizedStringKey
    /// Action tags in the order you want to display them.
    let actionTags: [String]
    

}

