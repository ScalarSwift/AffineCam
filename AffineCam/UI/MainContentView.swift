import CoreMedia
import SwiftUI

struct MainContentView: View {
    @State private var viewModel = CameraViewModel()

    var body: some View {
        VStack {
            if let frame = viewModel.currentFrame {
                MetalView(frame: frame)
                    .edgesIgnoringSafeArea(.all)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .aspectRatio(contentMode: .fill)
//                    .clipShape(RoundedRectangle(cornerRadius: 15))
            } else {
                ProgressView("Initializing Hardware...")
            }
        }
//        VStack {
//            if let frame = viewModel.currentFrame {
//                Text("Frame received: \(frame.presentationTimeStamp.seconds)")
//                    .font(.caption)
//                    .monospaced()
//            } else {
//                Text("Waiting for camera...")
//                    .foregroundStyle(.secondary)
//            }
//        }
        .onAppear {
            viewModel.startSession()
        }
    }
}

#Preview {
    MainContentView()
}
