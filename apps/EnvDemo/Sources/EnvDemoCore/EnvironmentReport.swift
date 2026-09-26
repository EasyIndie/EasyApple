import Foundation

/// 一台设备(或模拟器)的环境探测结果。
public struct EnvironmentReport: Equatable, Sendable {
    public var model: String
    public var osName: String
    public var osVersion: String
    public var isSimulator: Bool
    public var architecture: String
    public var screenWidthPoints: Int
    public var screenHeightPoints: Int
    public var physicalMemoryBytes: UInt64
    public var storageTotalBytes: UInt64
    public var gpuName: String

    public init(
        model: String = "",
        osName: String = "",
        osVersion: String = "",
        isSimulator: Bool = false,
        architecture: String = "",
        screenWidthPoints: Int = 0,
        screenHeightPoints: Int = 0,
        physicalMemoryBytes: UInt64 = 0,
        storageTotalBytes: UInt64 = 0,
        gpuName: String = ""
    ) {
        self.model = model
        self.osName = osName
        self.osVersion = osVersion
        self.isSimulator = isSimulator
        self.architecture = architecture
        self.screenWidthPoints = screenWidthPoints
        self.screenHeightPoints = screenHeightPoints
        self.physicalMemoryBytes = physicalMemoryBytes
        self.storageTotalBytes = storageTotalBytes
        self.gpuName = gpuName
    }

    /// 输出成人类可读的多行文本(纯函数,便于测试)。
    public func formatAsText() -> String {
        var lines: [String] = []
        lines.append("型号: \(model.isEmpty ? "未知" : model)")
        lines.append("系统: \(osName) \(osVersion)")
        lines.append("模拟器: \(isSimulator ? "是" : "否")")
        lines.append("架构: \(architecture.isEmpty ? "未知" : architecture)")
        if screenWidthPoints > 0, screenHeightPoints > 0 {
            lines.append("屏幕: \(screenWidthPoints) x \(screenHeightPoints) pt")
        }
        lines.append("内存: \(formatBytes(physicalMemoryBytes))")
        lines.append("存储: \(formatBytes(storageTotalBytes))")
        lines.append("GPU: \(gpuName.isEmpty ? "未知" : gpuName)")
        return lines.joined(separator: "\n")
    }
}

/// 把字节数格式化成可读字符串(固定 en_US_POSIX locale,结果确定、可测试)。
public func formatBytes(_ bytes: UInt64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024, unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    let number = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    return "\(number) \(units[unitIndex])"
}
