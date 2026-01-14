import requests
import json
import time

# Configuration
API_URL = "https://lyo-backend-production-5oq7jszolq-uc.a.run.app"
API_KEY = "lyo_sk_live_S5ALtW3WDjhF-TAgn767ORCCga4Nx52xBlAkMHg2-TQ"

def verify_a2a_stream():
    print("🚀 Starting A2A Protocol Verification...")
    
    url = f"{API_URL}/api/v2/courses/stream-a2a"
    headers = {
        "X-API-Key": API_KEY,
        "Content-Type": "application/json"
    }
    
    payload = {
        "topic": "The Physics of Black Holes",
        "quality_tier": "standard",
        "enable_visual": True,
        "enable_voice": False,  # Disable voice to speed up test
        "enable_qa": True,
        "user_context": {
            "goals": ["Understand event horizon", "Learn about hawking radiation"],
            "difficulty": "beginner"
        }
    }
    
    print(f"📡 Connecting to {url}...")
    
    try:
        response = requests.post(url, json=payload, headers=headers, stream=True)
        print(f"Status Code: {response.status_code}")
        print(f"Headers: {response.headers}")
        response.raise_for_status()
        
        events_received = []
        phases_started = set()
        phases_completed = set()
        
        print("\n📊 Streaming Events:")
        print("-" * 50)
        
        for line in response.iter_lines():
            if not line:
                continue
                
            line = line.decode('utf-8')
            if line.startswith("data: "):
                data_str = line[6:]
                # Parse event data
                try:
                    data = json.loads(data_str)
                except json.JSONDecodeError:
                    print(f"❌ Failed to decode JSON: {data_str}")
                    continue
                    
                event_type = data.get("type")
                phase = data.get("phase")
                
                print(f"[{phase or 'GLOBAL'}] {event_type}: {data.get('message', '')}")
                
                events_received.append(event_type)
                
                if event_type == "phase_started":
                    phases_started.add(phase)
                elif event_type == "phase_completed":
                    phases_completed.add(phase)
                elif event_type == "pipeline_completed":
                    print("\n✅ Pipeline Completed!")
                    # Verify payload
                    payload = data.get("payload")
                    if not payload:
                        print("❌ Missing payload in pipeline_completed event")
                        return False
                        
                    print(f"📦 Generated Course: {payload.get('course_title')}")
                    print(f"📚 Modules: {len(payload.get('modules', []))}")
                    
                    # Verify strictly required fields
                    required_fields = ["course_id", "course_title", "modules", "metadata"]
                    missing = [f for f in required_fields if f not in payload]
                    if missing:
                        print(f"❌ Missing required fields in course payload: {missing}")
                        return False
                        
                    break
                elif event_type == "error":
                    print(f"❌ Error received: {data.get('message')}")
                    return False
                
        # Protocol Verification Checks
        print("\n🔍 Protocol Verification Results:")
        print("-" * 50)
        
        # 1. Check Phase Order
        expected_phases = ["INITIALIZATION", "PEDAGOGY", "CINEMATIC", "ASSEMBLY", "FINALIZATION"]
        # Note: VISUAL/VOICE/QA might be skipped or parallel, so we check core flow
        
        success = True
        
        if "INITIALIZATION" not in phases_started:
            print("❌ INITIALIZATION phase never started")
            success = False
            
        if "FINALIZATION" not in phases_completed:
            print("❌ FINALIZATION phase never completed")
            success = False
            
        # 2. Check Event Logic
        if "pipeline_started" not in events_received:
            print("❌ Missing pipeline_started event")
            success = False
            
        # 3. Check specific artifact events
        if "artifact_created" not in events_received:
             print("⚠️ Warning: No artifact_created events received")
             
        if success:
            print("✅ Protocol Verified Successfully")
        else:
            print("❌ Protocol Verification Failed")
            
        return success
        
    except Exception as e:
        print(f"❌ Connection Failed: {str(e)}")
        return False

if __name__ == "__main__":
    verify_a2a_stream()
