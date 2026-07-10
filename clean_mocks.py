import re

files_to_clean = [
    "Sources/Services/LyoAPIClient.swift",
    "Sources/Services/DiscoveryService.swift",
    "Sources/Services/PostService.swift",
    "Sources/Services/LiveClassroomService.swift",
    "Sources/ViewModels/LiveClassroomViewModel.swift",
    "Sources/ViewModels/LyoAIViewModel.swift",
    "Sources/Services/CloudStorageService.swift",
    "Sources/Services/OpenAIService.swift"
]

def remove_mock_blocks(text):
    # Regex to match: if AppConfig.allowMockFallbacks { ... }
    # Also matches: if AppConfig.allowMockFallbacks && ... { ... }
    # And we assume there's no nested '{' inside these blocks since they usually just return mockData()
    pattern = re.compile(r'[ \t]*if AppConfig\.allowMockFallbacks.*?(?:\{[^\{\}]*\})', re.DOTALL)
    
    # Check for ones that have nested {} like mock story creation inline
    pattern_nested = re.compile(r'[ \t]*if AppConfig\.allowMockFallbacks.*?(?:\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\})', re.DOTALL)
    
    res = pattern_nested.sub('', text)
    
    # also remove `guard AppConfig.allowMockFallbacks else { ... }`
    pattern_guard = re.compile(r'[ \t]*guard AppConfig\.allowMockFallbacks else(?:\{[^\{\}]*\})', re.DOTALL)
    res = pattern_guard.sub('', res)
    
    return res

for path in files_to_clean:
    full_path = "/Users/hectorgarcia/LYO_Da_ONE/" + path
    try:
        with open(full_path, "r") as f:
            content = f.read()
        
        new_content = remove_mock_blocks(content)
        
        with open(full_path, "w") as f:
            f.write(new_content)
        print(f"Cleaned {path}")
    except FileNotFoundError:
        print(f"Not found: {path}")

