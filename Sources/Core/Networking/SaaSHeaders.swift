//
//  SaaSHeaders.swift
//  Lyo
//
//  Centralized helper for applying SaaS multi-tenant headers to any URLRequest.
//  This ensures consistent header application across all network calls.
//

import Foundation

/// Centralized helper for applying SaaS multi-tenant headers to any URLRequest
enum SaaSHeaders {
    
    /// Apply all required SaaS headers to a request
    /// - Parameters:
    ///   - request: The URLRequest to modify (inout)
    ///   - includeAuth: Whether to include the Bearer token (default: true)
    static func apply(to request: inout URLRequest, includeAuth: Bool = true) async {
        // 1. API Key (always required for SaaS)
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        
        // 2. Tenant ID (for multi-tenant isolation)
        if let tenantId = await TokenManager.shared.getTenantId() {
            request.setValue(tenantId, forHTTPHeaderField: "X-Tenant-Id")
        }
        
        // 3. Authorization token (if requested and available)
        if includeAuth, let token = await TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 4. Platform identification
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue(AppConfig.version, forHTTPHeaderField: "X-App-Version")
        request.setValue(Bundle.main.bundleIdentifier ?? "com.lyo.app", forHTTPHeaderField: "X-Bundle-Id")
        
        // 5. Client Capabilities (Unbreakable Protocol)
        request.setValue(ClientCapabilities.shared.versionHeader, forHTTPHeaderField: "X-Client-Version")
        request.setValue(ClientCapabilities.shared.componentsHeader, forHTTPHeaderField: "X-Client-Capabilities")
    }
    
    /// Convenience for synchronous contexts (uses cached values)
    /// Use when you already have the token and tenantId from a previous async call
    static func applySync(to request: inout URLRequest, token: String?, tenantId: String?) {
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        
        if let tenantId = tenantId {
            request.setValue(tenantId, forHTTPHeaderField: "X-Tenant-Id")
        }
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue(AppConfig.version, forHTTPHeaderField: "X-App-Version")
        
        // Client Capabilities (Unbreakable Protocol)
        request.setValue(ClientCapabilities.shared.versionHeader, forHTTPHeaderField: "X-Client-Version")
        request.setValue(ClientCapabilities.shared.componentsHeader, forHTTPHeaderField: "X-Client-Capabilities")
    }
    
    /// Apply only API key (for public endpoints that don't need auth)
    static func applyPublic(to request: inout URLRequest) async {
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        
        if let tenantId = await TokenManager.shared.getTenantId() {
            request.setValue(tenantId, forHTTPHeaderField: "X-Tenant-Id")
        }
        
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue(AppConfig.version, forHTTPHeaderField: "X-App-Version")
        
        // Client Capabilities (Unbreakable Protocol)
        request.setValue(ClientCapabilities.shared.versionHeader, forHTTPHeaderField: "X-Client-Version")
        request.setValue(ClientCapabilities.shared.componentsHeader, forHTTPHeaderField: "X-Client-Capabilities")
    }
}
