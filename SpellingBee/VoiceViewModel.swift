
import Foundation
import AVFoundation

class VoiceViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    var indexOfPlayer = 0
    @Published var recordedSoundURL: URL?
    @Published var isRecording: Bool = false
    private var completionHandler: (() -> Void)?
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func startRecording(for word: String, completion: @escaping (URL?) -> Void) {
        configureAudioSession()
        
        let audioRecorderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("\(word)_\(UUID().uuidString).m4a")
        
        recordedSoundURL = audioRecorderURL
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioRecorderURL, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true
            completion(audioRecorderURL)
        } catch {
            print("Failed to setup recording: \(error)")
            isRecording = false
            completion(nil)
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        audioRecorder = nil
        
        if let url = recordedSoundURL {
            if !FileManager.default.fileExists(atPath: url.path) {
                print("Recording file not found at: \(url.path)")
                recordedSoundURL = nil
            }
        }
    }
    
    func startPlaying(url: URL, isRemote: Bool = false, completion: @escaping () -> Void) {
        self.completionHandler = completion
        configureAudioSession()
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Audio file not found at: \(url.path)")
            completionHandler?()
            completionHandler = nil
            return
        }
        
        print ("Playing audio from: \(url.path)")
        
        do {
            _ = try FileManager.default.attributesOfItem(atPath: url.path)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            if audioPlayer?.play() == false {
                print("Failed to play audio: playback returned false")
                completionHandler?()
                completionHandler = nil
            }
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
            if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError {
                print("Underlying error: \(underlyingError)")
            }
            completionHandler?()
            completionHandler = nil
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if !flag {
            print("Audio playback finished unsuccessfully")
        }
        completionHandler?()
        completionHandler = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        completionHandler?()
        completionHandler = nil
    }
}
