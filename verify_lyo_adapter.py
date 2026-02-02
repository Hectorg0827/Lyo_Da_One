import requests
import json
import sys

# Configuration - Localhost (Patched Version)
API_URL = "http://127.0.0.1:8000"
API_KEY = "test_key"

def verify_chat_endpoint():
    print("🚀 Starting Lyo Adapter Integration Verification...")
    
    url = f"{API_URL}/api/v1/chat"
    headers = {
        "X-API-Key": API_KEY,
        "Content-Type": "application/json"
    }
    
    # Payload designed to trigger a LyoBlock response
    # "Create a course" triggers the classroom logic in the system prompt
    payload = {
        "message": "Create a course about Black Holes",
        "conversationHistory": [],
        "context": "mode=tutor,topic=science"
    }
    
    print(f"📡 Connecting to {url}...")
    
    try:
        response = requests.post(url, json=payload, headers=headers)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 404:
             print("❌ 404 Not Found. Checking /api/v1/ai/chat fallback...")
             # Try alternate endpoint
             url = f"{API_URL}/api/v1/ai/chat"
             response = requests.post(url, json=payload, headers=headers)
             print(f"Fallback Status Code: {response.status_code}")
        
        if response.status_code != 200:
            print(f"❌ Error Response: {response.text}")
            return False
            
        data = response.json()
        
        # 1. Verify Structure
        print("\n🔍 Checking Response Structure:")
        
        has_lyo_blocks = "lyoBlocks" in data
        has_content_types = "contentTypes" in data
        has_payload = "payload" in data
        
        print(f"   • lyoBlocks found: {'✅' if has_lyo_blocks else '❌'}")
        print(f"   • contentTypes found: {'✅' if has_content_types else '❌'}")
        print(f"   • payload found: {'✅' if has_payload else '❌'}")
        
        # 2. Check Lyo Blocks Content (if any)
        if has_lyo_blocks:
            blocks = data["lyoBlocks"]
            print(f"\n📦 Found {len(blocks)} Lyo Blocks:")
            for b in blocks:
                b_type = b.get("type", "unknown")
                b_role = b.get("role", "unknown")
                b_hint = b.get("presentationHint", "none")
                b_mood = b.get("mood", "neutral")
                print(f"   - [{b_type}] Role: {b_role}, Hint: {b_hint}, Mood: {b_mood}")
                
                # Check for enhancements
                if b_hint == "cinematic" or b_role == "hook":
                    print("     ✨ Cinematic Block Detected!")
                if b_mood != "neutral":
                    print(f"     🎭 Mood Directed: {b_mood}")
                    
            return True
        else:
            print("\n⚠️ No Lyo Blocks returned. This might be because the LLM didn't generate them or the backend feature flag is off.")
            # If no blocks, but valid response, it's a "soft" pass but not a verification of our feature
            return False
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection Refused. Is the backend running on localhost:8000?")
        return False
    except Exception as e:
        print(f"❌ Verification Failed: {str(e)}")
        return False

def verify_streaming_endpoint():
    print(f"\n📡 Testing Streaming Endpoint: {API_URL}/api/v1/chat/stream")
    try:
        payload = {
            "message": "Hello A.I., this is a streaming test.",
            "mode_hint": "chat",
            "session_id": "test_streaming_session",
            "include_ctas": True
        }
        
        headers = {
            "X-API-Key": API_KEY,
            "Content-Type": "application/json",
            "Accept": "text/event-stream"
        }
        
        # Verify streaming connection
        print(f"   Connecting to stream...")
        response = requests.post(f"{API_URL}/api/v1/chat/stream", json=payload, headers=headers, stream=True)
        
        if response.status_code == 200:
            print(f"✅ Connection Successful: {response.status_code}")
            
            # Check content type
            ctype = response.headers.get('Content-Type', '')
            print(f"   Content-Type: {ctype}")
            
            if "text/event-stream" in ctype:
                 print("✅ Valid Event Stream Content-Type")
            else:
                 print(f"⚠️ Warning: Content-Type is {ctype}, expected text/event-stream")
            
            # Consume chunks
            print("   Receiving chunks...")
            chunk_count = 0
            has_delta = False
            
            for line in response.iter_lines():
                if line:
                    decoded = line.decode('utf-8')
                    if decoded.startswith("event: message_delta"):
                        has_delta = True
                    if decoded.startswith("data:"):
                        chunk_count += 1
                        
                    if chunk_count >= 3 and has_delta:
                        print("✅ Received valid SSE message_delta events")
                        break
                        
            return True
        else:
            print(f"❌ Streaming Connection Failed: {response.status_code}")
            print(response.text)
            return False
            
    except Exception as e:
        print(f"❌ Streaming Error: {e}")
        return False

if __name__ == "__main__":
    s1 = verify_chat_endpoint()
    s2 = verify_streaming_endpoint()
    sys.exit(0 if (s1 and s2) else 1)
