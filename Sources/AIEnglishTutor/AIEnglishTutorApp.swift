import SwiftUI

public struct AIEnglishTutorApp: App {
    @StateObject private var viewModel: AppViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: AppViewModel(
            keychainService: KeychainService(),
            hotkeyService: GlobalHotkeyService(),
            screenCaptureService: ScreenCaptureService(),
            audioEngineService: AudioEngineService(),
            geminiLiveClient: GeminiLiveClient(),
            sessionStorageService: SessionStorageService()
        ))
    }

    public var body: some Scene {
        WindowGroup("AI English Tutor") {
            MainWindow(viewModel: viewModel)
        }
        MenuBarExtra("AI English Tutor", systemImage: "graduationcap") {
            MenuBarView(viewModel: viewModel)
        }
    }
}


