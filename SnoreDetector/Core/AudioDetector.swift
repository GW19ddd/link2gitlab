import AVFoundation
import Combine

/// 音频检测核心：监听麦克风、识别呼噜/呼吸暂停/人声
class AudioDetector: ObservableObject {
    // 检测状态发布
    @Published var isDetecting = false
    @Published var currentVolume: Float = 0.0
    @Published var snoreDetected = false       // 呼噜检测
    @Published var breathPauseDetected = false// 呼吸暂停检测
    @Published var humanVoiceDetected = false // 人声检测
    
    // 配置参数（可根据蜗牛睡眠逻辑调整）
    private let snoreThreshold: Float = 0.55          // 呼噜音量阈值
    private let snoreDuration: TimeInterval = 0.8     // 呼噜持续时间（秒）
    private let breathPauseThreshold: TimeInterval = 10.0 // 呼吸暂停阈值（秒）
    private let voiceFrequencyRange = 85...255        // 人声频率范围（Hz）
    
    // 音频核心对象
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioEngine: AVAudioEngine!
    private var audioInputNode: AVAudioInputNode!
    private var timer: Timer?
    
    // 状态记录
    private var snoreStartTime: TimeInterval?
    private var lastAudioTime: TimeInterval = Date().timeIntervalSince1970
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    // MARK: - 基础配置
    private func setupAudioSession() {
        do {
            // 配置后台音频+麦克风权限
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        audioInputNode = audioEngine.inputNode
        
        // 配置音频格式（44.1kHz 单声道）
        let format = audioInputNode.inputFormat(forBus: 0)
        
        // 实时监听音频数据
        audioInputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self, self.isDetecting else { return }
            
            // 1. 计算音量（分贝）
            let volume = self.calculateVolume(from: buffer)
            DispatchQueue.main.async {
                self.currentVolume = volume
            }
            
            // 2. 检测呼噜声
            self.detectSnore(volume: volume)
            
            // 3. 检测呼吸暂停
            self.detectBreathPause()
            
            // 4. 检测人声
            self.detectHumanVoice(from: buffer)
            
            // 更新最后音频时间
            self.lastAudioTime = Date().timeIntervalSince1970
        }

                // 新增：容错处理
        do {
            try audioEngine.start()
        } catch {
            print("音频引擎初始化失败（云端构建无麦克风，真机正常）: \(error)")
        }
    }
    
    // MARK: - 核心检测逻辑
    /// 计算音频音量（0.0 ~ 1.0）
    private func calculateVolume(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        
        // 计算均方根（RMS）得到音量
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        return min(rms * 10, 1.0) // 归一化到 0-1
    }
    
    /// 检测呼噜声（持续高音量）
    private func detectSnore(volume: Float) {
        if volume > snoreThreshold {
            if snoreStartTime == nil {
                snoreStartTime = Date().timeIntervalSince1970
            } else {
                let elapsed = Date().timeIntervalSince1970 - snoreStartTime!
                if elapsed >= snoreDuration {
                    // 触发呼噜检测
                    DispatchQueue.main.async {
                        self.snoreDetected = true
                    }
                    return
                }
            }
        } else {
            snoreStartTime = nil
            DispatchQueue.main.async {
                self.snoreDetected = false
            }
        }
    }
    
    /// 检测呼吸暂停（长时间无音频）
    private func detectBreathPause() {
        let elapsed = Date().timeIntervalSince1970 - lastAudioTime
        DispatchQueue.main.async {
            self.breathPauseDetected = elapsed > self.breathPauseThreshold
        }
    }
    
    /// 检测人声（基于频率范围）
    private func detectHumanVoice(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            DispatchQueue.main.async { self.humanVoiceDetected = false }
            return
        }
        
        // 快速傅里叶变换（FFT）计算频率
        let frameCount = buffer.frameLength
        let log2n = log2(Float(frameCount))
        let fftSize = Int(pow(2, ceil(log2n)))
        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(kFFTRadix2))!
        
        var real = [Float](repeating: 0, count: fftSize/2)
        var imag = [Float](repeating: 0, count: fftSize/2)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        
        // 填充数据
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData[0], count: Int(frameCount)))
        var data = [Float](channelDataArray)
        data.append(contentsOf: [Float](repeating: 0, count: fftSize - Int(frameCount)))
        
        // 执行FFT
        vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(&data)), 2, &splitComplex, 1, vDSP_Length(fftSize/2))
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))
        
        // 计算频率峰值
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
        let maxMagnitudeIndex = magnitudes.firstIndex(of: magnitudes.max()!) ?? 0
        
        // 转换为实际频率（采样率/2 / FFT大小 * 索引）
        let sampleRate = buffer.format.sampleRate
        let peakFrequency = Float(maxMagnitudeIndex) * (sampleRate / 2) / Float(fftSize/2)
        
        // 判断是否在人声频率范围
        DispatchQueue.main.async {
            self.humanVoiceDetected = self.voiceFrequencyRange.contains(Int(peakFrequency))
        }
        
        // 释放FFT资源
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    // MARK: - 外部控制方法
    func startDetection() {
        guard !isDetecting else { return }
        
        // 请求麦克风权限
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else {
                print("麦克风权限被拒绝！")
                return
            }
            
            DispatchQueue.main.async {
                self?.isDetecting = true
                do {
                    try self?.audioEngine.start()
                } catch {
                    print("音频引擎启动失败: \(error)")
                }
            }
        }
    }
    
    func stopDetection() {
        isDetecting = false
        audioEngine.stop()
        audioInputNode.removeTap(onBus: 0)
        
        // 重置状态
        snoreDetected = false
        breathPauseDetected = false
        humanVoiceDetected = false
        snoreStartTime = nil
    }
}

