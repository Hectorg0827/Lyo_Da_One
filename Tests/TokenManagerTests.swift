import XCTest
@testable import Lyo

/// Tests for JWT token validation and expiry parsing
final class TokenManagerTests: XCTestCase {
    
    // MARK: - JWT Parsing Tests
    
    func testValidJWTWithFutureExpiry() async {
        // Build a JWT with exp = 1 hour from now
        let futureExp = Date().timeIntervalSince1970 + 3600
        let token = makeJWT(exp: futureExp)
        
        let manager = TokenManager.shared
        await manager.setToken(token)
        
        let isValid = await manager.hasValidToken()
        XCTAssertTrue(isValid, "Token with future expiry should be valid")
        
        // Cleanup
        await manager.clearAll()
    }
    
    func testExpiredJWTIsInvalid() async {
        // Build a JWT with exp = 1 hour ago
        let pastExp = Date().timeIntervalSince1970 - 3600
        let token = makeJWT(exp: pastExp)
        
        let manager = TokenManager.shared
        await manager.setToken(token)
        
        let isValid = await manager.hasValidToken()
        XCTAssertFalse(isValid, "Token with past expiry should be invalid")
    }
    
    func testEmptyTokenIsInvalid() async {
        let manager = TokenManager.shared
        await manager.clearAll()
        
        let isValid = await manager.hasValidToken()
        XCTAssertFalse(isValid, "Empty/nil token should be invalid")
    }
    
    func testNonJWTTokenTreatedAsValid() async {
        // A simple string without JWT structure
        let manager = TokenManager.shared
        await manager.setToken("simple-api-key-no-dots")
        
        let isValid = await manager.hasValidToken()
        // Non-JWT tokens (no dots) should be treated as valid since we can't parse expiry
        XCTAssertTrue(isValid, "Non-JWT token should be assumed valid")
        
        await manager.clearAll()
    }
    
    func testJWTWithoutExpClaimTreatedAsValid() async {
        // JWT with no exp field
        let header = base64URLEncode("{\"alg\":\"HS256\",\"typ\":\"JWT\"}")
        let payload = base64URLEncode("{\"sub\":\"1234\",\"name\":\"Test\"}")
        let token = "\(header).\(payload).signature"
        
        let manager = TokenManager.shared
        await manager.setToken(token)
        
        let isValid = await manager.hasValidToken()
        XCTAssertTrue(isValid, "JWT without exp should be assumed valid")
        
        await manager.clearAll()
    }
    
    // MARK: - Helpers
    
    private func makeJWT(exp: TimeInterval) -> String {
        let header = base64URLEncode("{\"alg\":\"HS256\",\"typ\":\"JWT\"}")
        let payload = base64URLEncode("{\"sub\":\"user123\",\"exp\":\(Int(exp))}")
        return "\(header).\(payload).test-signature"
    }
    
    private func base64URLEncode(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
