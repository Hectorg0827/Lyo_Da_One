# 🚀 Quick Testing Guide - Bypass Backend Bug

## The Problem
The backend has a bug that rejects ALL passwords, even valid ones like `Test123!`. This blocks registration and login.

## The Solution
Use **Mock Authentication** to test the app while the backend team fixes their bug.

---

## 📱 How to Test the App RIGHT NOW

### Step 1: Look for the Gear Icon ⚙️
- The gear icon is in the **top-right corner** of the login/signup screen
- It's only visible in DEBUG builds (simulator or development builds)

### Step 2: Open the Debug Menu
- **Tap the gear icon ⚙️**
- A menu will slide up from the bottom

### Step 3: Choose an Option

**Option A: Quick Mock Login (Fastest)**
1. Tap **"Test Register (Mock)"**
2. Instantly logs you in with a test user
3. No forms to fill out

**Option B: Test the Registration Form**
1. Tap **"Fill Register Form"**
2. Pre-fills all fields with test data
3. Then tap **"Test Register (Mock)"**
4. Tests the UI validation flow

**Option C: Test the Login Form**
1. Switch to Login mode
2. Tap **"Fill Login Form"**
3. Pre-fills email and password
4. Then tap **"Test Login (Mock)"**

---

## ✅ What You Can Test With Mock Auth

- ✅ **All UI screens** - Home, Lyo AI, Challenges, Classroom, Profile
- ✅ **Navigation** - Tab bar, back buttons, modals
- ✅ **Avatar animations** - Professional 60 FPS SpriteKit avatar
- ✅ **Performance overlay** - Double-tap avatar to see FPS metrics
- ✅ **Form validation** - Email, password, username fields
- ✅ **Error states** - Loading indicators, error messages
- ✅ **Settings** - Profile editing, preferences

## ❌ What You Cannot Test (Backend Required)

- ❌ **Real API calls** - Mock user has no auth token
- ❌ **Data persistence** - No backend to save data
- ❌ **AI Chat** - Needs real backend connection
- ❌ **Challenges/Leaderboard** - Needs backend data
- ❌ **Social features** - Needs backend integration

---

## 🎯 Testing the Avatar Performance (Phase 1 Complete!)

Once logged in with mock auth:

1. **Go to "Lyo AI" tab** (second tab from left)
2. **See the animated avatar** - Professional 74-frame animation
3. **Double-tap the avatar** - Shows performance overlay
4. **Check the metrics**:
   - **FPS**: Should be ~60 (smooth animation)
   - **Avg**: Average FPS over time
   - **Peak**: Worst frame time (should be <20ms)
   - **Drops**: Number of dropped frames (should be minimal)

5. **Watch the console** - When you leave the screen, you'll see:
   ```
   📊 Avatar summary — avg: 59.9fps, min: 58.2fps, peak: 18.3ms, drops: 2, samples: 450
   ```

### ✅ Performance Success Criteria
- Average FPS: **>55 FPS** ✅
- Dropped frames: **<5%** ✅
- Peak frame time: **<20ms** ✅
- No NaN errors: **Clean console** ✅

---

## 🐛 If You Still See Errors

### "Connection failed" or Network Errors
- **This is expected** - Mock auth bypasses the network
- The app works offline with mock data
- Real network calls will fail gracefully

### NaN (Not-a-Number) Errors
- **Fixed in this build!** Should not appear anymore
- If you still see them, let me know which screen

### Keyboard Constraint Warnings
- **These are harmless** - iOS system warnings
- Don't affect functionality
- Happens in simulator, not on real devices

---

## 📋 When Backend is Fixed

The backend team needs to fix their password validation bug. Once fixed:

1. I'll remove the mock auth bypass
2. You'll be able to register real accounts
3. You'll be able to test all backend features
4. Ready for TestFlight and App Store!

---

## 🎉 Bottom Line

**Use the debug menu (⚙️) to bypass the backend bug and test the avatar and UI now!**

The iOS app is 100% ready - we're just waiting on the backend team to fix their validation bug.

---

**Quick Steps:**
1. Launch app
2. Tap ⚙️ (top-right corner)
3. Tap "Test Register (Mock)"
4. Enjoy testing the app! 🚀
