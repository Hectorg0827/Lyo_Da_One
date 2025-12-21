#!/bin/bash

echo "🚀 Generating all Lyo app Swift files..."

# Main app entry point
cat > "LyoApp/LyoApp.swift" << 'EOF'
import SwiftUI

@main
struct LyoApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                MainTabView()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
EOF

echo "✅ Created LyoApp.swift"

# Run the script
chmod +x generate_all_files.sh
