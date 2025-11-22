//
//  sailExtensions.swift
//  SailTrips
//
//  Created by jeroen kok on 30/11/2025.
//

extension SailState {
    /// A sail is "set" if it is not lowered, not down, and not out of order.
    var isSet: Bool {
        switch self {
        case .lowered, .down, .outOfOrder:
            return false
        default:
            return true
        }
    }
    
    /// Convenience if you ever need the inverse wording.
    var isLoweredOrDownOrOutOfOrder: Bool {
        switch self {
        case .lowered, .down, .outOfOrder:
            return true
        default:
            return false
        }
    }
}

extension Sail {
    /// Normalized sail name for matching.
    var normalizedName: String {
        nameOfSail.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

extension Boat {
    /// The mainsail for a classical sloop.
    var mainSail: Sail? {
        sails.first { $0.normalizedName == "mainsail" && $0.optional == false }
    }
    
    /// The headsail (Genoa or Jib) for a classical sloop.
    var headsail: Sail? {
        sails.first {
            !$0.optional && ($0.normalizedName == "genoa" || $0.normalizedName == "jib")
        }
    }
    
    /// Convenience flags – assuming you've already checked `isClassicalSloop()`.
    var isMainSailSet: Bool {
        guard let main = mainSail else { return false }
        return main.currentState.isSet
    }
    
    var isHeadsailSet: Bool {
        guard let head = headsail else { return false }
        return head.currentState.isSet
    }
}
extension Boat {
    /// Gennaker: can be named "Gennaker", "Code 0", "Code0", or "C0".
    var gennakerSail: Sail? {
        sails.first { sail in
            guard sail.optional == false else { return false }
            guard sail.currentState != .outOfOrder else { return false }
            switch sail.normalizedName {
            case "gennaker", "code 0", "code0", "c0":
                return true
            default:
                return false
            }
        }
    }

    /// Spinnaker (you can add more synonyms later if you like).
    var spinnakerSail: Sail? {
        sails.first { sail in
            guard sail.optional == false else { return false }
            guard sail.currentState != .outOfOrder else { return false }
            return sail.normalizedName == "spinnaker"
        }
    }

    var isGennakerSet: Bool {
        gennakerSail?.currentState.isSet ?? false
    }

    var isSpinnakerSet: Bool {
        spinnakerSail?.currentState.isSet ?? false
    }
}

extension Sail {
    /// Convenient classification of how this sail is reduced.
    enum ReductionMode {
        case reef
        case furl
        case none
    }

    var reductionMode: ReductionMode {
        if reducedWithFurling {
            return .furl
        } else if reducedWithReefs {
            return .reef
        } else {
            return .none
        }
    }

    // MARK: - Reef logic

    var canReefFurther: Bool {
        guard reductionMode == .reef else { return false }
        switch currentState {
        case .full, .reef1, .reef2:
            return true          // can go down to next reef
        default:
            return false         // reef3 or anything else: no further reefing
        }
    }

    var canShakeOutReef: Bool {
        guard reductionMode == .reef else { return false }
        switch currentState {
        case .reef1, .reef2, .reef3:
            return true          // can go up towards full
        default:
            return false
        }
    }

    // MARK: - Furl logic

    var canFurlFurther: Bool {
        guard reductionMode == .furl else { return false }
        switch currentState {
        case .full, .vlightFurled, .lightFurled, .halfFurled:
            return true          // can go down to more furled
        default:
            return false         // tightFurled or anything else: no further furling
        }
    }

    var canUnfurl: Bool {
        guard reductionMode == .furl else { return false }
        switch currentState {
        case .vlightFurled, .lightFurled, .halfFurled, .tightFurled:
            return true          // can go up towards full
        default:
            return false
        }
    }

    // MARK: - Generic “reduce” / “increase” for isVisible

    /// Can we reduce sail area (reef *or* furl) from here?
    var canReduce: Bool {
        // Must be set (not lowered/down/outOfOrder)
        guard currentState.isSet else { return false }
        switch reductionMode {
        case .reef: return canReefFurther
        case .furl: return canFurlFurther
        case .none: return false
        }
    }

    /// Can we increase sail area from here (shake reef / unfurl)?
    /// A sail can be increased if it is not full, but is set.
    var canIncrease: Bool {
        guard currentState.isSet else { return false }
        switch reductionMode {
        case .reef: return canShakeOutReef
        case .furl: return canUnfurl
        case .none: return false
        }
    }
}


