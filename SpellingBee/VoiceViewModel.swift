import Foundation
import AVFoundation

@MainActor
final class VoiceViewModel: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    @Published var recordedSoundURL: URL?
    @Published var isRecording: Bool = false
    
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func startRecording(for word: String) -> URL? {
        configureAudioSession()
        
        let audioRecorderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("\(word)_\(UUID().uuidString).m4a")
        
        recordedSoundURL = audioRecorderURL
        
        let settings: [String: Any] = [
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
            return audioRecorderURL
        } catch {
            print("Failed to setup recording: \(error)")
            isRecording = false
            return nil
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
    
    func startPlaying(url: URL, isRemote: Bool = false) async {
        configureAudioSession()
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Audio file not found at: \(url.path)")
            return
        }
        
        print("Playing audio from: \(url.path)")
        
        do {
            _ = try FileManager.default.attributesOfItem(atPath: url.path)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                self.playbackContinuation = continuation
                if self.audioPlayer?.play() == false {
                    print("Failed to play audio: playback returned false")
                    self.playbackContinuation?.resume()
                    self.playbackContinuation = nil
                }
            }
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
            if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError {
                print("Underlying error: \(underlyingError)")
            }
        }
    }
}

extension VoiceViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if !flag {
            print("Audio playback finished unsuccessfully")
        }
        Task { @MainActor in
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        Task { @MainActor in
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }
}
