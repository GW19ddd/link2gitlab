import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var audioDetector = AudioDetector()
    @StateObject private var watchConnector = WatchConnector.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 检测状态
                VStack {
                    Text(audioDetector.isDetecting ? "正在监听睡眠..." : "未监听")
                        .font(.title)
                        .foregroundColor(audioDetector.isDetecting ? .green : .gray)
                    
                    // 音量显示
                    Text(String(format: "当前音量: %.1f%%", audioDetector.currentVolume * 100))
                        .font(.subheadline)
                    
                    // 检测结果标签
                    HStack(spacing: 10) {
                        TagView(text: "呼噜", isActive: audioDetector.snoreDetected)
                        TagView(text: "呼吸暂停", isActive: audioDetector.breathPauseDetected)
                        TagView(text: "人声", isActive: audioDetector.humanVoiceDetected)
                    }
                }
                
                // 启停按钮
                Button(action: {
                    if audioDetector.isDetecting {
                        audioDetector.stopDetection()
                    } else {
                        audioDetector.startDetection()
                    }
                }) {
                    Text(audioDetector.isDetecting ? "停止检测" : "开始检测")
                        .frame(width: 200, height: 50)
                        .background(audioDetector.isDetecting ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("睡眠监测")
        }
        .onChange(of: audioDetector.snoreDetected) { isSnoring in
            // 检测到呼噜时，发送震动指令到手表
            if isSnoring {
                watchConnector.sendVibrationCommand(duration: 5.0)
            }
        }
    }
}

// 辅助视图：检测状态标签
struct TagView: View {
    let text: String
    let isActive: Bool
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(8)
            .background(isActive ? Color.red : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}