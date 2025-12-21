# 🧪 iOS App - Local Backend Testing Guide

**Date**: November 5, 2025  
**Backend**: http://localhost:8000/api  
**Test Credentials**: test@lyoapp.com / Test123!

---

## ✅ **App Updated for Local Testing**

The iOS app is now configured to connect to your **local backend** at `localhost:8000/api`.

### 📝 **What Changed**

**File**: `Sources/Services/LyoRepository.swift`

```swift
// Local backend (for testing with localhost:8000)
private let baseURL = "http://localhost:8000/api"

// GCP backend (production)
// private let baseURL = "https://lyo-backend-830162750094.us-central1.run.app"
```

**Status**: ✅ Build succeeded - App ready to test

---

## 🚀 **How to Test**

### Step 1: Start Your Local Backend

Make sure your backend is running on `localhost:8000`:

```bash
# Navigate to your backend directory
cd /path/to/backend

# Start the backend (example commands)
# Python/FastAPI:
uvicorn main:app --reload --port 8000

# Or if using different setup:
python main.py
```

**Verify it's running**:
```bash
curl http://localhost:8000/health
# Should return backend health status
```

### Step 2: Run the iOS App

1. **Open Xcode**
   - Open `Lyo.xcodeproj`
   - Select an iPhone simulator (any model)

2. **Run the App**
   - Press `CMD+R` or click the ▶️ Run button
   - Wait for simulator to launch

3. **Login**
   - App will open to login screen
   - Enter credentials:
     - **Email**: `test@lyoapp.com`
     - **Password**: `Test123!`
   - Tap "Login"

### Step 3: Test Features

After successful login, test:

1. **✅ AI Chat (Lyo)**
   - Navigate to center tab (Lyo AI)
   - Send a message: "Hello Lyo!"
   - Verify response appears

2. **✅ Courses**
   - Check if course cards load
   - Verify data from backend displays

3. **✅ Classroom**
   - Try creating a lesson
   - Verify TTS and slides work

4. **✅ Challenges**
   - Navigate to Challenges tab
   - Check leaderboard loads
   - Check challenges display

5. **✅ Profile**
   - Navigate to Profile tab
   - Verify user data displays

---

## 🔍 **Monitoring & Debugging**

### Watch Xcode Console

When you run the app, watch the Xcode console for logs:

**Success Logs to Look For**:
```
✅ Login successful: <user data>
✅ Received message from Lyo: <message>
✅ Loaded courses: <count>
✅ Loaded challenges: <count>
```

**Error Logs to Watch**:
```
❌ Error: <error message>
❌ Network error: <details>
❌ Failed to decode: <decoding error>
```

### Backend Logs

Watch your backend terminal for incoming requests:
```
INFO: 127.0.0.1 - POST /api/auth/login
INFO: 127.0.0.1 - GET /api/learning/courses
INFO: 127.0.0.1 - POST /api/ai/mentor/conversation
```

---

## 🐛 **Troubleshooting**

### Issue: "Cannot connect to server"

**Cause**: Backend not running or wrong port

**Fix**:
1. Start backend: `uvicorn main:app --reload --port 8000`
2. Verify: `curl http://localhost:8000/health`
3. Check backend is on port 8000 (not 8080 or other)

### Issue: "Invalid credentials"

**Cause**: Test user doesn't exist or wrong password

**Fix**:
1. Check backend has test user: `test@lyoapp.com`
2. Verify password is: `Test123!`
3. Or create new test user in backend

### Issue: "Unauthorized" or "401 error"

**Cause**: JWT token not working

**Fix**:
1. Check backend returns valid JWT on login
2. Verify iOS app stores token: `self.authToken = loginResponse.token`
3. Check Authorization header sent on API calls

### Issue: App launches but features don't work

**Cause**: Endpoints might be different on local backend

**Fix**:
1. Check backend endpoint structure matches:
   - `/api/auth/login`
   - `/api/ai/mentor/conversation`
   - `/api/learning/courses`
   - `/api/gamification/challenges`
2. Update iOS endpoint paths if needed

---

## 📊 **Expected API Calls**

When you test the app, expect these requests:

### 1. Login
```
POST http://localhost:8000/api/auth/login
Body: {"email":"test@lyoapp.com","password":"Test123!"}
Expected: 200 OK with JWT token
```

### 2. Load Courses
```
GET http://localhost:8000/api/learning/courses
Headers: Authorization: Bearer <token>
Expected: 200 OK with course list
```

### 3. Send Chat Message
```
POST http://localhost:8000/api/ai/mentor/conversation
Headers: Authorization: Bearer <token>
Body: {"message":"Hello Lyo!"}
Expected: 200 OK with AI response
```

### 4. Load Challenges
```
GET http://localhost:8000/api/gamification/challenges
Headers: Authorization: Bearer <token>
Expected: 200 OK with challenges list
```

---

## ⚙️ **Switching Between Local and Production**

### To Use Local Backend (Current)
```swift
private let baseURL = "http://localhost:8000/api"
// private let baseURL = "https://lyo-backend-830162750094.us-central1.run.app"
```

### To Use Production GCP Backend
```swift
// private let baseURL = "http://localhost:8000/api"
private let baseURL = "https://lyo-backend-830162750094.us-central1.run.app"
```

**After changing**: Rebuild the app (CMD+B)

---

## ✅ **Testing Checklist**

- [ ] Backend running on localhost:8000
- [ ] Backend health check responds
- [ ] iOS app built successfully
- [ ] App launched in simulator
- [ ] Login with test@lyoapp.com / Test123!
- [ ] Received JWT token
- [ ] Main app screen appears
- [ ] Test AI chat - send message
- [ ] Test courses - view course cards
- [ ] Test classroom - create lesson
- [ ] Test challenges - view challenges
- [ ] Test leaderboard - view rankings
- [ ] Test profile - view user data
- [ ] All network requests successful
- [ ] No errors in Xcode console

---

## 🎉 **Success Criteria**

### ✅ Fully Working If:
1. Login succeeds with test credentials
2. JWT token stored and used for requests
3. AI chat sends/receives messages
4. Courses load from backend
5. Challenges/leaderboard display
6. No network errors in console

### 🚨 Report Issues If:
1. Cannot connect to backend
2. Login fails with valid credentials
3. Features return 404 or 500 errors
4. Data doesn't display properly
5. App crashes on any action

---

## 📝 **Test Credentials**

**Email**: `test@lyoapp.com`  
**Password**: `Test123!`

Make sure this user exists in your local backend database!

---

## 🔄 **Next Steps After Testing**

1. **If everything works**:
   - Document any issues found
   - Test edge cases (bad network, logout, etc.)
   - Switch to production backend when ready

2. **If issues found**:
   - Check backend logs for errors
   - Verify API endpoint paths match
   - Ensure backend returns correct data format
   - Update iOS code if needed

3. **For Production**:
   - Switch baseURL to GCP
   - Test with production backend
   - Verify all features work
   - Prepare for App Store submission

---

**Status**: ✅ **READY TO TEST**  
**Action**: Start your backend on port 8000 and run the iOS app!

---

**Quick Start Commands**:

```bash
# Terminal 1 - Start Backend
cd /path/to/backend
uvicorn main:app --reload --port 8000

# Terminal 2 - Verify Backend
curl http://localhost:8000/health

# Xcode - Run App
# Press CMD+R in Xcode
# Login with test@lyoapp.com / Test123!
```

🚀 **Good luck with testing!**
