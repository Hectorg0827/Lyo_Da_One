import SwiftUI

struct ClassroomModuleCardView: View {
    let module: LessonModule
    let slideIndex: Int
    let settings: ClassroomSettings
    let geometry: GeometryProxy
    
    private var currentSlide: Slide {
        module.slides[slideIndex]
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side: Cover (40%)
            CoverAreaView(module: module, geometry: geometry)
                .frame(width: geometry.size.width * 0.4)
            
            // Right side: Slide content (60%)
            SlideContentView(
                slide: currentSlide,
                settings: settings
            )
            .frame(width: geometry.size.width * 0.6)
        }
    }
}

