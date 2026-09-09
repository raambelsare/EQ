import SwiftUI
import AVFoundation

@main
struct AppMain: App {
    @StateObject private var deviceManager = AudioDeviceManager()
    @State private var engine: AudioEngine?
    @State private var permissionState: PermissionState = .checking
    
    enum PermissionState {
        case checking
        case granted
        case denied
    }
    
    var body: some Scene {
        WindowGroup {
            MainView(deviceManager: deviceManager)
                .onAppear {
                    if self.deviceManager.engine == nil {
                        startEngine()
                    }
                }
        }
    }
    
    private func requestMicrophoneAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionState = .granted
            startEngine()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.permissionState = granted ? .granted : .denied
                    if granted {
                        self.startEngine()
                    }
                }
            }
        case .denied, .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .denied
        }
    }
    
    private func startEngine() {
        guard self.deviceManager.engine == nil else { return }
        AudioEngine.create { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newEngine):
                    do {
                        try newEngine.start()
                        self.engine = newEngine
                        self.deviceManager.engine = newEngine
                        self.deviceManager.update(from: newEngine)
                    } catch {
                        print("Failed to start audio engine: \(error)")
                        self.deviceManager.engineError = "Error: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    print("Failed to create audio engine: \(error)")
                    self.deviceManager.engineError = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
