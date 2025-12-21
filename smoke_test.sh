#!/bin/bash
# LiveClassroom UI Smoke Test Runner
# Comprehensive verification of all UI elements and backend integration

echo "🧪 LiveClassroom UI Smoke Test"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test Results
PASS=0
FAIL=0
MANUAL=0

echo "📡 Step 1: Backend Health Check"
echo "--------------------------------"
BACKEND_URL="https://lyo-backend-production-830162750094.us-central1.run.app"

HEALTH_RESPONSE=$(curl -s "$BACKEND_URL/health")
if [ $? -eq 0 ] && [ -n "$HEALTH_RESPONSE" ]; then
    echo -e "${GREEN}✅ Backend is responding${NC}"
    
    # Parse Firebase Project ID
    FIREBASE_ID=$(echo "$HEALTH_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('firebase_project_id', 'NOT_SET'))" 2>/dev/null)
    
    if [ "$FIREBASE_ID" = "lyo-app" ]; then
        echo -e "${GREEN}✅ Firebase Project ID: $FIREBASE_ID (CORRECT)${NC}"
        ((PASS++))
    else
        echo -e "${RED}❌ Firebase Project ID: $FIREBASE_ID (Expected: lyo-app)${NC}"
        ((FAIL++))
    fi
else
    echo -e "${RED}❌ Backend not responding${NC}"
    ((FAIL++))
fi

echo ""
echo "📱 Step 2: iOS App Build"
echo "------------------------"

cd "/Users/hectorgarcia/LYO_Da_ONE"

BUILD_OUTPUT=$(xcodebuild -scheme Lyo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5)
BUILD_OUTPUT=$(xcodebuild -scheme Lyo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5)

if echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
    echo -e "${GREEN}✅ iOS app builds successfully${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ iOS app build failed${NC}"
    echo "$BUILD_OUTPUT"
    ((FAIL++))
fi

echo ""
echo "🎯 Step 3: Manual UI Verification Checklist"
echo "-------------------------------------------"
echo ""
echo -e "${YELLOW}Please complete the following manual tests:${NC}"
echo ""

MANUAL_TESTS=(
    "App launches without crashing"
    "Navigate to Classroom/Live Lesson"
    "Lio avatar appears and animates"
    "Lesson content displays correctly"
    "Progress bar shows at top"
    "Block counter shows (e.g., 1/6)"
    "'Next' button works"
    "'Previous' button works (when applicable)"
    "Quiz question displays with options"
    "Can select quiz answer"
    "Quiz feedback shows (correct/incorrect)"
    "Sentiment signals work (Confused, Slower, etc.)"
    "Transcript button opens sheet"
    "Transcript shows all interactions"
    "Ask Question button works"
    "Can type and send question"
    "Question appears in transcript"
    "Lio responds to question"
    "Progress percentage updates"
    "Completed blocks tracked"
)

for i in "${!MANUAL_TESTS[@]}"; do
    echo "  [ ] $((i+1)). ${MANUAL_TESTS[$i]}"
    ((MANUAL++))
done

echo ""
echo "🔥 Step 4: Backend Integration Test"
echo "-----------------------------------"
echo ""
echo -e "${YELLOW}In the iOS app, try these scenarios:${NC}"
echo ""
echo "  [ ] 1. Sign in with Google"
echo "  [ ] 2. Watch for: '✅ Backend Firebase auth successful'"
echo "  [ ] 3. Request: 'Create a course on Python basics'"
echo "  [ ] 4. Verify course generates (not mock data)"
echo "  [ ] 5. Complete a lesson block"
echo "  [ ] 6. Answer a quiz correctly"
echo "  [ ] 7. Send a sentiment signal"
echo "  [ ] 8. Ask a question"
echo "  [ ] 9. Check transcript for all interactions"
echo ""

echo ""
echo "📊 Test Summary"
echo "==============="
echo -e "Automated Tests: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo -e "Manual Tests: ${YELLOW}$MANUAL to verify${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 All automated tests passed!${NC}"
    echo "Please complete manual verification."
else
    echo -e "${RED}⚠️  Some automated tests failed. Fix before manual testing.${NC}"
fi

echo ""
echo "📝 Quick Test Commands:"
echo "----------------------"
echo "Backend health: curl $BACKEND_URL/health | python3 -m json.tool"
echo "Build iOS: xcodebuild -scheme Lyo build"
echo "Run simulator: open -a Simulator"
echo ""
