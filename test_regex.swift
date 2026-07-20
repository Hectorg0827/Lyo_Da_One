import Foundation
let raw = "room? 2. Calculus steps in"
do {
    let numRegex = try NSRegularExpression(pattern: "(?<=[^\\n])\\s+(\\d+\\.)\\s", options: [])
    let result = numRegex.stringByReplacingMatches(in: raw, options: [], range: NSRange(location: 0, length: raw.utf16.count), withTemplate: "\n\n$1 ")
    print("SUCCESS: " + result)
} catch {
    print("ERROR: \(error)")
}
