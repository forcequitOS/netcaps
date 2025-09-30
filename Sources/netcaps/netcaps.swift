// netcaps.swift
// Made by Taj C (forcequit)

import Foundation
import Darwin
import IOKit
import IOKit.hid
import CoreGraphics
import AppKit

// MARK: - Caps Lock State
func isCapsLockOn() -> Bool {
    return CGEventSource.keyState(.combinedSessionState, key: 57)
}

@MainActor var legitInterval: TimeInterval = 0.00050
@MainActor var lastCapsState: Bool = false
@MainActor func setInterval() {
    let currentCapsState = isCapsLockOn()
    if currentCapsState != lastCapsState {
        legitInterval = currentCapsState ? 0.01050 : 0.00050
        lastCapsState = currentCapsState
    }
}

// MARK: - Blink Caps Lock LED
@MainActor
class CapsLockLEDManager {
    private let manager: IOHIDManager
    private var cachedLEDElements: [(device: IOHIDDevice, element: IOHIDElement)] = []
    init?() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [[String: Any]] = [[
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]]
        IOHIDManagerSetDeviceMatchingMultiple(manager, match as CFArray)
        let openRc = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openRc == kIOReturnNotPermitted {
            print("Input Monitoring permissions need to be granted, exiting...")
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
            exit(1)
        }
        guard let devicesCF = IOHIDManagerCopyDevices(manager) else { return nil }
        let devices = devicesCF as! Set<IOHIDDevice>
        for device in devices {
            guard let elementsCF = IOHIDDeviceCopyMatchingElements(device, nil, 0) else { continue }
            let elements = elementsCF as! [IOHIDElement]
            for element in elements {
                if IOHIDElementGetUsagePage(element) == kHIDPage_LEDs &&
                   IOHIDElementGetUsage(element) == UInt32(kHIDUsage_LED_CapsLock) {
                    cachedLEDElements.append((device, element))
                }
            }
        }
    }
    
    func toggle(_ on: Bool) {
        for (device, element) in cachedLEDElements {
            let value = IOHIDValueCreateWithIntegerValue(
                kCFAllocatorDefault,
                element,
                mach_absolute_time(),
                on ? 1 : 0
            )
            IOHIDDeviceSetValue(device, element, value)
        }
    }
    
    func blink(times: Int = 1, interval: TimeInterval) {
        let capsOn = isCapsLockOn()
        for _ in 1...times {
            if capsOn {
                toggle(false)
                Thread.sleep(forTimeInterval: interval)
                toggle(true)
            } else {
                toggle(true)
                Thread.sleep(forTimeInterval: interval)
                toggle(false)
            }
            Thread.sleep(forTimeInterval: interval)
        }
    }
}
@MainActor let ledManager = CapsLockLEDManager()
@MainActor
func blinkCapsLock(times: Int = 1, interval: TimeInterval = legitInterval) {
    ledManager?.blink(times: times, interval: interval)
}

// MARK: - Network Monitoring
func getNetworkBytes() -> (rx: UInt64, tx: UInt64) {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
    defer { freeifaddrs(ifaddr) }
    var rx: UInt64 = 0
    var tx: UInt64 = 0
    var ptr = firstAddr
    while true {
        let name = String(cString: ptr.pointee.ifa_name)
        if name.hasPrefix("en") || name.hasPrefix("pdp_ip") || name.hasPrefix("awdl") || name.hasPrefix("ap") || name.hasPrefix("llw") {
            if let data = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                rx &+= UInt64(data.pointee.ifi_ibytes)
                tx &+= UInt64(data.pointee.ifi_obytes)
            }
        }
        
        if ptr.pointee.ifa_next == nil { break }
        ptr = ptr.pointee.ifa_next!
    }
    return (rx, tx)
}

@main
struct main {
    static func main() {
        // MARK: - Argument Handling
        let args = CommandLine.arguments
        let silent = args.contains("-s") || args.contains("--silent")
        if args.contains("-v") || args.contains("--version") {
            print("netcaps version 1.5.0")
            print("    Made by Taj C (forcequit)")
            print("    Check this out on GitHub, at https://github.com/forcequitOS/netcaps")
            exit(0)
        }
        if args.contains("-h") || args.contains("--help") {
            print("")
            print("Usage:")
            print("    netcaps [arguments]")
            print("")
            print("Arguments:")
            print("    --silent, -s         - silences command-line output")
            print("    --version, -v        - displays current version of netcaps")
            print("    --help, -h           - shows this help menu")
            print("")
            exit(0)
        }
        
        if silent {
            setpriority(PRIO_PROCESS, 0, 10)
        }
        var previousBytes = getNetworkBytes()
        var checksWithoutActivity = 0
        let maxChecksBeforeSlowdown = 7500
        
        // MARK: - Main Loop
        while true {
            autoreleasepool {
                setInterval()
                Thread.sleep(forTimeInterval: legitInterval)
                let currentBytes = getNetworkBytes()
                if currentBytes.rx > previousBytes.rx || currentBytes.tx > previousBytes.tx {
                    if !silent {
                        print("RX: \(currentBytes.rx), TX: \(currentBytes.tx)")
                    }
                    blinkCapsLock()
                    checksWithoutActivity = 0
                } else {
                    checksWithoutActivity += 1
                    if checksWithoutActivity >= maxChecksBeforeSlowdown {
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                }
                previousBytes = currentBytes
            }
        }
    }
}
