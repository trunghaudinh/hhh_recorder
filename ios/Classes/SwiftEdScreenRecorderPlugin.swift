import Flutter
import UIKit
import ReplayKit
import Photos

struct RecorderConfig {
    var fileName: String = ""
    var dirPathToSave: NSString = ""
    var isAudioEnabled: Bool = false
    var addTimeCode: Bool! = false
    var filePath: NSString = ""
    var videoFrame: Int?
    var videoBitrate: Int?
    var fileOutputFormat: String = ""
    var fileExtension: String = ""
    var videoHash: String = ""
    var width: Int?
    var height: Int?
}

struct JsonObj: Codable {
    var success: Bool!
    var file: String
    var isProgress: Bool!
    var eventname: String!
    var message: String?
    var videohash: String!
    var startdate: Int?
    var enddate: Int?
    var checkStatus: String?
}

public class SwiftEdScreenRecorderPlugin: NSObject, FlutterPlugin {
    
    let recorder = RPScreenRecorder.shared()
    var videoOutputURL: URL?
    var videoWriter: AVAssetWriter?
    var audioInput: AVAssetWriterInput!
    var videoWriterInput: AVAssetWriterInput?
    
    var success: Bool = false
    var startDate: Int?
    var endDate: Int?
    var isProgress: Bool = false
    var eventName: String = ""
    var message: String = ""
    var checkStatus: String = "undetermined"
    
    var myResult: FlutterResult?
    
    var recorderConfig: RecorderConfig = RecorderConfig()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ed_screen_recorder", binaryMessenger: registrar.messenger())
        let instance = SwiftEdScreenRecorderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        myResult = result
        
