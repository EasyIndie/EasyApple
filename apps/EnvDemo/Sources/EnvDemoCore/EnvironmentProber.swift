import Foundation
#if canImport(Darwin)
import Darwin
#endif
#if canImport(Metal)
import Metal
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// 真实读取本机/模拟器环境的探测器。UI/GPU 相关字段按平台条件编译。
public enum EnvironmentProber {
    public static func probe() -> EnvironmentReport {
        var report = EnvironmentReport()

        report.architecture = architecture()
        report.model = model()
        report.isSimulator = isSimulator()
        report.osName = osName()
        report.osVersion = osVersion()

        report.physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        report.storageTotalBytes = storageTotalBytes()

        let screen = screenSizePoints()
        report.screenWidthPoints = screen.width
        report.screenHeightPoints = screen.height

        report.gpuName = gpuName()

        return report
    }

    // MARK: - 各字段

    static func architecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    static func model() -> String {
        // 模拟器优先用 SIMULATOR_DEVICE_NAME 作为型号
        if let simName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"],
           !simName.isEmpty {
            return simName
        }
        #if canImport(Darwin)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &buffer, &size, nil, 0)
            return String(cString: buffer)
        }
        #endif
        return ""
    }

    static func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static func osName() -> String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return "iOS"
        #else
        return "unknown"
        #endif
    }

    static func osVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    static func storageTotalBytes() -> UInt64 {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey]),
           let total = values.volumeTotalCapacity {
            return UInt64(max(0, total))
        }
        return 0
    }

    static func screenSizePoints() -> (width: Int, height: Int) {
        #if canImport(AppKit)
        if let screen = NSScreen.main {
            let f = screen.frame
            return (Int(f.width), Int(f.height))
        }
        #endif
        #if canImport(UIKit)
        let bounds = UIScreen.main.bounds
        return (Int(bounds.width), Int(bounds.height))
        #endif
        return (0, 0)
    }

    static func gpuName() -> String {
        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            return device.name
        }
        #endif
        return ""
    }
}
