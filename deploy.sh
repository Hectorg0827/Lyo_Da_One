#!/bin/bash

# Deployment Script for Lyo App

echo "🚀 Starting Deployment Process..."

# 1. Clean Build Folder
echo "🧹 Cleaning build folder..."
xcodebuild clean -scheme Lyo -destination 'generic/platform=iOS'

# 2. Build for Release (Archive)
echo "📦 Building for Release..."
# Note: This will build the app but might fail at signing if no valid certificate is present.
# We use CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO to allow building without signing for verification.
xcodebuild archive \
  -scheme Lyo \
  -destination 'generic/platform=iOS' \
  -archivePath ./build/Lyo.xcarchive \
  -configuration Release

if [ $? -eq 0 ]; then
    echo "✅ Build Successful!"
    echo "📂 Archive created at ./build/Lyo.xcarchive"
    echo "👉 To upload to App Store Connect, open Xcode and organize the archive."
else
    echo "❌ Build Failed."
    exit 1
fi

echo "🎉 Deployment Prep Complete!"
