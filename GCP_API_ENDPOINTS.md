# 🔌 GCP Cloud Run API Endpoints

## Base URL
```
https://lyo-backend-830162750094.us-central1.run.app
```

## Updated Endpoint Mapping

### Authentication
- ✅ `POST /auth/login` - User login
- ✅ `POST /auth/register` - User registration
- `POST /auth/refresh` - Refresh JWT token
- `GET /auth/me` - Get current user
- `GET /auth/profile` - Get user profile

### AI Mentor Chat
- ✅ `POST /ai/mentor/conversation` - Send message to AI mentor (was `/chat/leo`)
- `GET /ai/mentor/history` - Get chat history
- `GET /ai/health` - Check AI service health

### Learning & Courses
- ✅ `GET /learning/courses` - Get all courses (was `/courses/cards`)
- `GET /learning/courses/:id` - Get specific course
- `GET /learning/courses/:id/lessons` - Get course lessons
- `POST /learning/courses/:id/publish` - Publish course
- ✅ `GET /learning/lessons/:id` - Get lesson/session (was `/classroom/sessions/:id`)
- ✅ `POST /learning/enrollments` - Create enrollment (was `/classroom/sessions`)
- ✅ `POST /learning/lesson-completions` - Save progress (was `/classroom/sessions/:id/progress`)
- `GET /learning/progress/:userId` - Get user progress

### Gamification
- ✅ `GET /gamification/challenges` - Get challenges (was `/challenges`)
- ✅ `POST /gamification/challenges/:id/complete` - Complete challenge (was `/challenges/:id/complete`)
- ✅ `GET /gamification/streak` - Get streak data (was `/challenges/streak`)
- ✅ `GET /gamification/leaderboard` - Get leaderboard (was `/leaderboard`)
- ✅ `GET /gamification/achievements` - Get achievements (was `/achievements`)
- ✅ `GET /gamification/battles` - Get battles (was `/battles`)
- ✅ `POST /gamification/battles` - Start battle (was `/battles`)
- ✅ `POST /gamification/battles/:id/accept` - Accept battle (was `/battles/:id/accept`)
- ✅ `POST /gamification/battles/:id/decline` - Decline battle (was `/battles/:id/decline`)
- `POST /gamification/xp/award` - Award XP
- `GET /gamification/xp/summary` - Get XP summary
- `POST /gamification/achievements/:id/unlock` - Unlock achievement

### Social & Feeds
- `GET /posts` - Get posts
- `GET /posts/:id` - Get specific post
- `POST /posts/:id/react` - React to post
- `GET /posts/:id/comments` - Get post comments
- `GET /feeds/personalized` - Get personalized feed
- `POST /users/:id/follow` - Follow user

### Curriculum Generation
- `POST /ai/curriculum/course-outline` - Generate course outline
- `POST /ai/curriculum/lesson-content` - Generate lesson content
- `POST /ai/curation/evaluate-content` - Evaluate content
- `POST /gen-curriculum/content/generate` - Generate curriculum

### File Uploads
- ✅ `POST /files/upload` - Upload file (needs verification)

## Testing Endpoints

### Test Authentication
```bash
curl -X POST https://lyo-backend-830162750094.us-central1.run.app/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

### Test AI Mentor
```bash
curl -X POST https://lyo-backend-830162750094.us-central1.run.app/ai/mentor/conversation \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"message":"Hello, Lyo!"}'
```

### Test Courses
```bash
curl https://lyo-backend-830162750094.us-central1.run.app/learning/courses \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Test Challenges
```bash
curl https://lyo-backend-830162750094.us-central1.run.app/gamification/challenges \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Changes Made

### From Render.com → GCP Cloud Run
1. ❌ `/chat/leo` → ✅ `/ai/mentor/conversation`
2. ❌ `/courses/cards` → ✅ `/learning/courses`
3. ❌ `/classroom/sessions` → ✅ `/learning/enrollments` & `/learning/lessons/:id`
4. ❌ `/challenges/*` → ✅ `/gamification/challenges/*`
5. ❌ `/leaderboard` → ✅ `/gamification/leaderboard`
6. ❌ `/achievements` → ✅ `/gamification/achievements`
7. ❌ `/battles/*` → ✅ `/gamification/battles/*`

## Notes

- All endpoints require JWT Bearer token (except login/register)
- API version is `v1` but not included in base URL
- WebSocket available at `wss://lyo-backend-830162750094.us-central1.run.app`
- Region: `us-central1` (Iowa, USA)
- Project ID: `830162750094`

## Response Format

All responses should follow this structure:
```json
{
  "success": true,
  "data": {...},
  "message": "Success message"
}
```

Error responses:
```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE"
}
```

---

**Last Updated**: November 5, 2025
**Build Status**: ✅ BUILD SUCCEEDED
