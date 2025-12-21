# 🎯 Quick Start Guide - Local Testing

## ✅ Local Backend Integration

**App is now connected to your local backend:**
```
http://localhost:8000/api
```

**Test Credentials:**
- Email: `test@lyoapp.com`
- Password: `Test123!`

No mock data. No test helpers. **100% real functionality.**

### 1. **Authentication**
- Open app → Login with real credentials
- Or register a new account
- JWT token managed automatically

### 2. **Chat with Lyo AI**
- Navigate to **center tab (Lyo AI)**
- Type any question or request
- **Real AI responses** from backend
- Action buttons may appear based on AI response
- **If error**: Check internet connection, error message will appear

### 3. **Launch Classroom**
- Ask Lyo AI to create a lesson, or
- Backend may respond with "Start Lesson" button
- Tap to create **real classroom session from API**
- Watch for:
  ```
  ✅ Session loaded successfully: X modules
  🔊 Starting narration for slide 1: [Title]
  ```
- **TTS narration plays automatically** (listen with volume up!)
- **Animated voice bubble** appears in top-right corner (3 bars wave)
- **If error**: Retry button appears with explanation

### 4. **Navigate Slides**
- **Swipe left/right** on the screen OR
- **Tap screen** to show controls → use **Next/Previous buttons**
- **Progress saves to backend automatically**
- Watch console for:
  ```
  📄 Advanced to slide X/Y
  ```

### 5. **Quick Checks (From Backend)**
- Appear based on **settings frequency** (every 2-3 slides by default)
- **Yellow overlay** slides in from right
- **Real questions from backend lesson data**
- **Countdown timer** at top
- Tap option → Get instant feedback
- "I'm not sure" button → Skip to explanation
- **Results save to backend**

### 6. **Interactive Features**
- **Controls Overlay** (tap screen to toggle):
  - Scrubber bar (seek through slides)
  - Play/Pause narration
  - Speed controls (1x, 1.25x, 1.5x)
  - Captions toggle
  - Module grid
  - Close button

- **Module Grid** (tap grid icon):
  - See all slides as thumbnails
  - Jump to any slide directly
  - Progress indicators

- **Orientation Lock**:
  - App forces **landscape** in Classroom
  - Returns to normal when you exit

## 🎨 What You'll See

### Lyo AI Tab (Center)
- ✅ Chat interface
- ✅ Auto-appearing test message with button
- ✅ Course drawer (swipe from bottom)
- ✅ Suggestion chips

### Challenges Tab (Trophy Icon)
- ✅ **Real daily challenges** from backend
- ✅ Weekly challenge with XP rewards
- ✅ **Live battles** (1v1, team, tournament)
- ✅ **Live leaderboard** (top 50 users, refreshes from API)
- ✅ **Real achievements** synced with backend
- ✅ **Streak tracking** saved to server

### Profile Tab (Person Icon)
- ✅ Stats (lessons, streaks, XP)
- ✅ Achievements showcase
- ✅ Settings (notifications, TTS speed, frequency)

### Classroom (Full-Screen)
- ✅ Netflix-style split layout
- ✅ TTS narration with voice bubble
- ✅ Swipe navigation
- ✅ Quick checks every 2-3 slides
- ✅ Reteach overlays
- ✅ Controls overlay

## 🐛 Debugging

Open **Xcode Console** while running to see:
- 🔊 Narration events
- 📄 Slide navigation
- ✅ Quick check triggers
- ⚠️ Any errors

## 🔧 Settings to Try

In Profile → Settings:
- **TTS Speed**: Slow (0.4x), Normal (0.5x), Fast (0.6x)
- **Quick Check Frequency**: Standard (every 2-3 slides), More (every 1-2), Less (every 4-5)
- **Captions**: Auto-show or off

## � Backend Data (Real-Time)

**All content comes from backend API:**
- Lesson modules with real slides
- Quick check questions tailored to content
- Challenge data updated daily
- Leaderboard refreshes on load
- Progress syncs automatically
- Achievements unlock server-side

## 🚀 Getting Started

1. **Ensure backend is running**: `https://lyo-backend-830162750094.us-central1.run.app`
2. **Run the app** (iPhone 17 simulator or real device)
3. **Login/Register** with real credentials
4. **Chat with Lyo AI** → Ask for lessons, quizzes, explanations
5. **Start Classroom** → Backend creates session
6. **Listen to TTS** (volume up!)
7. **Navigate slides** → Progress saves automatically
8. **Complete quick checks** → Results sync to backend
9. **Try Challenges** → Real leaderboard and battles
10. **Check Profile** → Real stats and achievements

## ⚠️ Error Handling

If you see an error message:
1. **Check internet connection** (WiFi/cellular)
2. **Verify backend is accessible** (try opening API URL in browser)
3. **Tap Retry** button if available
4. **Check Xcode console** for detailed error logs with ❌ emoji

## 🐛 Debugging

Open **Xcode Console** to see real-time logs:
- ✅ Success operations (green checkmark)
- ❌ Errors with descriptions (red X)
- 🔊 Narration events (speaker)
- 📄 Navigation events (page)

---

**Note**: This is a **production-ready app**. All features connect to real backend API. No mock data fallbacks.
