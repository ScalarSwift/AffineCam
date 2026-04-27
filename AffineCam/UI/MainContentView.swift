import CoreMedia
import SwiftUI

struct MainContentView: View {
    @State private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            if let coordinator = viewModel.previewCoordinator {
                MetalCameraPreview(coordinator: coordinator)
                    .ignoresSafeArea()
            }
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.footnote)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
            VStack {
                Text(viewModel.recognizedDigits.isEmpty ? "Scanning for digits..." : viewModel.recognizedDigits)
                    .font(.system(.title, design: .monospaced))
                    .bold()
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding(.top, 50)
                Spacer()
            }
        }
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
    }
}

#Preview {
    MainContentView()
}