        if call.method == "startRecordScreen" {
            let args = call.arguments as? Dictionary<String, Any>
            recorderConfig = RecorderConfig()
            recorderConfig.isAudioEnabled = ((args?["audioenable"] as? Bool?)! ?? false)!
            recorderConfig.fileName = (args?["filename"] as? String)! + ".mp4"
            recorderConfig.dirPathToSave = ((args?["dirpathtosave"] as? NSString) ?? "")
            recorderConfig.addTimeCode = ((args?["addtimecode"] as? Bool?)! ?? false)!
            recorderConfig.videoFrame = (args?["videoframe"] as? Int)!
            recorderConfig.videoBitrate = (args?["videobitrate"] as? Int)!
            recorderConfig.fileOutputFormat = (args?["fileoutputformat"] as? String)!
            recorderConfig.fileExtension = (args?["fileextension"] as? String)!
            recorderConfig.videoHash = (args?["videohash"] as? String)!
            recorderConfig.width = (args?["width"] as? Int)
            recorderConfig.height = (args?["height"] as? Int)
            
            if UIDevice.current.orientation.isLandscape {
                if recorderConfig.width == nil {
                    recorderConfig.width = Int(UIScreen.main.nativeBounds.height)
                }
                if recorderConfig.height == nil {
                    recorderConfig.height = Int(UIScreen.main.nativeBounds.width)
                }
            } else {
                if recorderConfig.width == nil {
                    recorderConfig.width = Int(UIScreen.main.nativeBounds.width)
                }
                if recorderConfig.height == nil {
                    recorderConfig.height = Int(UIScreen.main.nativeBounds.height)
                }
            }
            
            self.startDate = Int(NSDate().timeIntervalSince1970 * 1_000)
            startRecording(width: Int32(recorderConfig.width!), height: Int32(recorderConfig.height!)) { success, message, checkStatus in
                self.success = success
                self.message = message
                self.checkStatus = checkStatus
                self.isProgress = success // Cập nhật isProgress dựa trên success
                self.eventName = "startRecordScreen"
                
                let jsonObject = JsonObj(
                    success: self.success,
                    file: "\(self.recorderConfig.filePath)/\(self.recorderConfig.fileName)",
                    isProgress: self.isProgress,
                    eventname: self.eventName,
                    message: self.message,
                    videohash: self.recorderConfig.videoHash,
                    startdate: self.startDate,
                    enddate: self.endDate ?? 0,
                    checkStatus: self.checkStatus
                )
                let encoder = JSONEncoder()
                if let json = try? encoder.encode(jsonObject),
                   let jsonStr = String(data: json, encoding: .utf8) {
                    result(jsonStr)
                } else {
                    result(FlutterError(code: "ENCODE_ERROR", message: "Failed to encode JSON", details: nil))
                }
            }
        } else if call.method == "stopRecordScreen" {
            if videoWriter != nil {
                self.success = Bool(stopRecording())
                self.isProgress = Bool(false)
                self.eventName = String("stopRecordScreen")
                self.endDate = Int(NSDate().timeIntervalSince1970 * 1_000)
            } else {
                self.success = Bool(false)
                self.message = "Recording has not been started."
                // Không thay đổi checkStatus ở đây để giữ trạng thái từ startRecording
            }
            let jsonObject = JsonObj(
                success: self.success,
                file: "\(self.recorderConfig.filePath)/\(self.recorderConfig.fileName)",
                isProgress: self.isProgress,
                eventname: self.eventName,
                message: self.message,
                videohash: self.recorderConfig.videoHash,
                startdate: self.startDate ?? Int(NSDate().timeIntervalSince1970 * 1_000),
                enddate: self.endDate ?? 0,
                checkStatus: self.checkStatus // Giữ checkStatus từ startRecording
            )
            let encoder = JSONEncoder()
            if let json = try? encoder.encode(jsonObject),
               let jsonStr = String(data: json, encoding: .utf8) {
                result(jsonStr)
            } else {
                result(FlutterError(code: "ENCODE_ERROR", message: "Failed to encode JSON", details: nil))
            }
        } else if call.method == "pauseRecordingScreen" {
            result(true)
        } else if call.method == "resumeRecordingScreen" {
            result(true)
        }
    }
    
    func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    @objc func startRecording(width: Int32, height: Int32, completion: @escaping (Bool, String, String) -> Void) {
        var res: Bool = true
        var message: String = ""
        var checkStatus: String = "undetermined"
        
        // Configure AVAudioSession
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            message = "Failed to configure audio session: \(error.localizedDescription)"
            res = false
            checkStatus = "denied"
            completion(res, message, checkStatus)
            return
        }
        
        if recorder.isAvailable {
            if recorderConfig.dirPathToSave != "" {
                recorderConfig.filePath = recorderConfig.dirPathToSave as NSString
                self.videoOutputURL = URL(fileURLWithPath: String(recorderConfig.filePath.appendingPathComponent(recorderConfig.fileName)))
            } else {
                recorderConfig.filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
                self.videoOutputURL = URL(fileURLWithPath: String(recorderConfig.filePath.appendingPathComponent(recorderConfig.fileName)))
            }
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: videoOutputURL!.path) {
                    try FileManager.default.removeItem(at: videoOutputURL!)
                }
            } catch let fileError as NSError {
                message = String(fileError as! Substring) as String
                res = false
                checkStatus = "denied"
                completion(res, message, checkStatus)
                return
            }
            
            do {
                try videoWriter = AVAssetWriter(outputURL: videoOutputURL!, fileType: AVFileType.mp4)
                message = "Started Video"
            } catch let writerError as NSError {
                message = String(writerError as! Substring) as String
                videoWriter = nil
                res = false
                checkStatus = "denied"
                completion(res, message, checkStatus)
                return
            }
            
            if #available(iOS 11.0, *) {
                recorder.isMicrophoneEnabled = recorderConfig.isAudioEnabled
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: NSNumber(value: width),
                    AVVideoHeightKey: NSNumber(value: height),
                    AVVideoCompressionPropertiesKey: [
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                        AVVideoAverageBitRateKey: recorderConfig.videoBitrate ?? 6000000
                    ] as [String: Any]
                ]
                self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
                self.videoWriterInput?.expectsMediaDataInRealTime = true
                self.videoWriter?.add(videoWriterInput!)
                
                if recorderConfig.isAudioEnabled {
                    let audioOutputSettings: [String: Any] = [
                        AVNumberOfChannelsKey: 2,
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 44100,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]
                    self.audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
                    self.audioInput?.expectsMediaDataInRealTime = true
                    self.videoWriter?.add(audioInput!)
                }
                
                recorder.startCapture(handler: { (cmSampleBuffer, rpSampleType, error) in
                    guard error == nil else {
                        self.checkStatus = "denied"
                        self.message = "Capture error: \(error!.localizedDescription)"
                        return
                    }
                    switch rpSampleType {
                    case .video:
                        if self.videoWriter?.status == .unknown {
                            self.videoWriter?.startWriting()
                            self.videoWriter?.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer))
                        } else if self.videoWriter?.status == .writing {
                            if self.videoWriterInput?.isReadyForMoreMediaData == true {
                                if !self.videoWriterInput!.append(cmSampleBuffer) {
                                    self.message = "Error starting capture"
                                    self.checkStatus = "denied"
                                }
                            }
                        }
                    case .audioMic:
                        if self.recorderConfig.isAudioEnabled {
                            if self.audioInput?.isReadyForMoreMediaData == true {
                                if !self.audioInput!.append(cmSampleBuffer) {
                                    print(self.videoWriter?.status ?? "")
                                    print(self.videoWriter?.error ?? "")
                                }
                            }
                        }
                    default:
                        break
                    }
                }) { error in
                    if let error = error {
                        res = false
                        message = "Failed to start capture: \(error.localizedDescription)"
                        checkStatus = "denied"
                    } else {
                        res = true
                        message = "Started Video"
                        checkStatus = "granted"
                    }
                    completion(res, message, checkStatus)
                }
            } else {
                res = false
                message = "Screen recorder is not available."
                checkStatus = "denied"
                completion(res, message, checkStatus)
            }
        } else {
            res = false
            message = "Screen recorder is not available."
            checkStatus = "denied"
            completion(res, message, checkStatus)
        }
    }
    
    @objc func stopRecording() -> Bool {
        var res: Bool = true
        if recorder.isRecording {
            if #available(iOS 11.0, *) {
                recorder.stopCapture { error in
                    if let error = error {
                        res = false
                        self.message = "Error in stopRecording: \(error.localizedDescription)"
                        self.checkStatus = "denied"
                    } else {
                        DispatchQueue.main.async {
                            if self.videoWriter?.status == .writing {
                                self.videoWriterInput?.markAsFinished()
                                if self.recorderConfig.isAudioEnabled {
                                    self.audioInput?.markAsFinished()
                                }
                                
                                self.videoWriter?.finishWriting {
                                    DispatchQueue.main.async {
                                        if self.videoWriter?.status == .completed {
                                            PHPhotoLibrary.shared().performChanges({
                                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoOutputURL!)
                                            }) { success, error in
                                                if success {
                                                    self.message = "Video saved successfully."
                                                    self.checkStatus = "granted"
                                                } else {
                                                    res = false
                                                    self.message = "Failed to save video: \(error?.localizedDescription ?? "unknown error")"
                                                    self.checkStatus = "denied"
                                                }
                                                self.sendStopRecordingResult(res: res)
                                            }
                                        } else {
                                            res = false
                                            self.message = "Failed to finish writing with status: \(self.videoWriter?.status.rawValue ?? -1)"
                                            self.checkStatus = "denied"
                                            self.sendStopRecordingResult(res: res)
                                        }
                                    }
                                }
                            } else {
                                res = false
                                self.message = "Attempted to stop recording while writer status is: \(self.videoWriter?.status.rawValue ?? -1)"
                                self.checkStatus = "denied"
                                self.sendStopRecordingResult(res: res)
                            }
                        }
                    }
                }
            } else {
                res = false
                self.message = "iOS version does not support this plugin."
                self.checkStatus = "denied"
                self.sendStopRecordingResult(res: res)
            }
        } else {
            res = false
            self.message = "Recording has not been started."
            // Không thay đổi checkStatus ở đây để giữ trạng thái từ startRecording
            self.sendStopRecordingResult(res: res)
        }
        return res
    }
    
    private func sendStopRecordingResult(res: Bool) {
        let jsonObject = JsonObj(
            success: res,
            file: "\(self.recorderConfig.filePath)/\(self.recorderConfig.fileName)",
            isProgress: false,
            eventname: "stopRecordScreen",
            message: self.message,
            videohash: self.recorderConfig.videoHash,
            startdate: self.startDate ?? Int(NSDate().timeIntervalSince1970 * 1_000),
            enddate: self.endDate ?? Int(NSDate().timeIntervalSince1970 * 1_000),
            checkStatus: self.checkStatus
        )
        let encoder = JSONEncoder()
        if let json = try? encoder.encode(jsonObject),
           let jsonStr = String(data: json, encoding: .utf8) {
            self.myResult?(jsonStr)
        } else {
            self.myResult?(FlutterError(code: "ENCODE_ERROR", message: "Failed to encode JSON", details: nil))
        }
    }
}