//
//  ConnectedMice.swift
//  UnnaturalScrollWheels
//

import Foundation
import IOKit.hid

// Keeps track of connected external mice so settings can be remembered per mouse
class ConnectedMice {

    static let shared = ConnectedMice()

    struct Mouse {
        // Vendor and product ID, so every mouse of the same model shares settings
        let id: String
        let name: String
    }

    var onChange: (() -> Void)?

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    // In connection order. One mouse can show up as several HID devices.
    private var devices: [(device: IOHIDDevice, mouse: Mouse)] = []

    // Most recently connected first, without duplicates
    var mice: [Mouse] {
        var seen = Set<String>()
        return devices.reversed().map { $0.mouse }.filter { seen.insert($0.id).inserted }
    }

    func start() {
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse,
        ] as CFDictionary)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { _, _, _, device in
            ConnectedMice.shared.deviceConnected(device)
        }, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { _, _, _, device in
            ConnectedMice.shared.deviceRemoved(device)
        }, nil)
        // The manager is never opened: matching works without it, and opening
        // the devices could trigger the Input Monitoring permission prompt.
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    private func deviceConnected(_ device: IOHIDDevice) {
        // Skip the built-in trackpad
        if IOHIDDeviceGetProperty(device, kIOHIDBuiltInKey as CFString) as? Bool == true {
            return
        }
        guard let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int,
              let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int else {
            return
        }
        let id = "\(vendorID):\(productID)"
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? id
        devices.append((device: device, mouse: Mouse(id: id, name: name)))
        onChange?()
    }

    private func deviceRemoved(_ device: IOHIDDevice) {
        devices.removeAll { $0.device === device }
        onChange?()
    }
}
