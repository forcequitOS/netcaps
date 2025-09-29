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
@MainActor func setInterval() {
    if isCapsLockOn() {
        legitInterval = 0.01550
    } else {
        legitInterval = 0.00050
    }
}

// MARK: - Blink Caps Lock LED
@MainActor
func blinkCapsLock(times: Int = 1, interval: TimeInterval = legitInterval) {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
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
    
    guard let devicesCF = IOHIDManagerCopyDevices(manager) else { return }
    let devices = devicesCF as! Set<IOHIDDevice>
    
    func toggle(_ on: Bool) {
        for device in devices {
            guard let elementsCF = IOHIDDeviceCopyMatchingElements(device, nil, 0) else { continue }
            let elements = elementsCF as! [IOHIDElement]
            for e in elements {
                if IOHIDElementGetUsagePage(e) == kHIDPage_LEDs &&
                   IOHIDElementGetUsage(e) == UInt32(kHIDUsage_LED_CapsLock) {
                    let value = IOHIDValueCreateWithIntegerValue(
                        kCFAllocatorDefault,
                        e,
                        mach_absolute_time(),
                        on ? 1 : 0
                    )
                    IOHIDDeviceSetValue(device, e, value)
                }
            }
        }
    }
    
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

// MARK: - Network Monitoring
func getNetworkBytes() -> (rx: UInt32, tx: UInt32) {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
    defer { freeifaddrs(ifaddr) }
    var rx: UInt32 = 0
    var tx: UInt32 = 0
    var ptr = firstAddr
    while true {
        if let data = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
            rx += data.pointee.ifi_ibytes
            tx += data.pointee.ifi_obytes
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
            print("netcaps version 1.3.0")
            print("Made by Taj C (forcequit)")
            print("Check this out on GitHub, at https://github.com/forcequitOS/netcaps")
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
        
        // MARK: - Main Loop
        var previousBytes = getNetworkBytes()
        
        while true {
            setInterval()
            Thread.sleep(forTimeInterval: legitInterval)
            let currentBytes = getNetworkBytes()
            if currentBytes.rx > previousBytes.rx || currentBytes.tx > previousBytes.tx {
                if !silent {
                    print("RX: \(currentBytes.rx), TX: \(currentBytes.tx)")
                }
                blinkCapsLock()
            }
            previousBytes = currentBytes
        }
    }
}
