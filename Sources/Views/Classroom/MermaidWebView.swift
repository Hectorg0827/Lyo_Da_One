import SwiftUI
import WebKit

struct PremiumMermaidWebView: UIViewRepresentable {
    let mermaidCode: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let cleanCode = mermaidCode
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script type="module">
                import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
                mermaid.initialize({ 
                    startOnLoad: true, 
                    theme: 'dark',
                    themeVariables: {
                        background: 'transparent',
                        primaryColor: '#8B5CF6',
                        secondaryColor: '#6366F1',
                        tertiaryColor: '#4F46E5',
                        primaryBorderColor: '#A78BFA',
                        primaryTextColor: '#FFFFFF',
                        fontFamily: 'system-ui, -apple-system, sans-serif'
                    }
                });
                
                document.addEventListener('DOMContentLoaded', () => {
                    const mermaidDiv = document.querySelector('.mermaid');
                    mermaidDiv.textContent = `\(cleanCode)`;
                    mermaid.init(undefined, mermaidDiv);
                });
            </script>
            <style>
                body { 
                    margin: 0; 
                    padding: 0;
                    display: flex; 
                    justify-content: center; 
                    align-items: center; 
                    background-color: transparent; 
                    color: white;
                    overflow: hidden;
                }
                .mermaid { 
                    width: 100%; 
                    display: flex;
                    justify-content: center;
                }
                svg {
                    max-width: 100%;
                    height: auto;
                }
            </style>
        </head>
        <body>
            <div class="mermaid"></div>
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
