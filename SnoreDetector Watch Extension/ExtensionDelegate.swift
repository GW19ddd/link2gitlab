import WatchKit

/// WatchKit Extension 入口代理。
///
/// 说明：
/// - 该类为 watchOS 扩展提供最小可编译入口，供 Xcode / XcodeGen 生成的 WatchKit Extension target 使用。
/// - 目前不包含业务逻辑，只保证在 CI 云端生成工程与构建阶段不因缺少入口而失败。
final class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        // 扩展启动完成。
    }

    func applicationDidBecomeActive() {
        // 扩展进入前台。
    }

    func applicationWillResignActive() {
        // 扩展即将进入后台。
    }
}
