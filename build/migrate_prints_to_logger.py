#!/usr/bin/env python3
"""
Bulk-convert print() statements to Log.* calls in the Lyo codebase.

Strategy:
  1. Map each file to a log category based on its path
  2. Classify each print() as info/warning/error based on emoji prefix
  3. Replace print("...") with Log.<category>.<level>("...")
  4. Strip emoji prefixes (the log level now carries that semantic)
  5. Add `import os` to files that need it (if not already present)

Safe: only modifies print() calls, preserves all other code exactly.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # LYO_Da_ONE

# Map file paths to log categories
CATEGORY_MAP = {
    "Networking/": "net",
    "NetworkClient": "net",
    "NetworkCache": "net",
    "OfflineQueueManager": "net",
    "LyoAPIClient": "net",
    "Endpoint": "net",
    "BackendAIService": "ai",
    "OpenAIService": "ai",
    "LyoAIViewModel": "ai",
    "AICommandHandler": "ai",
    "AICommandResponse": "ai",
    "AIStudyMode": "ai",
    "A2A": "ai",
    "Auth": "auth",
    "Token": "auth",
    "Login": "auth",
    "Signup": "auth",
    "RootViewModel": "auth",
    "CourseGeneration": "course",
    "CourseService": "course",
    "Classroom": "classroom",
    "LiveClassroom": "classroom",
    "LessonBlock": "classroom",
    "Community": "social",
    "Social": "social",
    "Comment": "social",
    "Post": "social",
    "Feed": "social",
    "Challenge": "social",
    "PushNotification": "push",
    "DataService": "data",
    "LyoRepository": "data",
    "UserDefaults": "data",
    "Cache": "data",
    "Audio": "audio",
    "Voice": "audio",
    "TTS": "audio",
    "Speech": "audio",
    "Monetization": "monetization",
    "Subscription": "monetization",
    "StoreKit": "monetization",
    "A2UI": "a2ui",
    "DeepLink": "deeplink",
    "Discovery": "discover",
    "Camera": "media",
    "Photo": "media",
    "Video": "media",
    "LyoApp": "app",
    "AppConfig": "app",
    "AppDelegate": "app",
    "Chat": "ai",
    "UnifiedChat": "ai",
    "Lyo2Chat": "ai",
    "InteractiveCinema": "ai",
    "ProfileView": "ui",
    "MainTabView": "ui",
    "FocusView": "ui",
    "OnboardingView": "ui",
    "SettingsView": "ui",
}

# Emoji → log level mapping
ERROR_EMOJIS = {"❌", "🛑", "💥"}
WARNING_EMOJIS = {"⚠️"}
SUCCESS_EMOJIS = {"✅", "🎉", "🎊"}
DEBUG_EMOJIS = {"🔍", "🧪", "🐛"}


def get_category(filepath: str) -> str:
    """Determine log category from file path/name."""
    for pattern, cat in CATEGORY_MAP.items():
        if pattern in filepath:
            return cat
    # Fallback by directory
    if "/Views/" in filepath:
        return "ui"
    if "/ViewModels/" in filepath:
        return "ui"
    if "/Services/" in filepath:
        return "net"
    if "/Models/" in filepath:
        return "data"
    if "/Core/" in filepath:
        return "app"
    return "general"


def get_log_level(content: str) -> str:
    """Determine log level from the print content."""
    # Check first few chars for emoji
    first_chars = content[:4] if len(content) >= 4 else content
    for emoji in ERROR_EMOJIS:
        if emoji in first_chars:
            return "error"
    for emoji in WARNING_EMOJIS:
        if emoji in first_chars:
            return "warning"
    for emoji in DEBUG_EMOJIS:
        if emoji in first_chars:
            return "debug"
    # Default: if it looks like an error message
    lower = content.lower()
    if "error" in lower or "fail" in lower or "crash" in lower:
        return "error"
    if "warn" in lower:
        return "warning"
    return "info"


def strip_emoji_prefix(content: str) -> str:
    """Remove leading emoji from log message since level carries the semantic."""
    # Common patterns: "❌ Something" or "✅ Something"
    all_emojis = ERROR_EMOJIS | WARNING_EMOJIS | SUCCESS_EMOJIS | DEBUG_EMOJIS | {
        "🚀", "📦", "🎓", "📡", "🔄", "🔑", "🧠", "💬", "🔥", "📱", "🎯",
        "🛡️", "🌐", "📊", "🔗", "⏱️", "🗑️", "📝", "🏠", "👤", "💾", "🎤",
        "🔊", "📢", "🤖", "⚡", "🔧", "💡", "🆘", "📋", "🧩", "🖼️"
    }
    stripped = content
    for emoji in all_emojis:
        if stripped.startswith(emoji):
            stripped = stripped[len(emoji):].lstrip()
            break
    return stripped


def has_string_interpolation(s: str) -> bool:
    """Check if a Swift string literal contains \\(...) interpolation."""
    depth = 0
    i = 0
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s) and s[i + 1] == '(':
            return True
        i += 1
    return False


def process_file(filepath: Path, dry_run: bool = False) -> int:
    """Process a single Swift file. Returns number of replacements made."""
    text = filepath.read_text(encoding="utf-8")
    lines = text.split("\n")
    category = get_category(str(filepath))
    changes = 0
    new_lines = []
    needs_import = False

    for line in lines:
        stripped = line.strip()

        # Skip comments
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            new_lines.append(line)
            continue

        # Match print(...) — handle simple single-line prints
        # Pattern: print("...") or print("...\(...)...")
        match = re.match(r'^(\s*)print\((".*")\)\s*$', line)
        if match:
            indent = match.group(1)
            content_raw = match.group(2)
            # Get the string content without quotes for analysis
            inner = content_raw[1:-1] if content_raw.startswith('"') and content_raw.endswith('"') else content_raw
            level = get_log_level(inner)
            # Strip emoji from the message
            cleaned_inner = strip_emoji_prefix(inner)
            if cleaned_inner != inner:
                # Reconstruct the string
                content_raw = f'"{cleaned_inner}"'
            new_lines.append(f'{indent}Log.{category}.{level}({content_raw})')
            changes += 1
            needs_import = True
            continue

        # Match multi-arg prints or complex prints: print("...", something)
        # Also handle: print("Error: \(error)")
        # For complex multi-line prints, just do simple replacement
        if stripped.startswith("print(") and stripped.endswith(")") and "print(" in stripped:
            # Extract everything between print( and the final )
            inner_start = line.index("print(") + 6
            # Find matching closing paren
            depth = 1
            i = inner_start
            line_chars = line
            while i < len(line_chars) and depth > 0:
                if line_chars[i] == '(':
                    depth += 1
                elif line_chars[i] == ')':
                    depth -= 1
                i += 1
            if depth == 0:
                inner_content = line_chars[inner_start:i-1]
                # Check if it's a simple string (starts with ")
                if inner_content.strip().startswith('"'):
                    first_quote_content = inner_content.strip()
                    level = get_log_level(first_quote_content)
                    # Try to strip emoji
                    if first_quote_content.startswith('"'):
                        inner_text = first_quote_content[1:] if first_quote_content.startswith('"') else first_quote_content
                        # Find closing quote (handling interpolation)
                        cleaned = strip_emoji_prefix(inner_text)
                        if cleaned != inner_text:
                            inner_content = f'"{cleaned}'
                            # Ensure we haven't broken anything by only cleaning if it's simple
                            inner_content = inner_content.rstrip()
                    indent = line[:line.index("print(")]
                    new_lines.append(f'{indent}Log.{category}.{level}({inner_content})')
                    changes += 1
                    needs_import = True
                    continue

        new_lines.append(line)

    if changes > 0 and not dry_run:
        result = "\n".join(new_lines)
        # Add import os if not present
        if needs_import and "import os" not in text and "import OSLog" not in text:
            # Add after the last import statement
            import_lines = []
            last_import_idx = 0
            for i, line in enumerate(new_lines):
                if line.strip().startswith("import "):
                    last_import_idx = i
            new_lines.insert(last_import_idx + 1, "import os")
            result = "\n".join(new_lines)
        filepath.write_text(result, encoding="utf-8")

    return changes


def main():
    dry_run = "--dry-run" in sys.argv
    sources = ROOT / "Sources"
    
    if not sources.exists():
        print(f"❌ Sources directory not found at {sources}")
        sys.exit(1)
    
    swift_files = sorted(sources.rglob("*.swift"))
    total_changes = 0
    files_changed = 0
    
    for f in swift_files:
        changes = process_file(f, dry_run=dry_run)
        if changes > 0:
            rel = f.relative_to(ROOT)
            action = "would change" if dry_run else "changed"
            print(f"  {action} {changes:3d} prints in {rel}")
            total_changes += changes
            files_changed += 1
    
    mode = "DRY RUN — " if dry_run else ""
    print(f"\n{mode}Total: {total_changes} print() → Log.*() across {files_changed} files")


if __name__ == "__main__":
    main()
