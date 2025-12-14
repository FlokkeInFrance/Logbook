//
//  Vec2.swift
//  SailTrips
//
//  Created by jeroen kok on 13/12/2025.
//


import Foundation

struct Vec2 {
    var x: Double   // East
    var y: Double   // North

    static func +(l: Vec2, r: Vec2) -> Vec2 { .init(x: l.x + r.x, y: l.y + r.y) }
    var mag: Double { sqrt(x*x + y*y) }

    /// Direction *from which* the wind is coming (meteorological), degrees true 0..359.
    /// Assumes vector points *toward* where air is moving (to-direction). Wind "from" is +180.
    var metFromDeg: Double {
        let toDeg = atan2(x, y).toDegrees0_360
        return (toDeg + 180).truncatingRemainder(dividingBy: 360)
    }
}

extension Double {
    var toRad: Double { self * .pi / 180 }
    var toDeg: Double { self * 180 / .pi }
    var toDegrees0_360: Double {
        let d = self.truncatingRemainder(dividingBy: 360)
        return d < 0 ? d + 360 : d
    }
}

/// Unit vector for a course/heading in degrees true, where 0° = North, 90° = East.
func unitFromDegTrue(_ deg: Double) -> Vec2 {
    let r = deg.toRad
    return .init(x: sin(r), y: cos(r))
}

func vecFromSpeedDir(speedKn: Double, dirDegTrue: Double) -> Vec2 {
    let u = unitFromDegTrue(dirDegTrue)
    return .init(x: u.x * speedKn, y: u.y * speedKn)
}

struct WindSolution {
    var twsKn: Double
    var twdFromDegTrue: Double
}

/// Convert apparent wind (AWA/AWS) into an earth-frame vector.
/// headingDegTrue is the boat's heading direction (where bow points).
func apparentWindEarthVector(awsKn: Double, awaDeg: Double, headingDegTrue: Double) -> Vec2 {
    // Wind angle relative to North:
    // If AWA is + to starboard, apparent wind comes from heading + AWA.
    let awaFromDegTrue = (headingDegTrue + awaDeg).toDegrees0_360

    // Create a vector pointing *toward* where the wind is going:
    // if wind comes FROM awaFromDegTrue, it goes TO +180
    let toDeg = (awaFromDegTrue + 180).toDegrees0_360
    return vecFromSpeedDir(speedKn: awsKn, dirDegTrue: toDeg)
}

/// True wind: T = A + V  (all earth-frame vectors)
func trueWind(
    awsKn: Double,
    awaDeg: Double,
    boatHeadingDegTrue: Double,
    boatSpeedKn: Double,
    boatCourseDegTrue: Double
) -> WindSolution {
    let A = apparentWindEarthVector(awsKn: awsKn, awaDeg: awaDeg, headingDegTrue: boatHeadingDegTrue)
    let V = vecFromSpeedDir(speedKn: boatSpeedKn, dirDegTrue: boatCourseDegTrue)
    let T = A + V
    return WindSolution(twsKn: T.mag, twdFromDegTrue: T.metFromDeg)
}

func currentVector(
    sogKn: Double, cogDegTrue: Double,
    stwKn: Double, headingDegTrue: Double
) -> (speedKn: Double, setDegTrue: Double) {
    let Vg = vecFromSpeedDir(speedKn: sogKn, dirDegTrue: cogDegTrue)
    let Vw = vecFromSpeedDir(speedKn: stwKn, dirDegTrue: headingDegTrue)
    let Vc = Vec2(x: Vg.x - Vw.x, y: Vg.y - Vw.y)

    // current "set" is direction current flows TO
    let setToDeg = atan2(Vc.x, Vc.y).toDegrees0_360
    return (speedKn: Vc.mag, setDegTrue: setToDeg)
}
