//
//  Device.swift
//  HowToMath
//

import UIKit

/// What kind of phone this is, and nothing else.
///
/// Deliberately the two dullest facts available. `identifierForVendor`, the
/// advertising identifier and anything that fingerprints a handset are all
/// absent on purpose: the only question this is here to answer is "is the app
/// slow on this hardware, or is the person thinking", and a model name answers
/// it completely.
enum Device {

    /// `iPhone16,2` — the hardware string, not the marketing name.
    ///
    /// Apple never ships a lookup table for these, and shipping one means
    /// shipping a list that is wrong the week a new phone comes out. The raw
    /// identifier is stable, sortable and honest.
    static let model: String = {
        var info = utsname()
        uname(&info)

        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }()

    /// `18.2`
    static let osVersion = UIDevice.current.systemVersion
}
