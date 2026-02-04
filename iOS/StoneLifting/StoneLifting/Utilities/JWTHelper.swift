//
//  JWTHelper.swift
//  StoneAtlas
//
//  Created by Max Rogers on 2/4/26.
//

import Foundation

/// Helper for decoding and validating JWT tokens
struct JWTHelper {

    /// JWT payload matching backend structure
    struct JWTPayload: Codable {
        let userID: String
        let username: String
        let exp: TimeInterval  // Unix timestamp

        var expirationDate: Date {
            Date(timeIntervalSince1970: exp)
        }

        var isExpired: Bool {
            Date() >= expirationDate
        }

        var isExpiringSoon: Bool {
            // Consider expired if within 1 hour of expiration
            let oneHourFromNow = Date().addingTimeInterval(3600)
            return oneHourFromNow >= expirationDate
        }
    }

    /// Decode JWT token and extract payload
    /// - Parameter token: JWT token string
    /// - Returns: Decoded payload or nil if invalid
    static func decode(_ token: String) -> JWTPayload? {
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else {
            return nil
        }

        // JWT payload is the second segment (header.payload.signature)
        let payloadSegment = segments[1]

        // JWT uses base64url encoding, need to convert to standard base64
        var base64 = payloadSegment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let payloadData = Data(base64Encoded: base64) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(JWTPayload.self, from: payloadData)
    }

    /// Check if token is expired
    /// - Parameter token: JWT token string
    /// - Returns: true if expired or invalid
    static func isExpired(_ token: String) -> Bool {
        guard let payload = decode(token) else {
            return true  // Invalid token = consider expired
        }
        return payload.isExpired
    }

    /// Check if token is expiring soon (within 1 hour)
    /// - Parameter token: JWT token string
    /// - Returns: true if expiring within 1 hour
    static func isExpiringSoon(_ token: String) -> Bool {
        guard let payload = decode(token) else {
            return true
        }
        return payload.isExpiringSoon
    }
}
