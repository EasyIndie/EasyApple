import Foundation

/// 模板的最小纯逻辑单元:不 import SwiftUI,可在宿主机 `swift test` 秒级验证。
public struct Greeting: Equatable, Sendable {
    public let text: String

    public init(appName: String) {
        self.text = "Hello, \(appName)"
    }
}
