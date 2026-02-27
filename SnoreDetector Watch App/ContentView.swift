import SwiftUI

struct ContentView: View {
    @StateObject private var vibrationManager = WatchVibrationManager.shared
    
    var body: some View {
        VStack(spacing: 15) {
            // 状态图标
            Image(systemName: vibrationManager.snoreDetected ? "zzz.fill" : "moon.fill")
                .font(.system(size: 40))
                .foregroundColor(vibrationManager.snoreDetected ? .red : .blue)
            
            // 状态文本
            Text(vibrationManager.snoreDetected ? "检测到呼噜！" : "睡眠中...")
                .font(.title3)
            
            // 震动状态
            Text(vibrationManager.isVibrating ? "正在震动提醒" : "未震动")
                .font(.caption)
                .foregroundColor(vibrationManager.isVibrating ? .red : .gray)
            
            // 手动停止震动按钮
            if vibrationManager.isVibrating {
                Button(action: {
                    vibrationManager.stopVibration()
                }) {
                    Text("停止震动")
                        .font(.caption)
                        .padding(8)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .onAppear {
            // 启动时激活Watch会话
            _ = WatchVibrationManager.shared
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}