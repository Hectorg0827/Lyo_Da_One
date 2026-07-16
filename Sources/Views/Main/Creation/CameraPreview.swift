import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // layerClass guarantees this type; the guard avoids a force-cast crash
            // in the theoretically-impossible mismatch case.
            guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
                return AVCaptureVideoPreviewLayer()
            }
            return previewLayer
        }
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90 // Portrait orientation
            } else {
                // Use deprecated API for iOS 16
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // No updates needed
    }
}
