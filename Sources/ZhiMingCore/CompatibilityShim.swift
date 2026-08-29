import Foundation

// Linux（swift test）工具链不带 Combine，而 Core 的模型层只用到了
// ObservableObject 协议与 @Published 包装器两个符号。iOS/macOS 上
// canImport(Combine) 为真，本文件内容不参与编译，行为与原实现完全一致。
#if !canImport(Combine)

/// Combine ObservableObject 的最小替代：仅满足协议形状，无发布管道
/// （全库无 objectWillChange.send() 调用）
public protocol ObservableObject: AnyObject {}

/// Combine @Published 的最小替代：仅存储值，无 projectedValue
@propertyWrapper
public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}

#endif
