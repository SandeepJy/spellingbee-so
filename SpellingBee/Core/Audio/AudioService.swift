import Foundation
import AVFoundation

/// Centralized audio service for handling all audio playback and recording
@MainActor
final class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    @Published private(set) var isPlaying = false
    @Published private(set) var isRecording = false
    @Published var recordedSoundURL: URL?
    
    private var audioPlayer: AVAudioPlayer?
    private var audioRecorder: AVAudioRecorder?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Audio Session Configuration
    
    func configureForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session for playback: \(error)")
        }
    }
    
    func configureForRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session for recording: \(error)")
        }
    }
    
    // MARK: - Playback
    
    /// Play audio from a URL (supports both local and remote URLs)
    func play(from url: URL) async {
        configureForPlayback()
        
        do {
            let data: Data
            
            if url.isFileURL {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    print("Audio file not found at: \(url.path)")
                    return
                }
                data = try Data(contentsOf: url)
            } else {
                let (remoteData, _) = try await URLSession.shared.data(from: url)
                data = remoteData
            }
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            
            isPlaying = true
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                self.playbackContinuation = continuation
                if self.audioPlayer?.play() == false {
                    print("Failed to play audio")
                    self.playbackContinuation?.resume()
                    self.playbackContinuation = nil
                    self.isPlaying = false
                }
            }
        } catch {
            print("Failed to play audio: \(error)")
            isPlaying = false
        }
    }
    
    /// Stop current playback
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackContinuation?.resume()
        playbackContinuation = nil
    }
    
    // MARK: - Recording
    
    /// Start recording audio
    func startRecording(fileName: String) -> URL? {
        configureForRecording()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsPath.appendingPathComponent("\(fileName)_\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true
            recordedSoundURL = audioURL
            return audioURL
        } catch {
            print("Failed to start recording: \(error)")
            isRecording = false
            return nil
        }
    }
    
    /// Stop recording
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        Task { @MainActor in
            self.isPlaying = false
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }
}
