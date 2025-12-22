//
//  PressureReader.swift
//  SailTrips
//
//  Created by jeroen kok on 20/12/2025.
//


//
//  PressureReader.swift
//  SailTrips
//

import Foundation
import CoreMotion

enum PressureReader {

    /// One-shot read of iPhone barometer (hPa). Returns nil if unavailable/timeout.
    static func readHpaOnce(timeoutSeconds: Double = 4.0) async -> Float? {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return nil }

        let altimeter = CMAltimeter()
        let queue = OperationQueue.main

        return await withCheckedContinuation { cont in
            var finished = false

            // Timeout safeguard
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                if finished { return }
                finished = true
                altimeter.stopRelativeAltitudeUpdates()
                cont.resume(returning: nil)
            }

            altimeter.startRelativeAltitudeUpdates(to: queue) { data, error in
                if finished { return }
                finished = true
                altimeter.stopRelativeAltitudeUpdates()

                guard error == nil, let data else {
                    cont.resume(returning: nil)
                    return
                }

                // CoreMotion gives pressure in kPa -> convert to hPa
                let hPa = data.pressure.floatValue * 10.0
                cont.resume(returning: hPa)
            }
        }
    }
}
