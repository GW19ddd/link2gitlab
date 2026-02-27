import WatchKit
import WatchConnectivity

/// Watch 震动管理器：接收指令并持续震动
class WatchVibrationManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchVibrationManager()
    private let session = WCSession.default
    private var vibrationTimer: Timer?
    
    @Published var isVibrating = false
    @Published var snoreDetected = false
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // 开始持续震动（直到停止）
    func startVibration(duration: TimeInterval) {
        isVibrating = true
        snoreDetected = true
        
        // 立即震动
        WKInterfaceDevice.current().play(.notification)
        
        // 循环震动（每1秒一次，直到duration结束）
        vibrationTimer?.invalidate()
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            WKInterfaceDevice.current().play(.notification)
            
            // 达到时长后停止
            if Date().timeIntervalSince(timer.fireDate) >= duration {
                self?.stopVibration()
                timer.invalidate()
            }
        }
    }
    
    // 停止震动
    func stopVibration() {
        isVibrating = false
        snoreDetected = false
        vibrationTimer?.invalidate()
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    
    // 接收iOS端的指令
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let command = message["command"] as? String else { return }
        if command == "vibrate" {
            let duration = message["duration"] as? TimeInterval ?? 5.0
            DispatchQueue.main.async {
                self.startVibration(duration: duration)
            }
        }
    }
}