import sys

filepath = '/Users/hectorgarcia/Desktop/LyoBackendJune/lyo_app/chat/routes.py'

with open(filepath, 'r') as f:
    content = f.read()

target = """        # 7. Get recent CTAs for deduplication
        recent_messages = await conversation_store.get_messages(
            db, conversation.id, limit=5
        )"""

replacement = """        # FORCE ROLLBACK to clear any stealth failed transaction states (e.g., from personalization or cache logic)
        try:
            await db.rollback()
        except Exception:
            pass

        # 7. Get recent CTAs for deduplication
        recent_messages = await conversation_store.get_messages(
            db, conversation.id, limit=5
        )"""

if target in content:
    content = content.replace(target, replacement)
    with open(filepath, 'w') as f:
        f.write(content)
    print("Patch applied successfully.")
else:
    print("Target not found.")
