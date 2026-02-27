import WatchConnectivity

/// iOS ↔ Watch 通信管理器：发送震动指令
class WatchConnector: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnector()
    private let session = WCSession.default
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // 发送震动指令到手表
    func sendVibrationCommand(duration: TimeInterval = 5.0) {
        guard session.isReachable else {
            print("手表未连接！")
            return
        }
        
        let message: [String: Any] = [
            "command": "vibrate",
            "duration": duration
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("发送震动指令失败: \(error)")
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("Watch 会话激活失败: \(error)")
        }
    }
    
    // 兼容 iOS 13 以下（可保留）
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
}