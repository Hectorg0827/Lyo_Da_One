import SwiftUI
import CoreMotion

/// CoreMotion-based parallax manager for Lyo Cards.
/// Provides layer depth offset when the device is physically tilted.
@MainActor
public class LyoParallaxManager: ObservableObject {
    public static let shared = LyoParallaxManager()
    
    @Published public var pitch: Double = 0
    @Published public var roll: Double = 0
    
    // The specific depth effect stated in Master Context: approximately 4 points of separation
    public let backgroundDepth: CGFloat = -4.0
    public let midLayerDepth: CGFloat = 0.0
    public let foregroundDepth: CGFloat = 4.0
    
    private let motionManager = CMMotionManager()
    private let maxAngle: Double = .pi / 6 // Reduce extremes
    
    private init() {
        startTracking()
    }
    
    public func startTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Limit the effect to a reasonable angle range (-30 to 30 degrees roughly)
            let limitedPitch = max(min(motion.attitude.pitch, self.maxAngle), -self.maxAngle)
            let limitedRoll = max(min(motion.attitude.roll, self.maxAngle), -self.maxAngle)
            
            // Normalize to a multiplier -1.0 to 1.0
            self.pitch = limitedPitch / self.maxAngle
            self.roll = limitedRoll / self.maxAngle
        }
    }
    
    public func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    /// Calculate offset for a given layer depth multiplier
    public func offset(for depth: CGFloat) -> CGSize {
        // Roll = X axis rotation (tilting device left/right moves layer horizontally)
        // Pitch = Y axis rotation (tilting device up/down moves layer vertically)
        return CGSize(
            width: CGFloat(roll) * depth * 5.0, // Scale factor to make the 4pt depth noticeable
            height: CGFloat(pitch) * depth * 5.0
        )
    }
}
