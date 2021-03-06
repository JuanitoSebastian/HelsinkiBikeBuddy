//
//  Helper.swift
//  HelsinkiBikeBuddy
//
//  Created by Juan Covarrubias on 7.2.2021.
//

import Foundation
import CoreData

class Helper {

    static func log(_ printMe: Any) {
        #if DEBUG
        print(printMe)
        #endif
    }

    static func timeIntervalToString(_ timeInverval: TimeInterval) -> String {
        if timeInverval < 60 {
            return "\(timeInverval) second"
        }
        var formatted = timeInverval / 60
        formatted.round(.toNearestOrEven)
        return "\(formatted) minute"
    }
}
