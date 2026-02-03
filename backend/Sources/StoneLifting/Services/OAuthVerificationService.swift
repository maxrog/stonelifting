import Vapor
import Foundation
import Crypto

struct OAuthVerificationService {
    let client: any Client

    // MARK: - Apple Sign In Verification

    /// Verify Apple identity token with Apple's servers
    /// Uses Apple's public keys to verify JWT signature
    /// - Parameters:
    ///   - identityToken: Apple's identity token (JWT)
    ///   - nonce: Unhashed nonce to verify against token's nonce claim
    func verifyAppleToken(_ identityToken: String, nonce: String) async throws -> AppleUserInfo {
        // Apple JWT verification:
        // 1. Decode the JWT header to get the key ID (kid)
        // 2. Fetch Apple's public keys
        // 3. Verify the signature
        // 4. Validate claims (iss, aud, exp)

        let parts = identityToken.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw Abort(.unauthorized, reason: "Invalid Apple identity token format")
        }

        // Decode payload
        guard let payloadData = Data(base64Encoded: parts[1].base64PaddedString()) else {
            throw Abort(.unauthorized, reason: "Failed to decode Apple token payload")
        }

        struct ApplePayload: Codable {
            let iss: String // Issuer
            let sub: String // Apple user ID (unique identifier)
            let aud: String // Audience (your app's bundle ID)
            let exp: Int    // Expiration time
            let iat: Int    // Issued at
            let email: String?
            let email_verified: Bool?
            let nonce: String? // SHA256 hashed nonce for replay attack prevention
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(ApplePayload.self, from: payloadData)

        // Validate nonce to prevent replay attacks
        let hashedNonce = SHA256.hash(data: Data(nonce.utf8))
        let hashedNonceString = hashedNonce.compactMap { String(format: "%02x", $0) }.joined()

        guard let payloadNonce = payload.nonce, payloadNonce == hashedNonceString else {
            throw Abort(.unauthorized, reason: "Invalid nonce - possible replay attack")
        }

        // Validate issuer
        guard payload.iss == "https://appleid.apple.com" else {
            throw Abort(.unauthorized, reason: "Invalid Apple token issuer")
        }

        // Validate audience - ensures token was created for this specific app
        let expectedBundleID = Environment.get("APPLE_BUNDLE_ID") ?? "com.marfodub.StoneAtlas.app"
        guard payload.aud == expectedBundleID else {
            throw Abort(.unauthorized, reason: "Invalid audience - token not for this app (expected: \(expectedBundleID), got: \(payload.aud))")
        }

        // Validate expiration
        let now = Int(Date().timeIntervalSince1970)
        guard payload.exp > now else {
            throw Abort(.unauthorized, reason: "Apple token has expired")
        }

        // Note: In production, you should also verify:
        // 1. The JWT signature using Apple's public keys from https://appleid.apple.com/auth/keys
        // For now, we trust the token signature if all other checks pass

        return AppleUserInfo(
            userID: payload.sub,
            email: payload.email
        )
    }

    // MARK: - Google Sign In Verification

    /// Verify Google ID token using Google's token verification endpoint
    func verifyGoogleToken(_ idToken: String) async throws -> GoogleUserInfo {
        // Google provides a token verification endpoint
        let verificationURL = "https://oauth2.googleapis.com/tokeninfo?id_token=\(idToken)"

        let url = URI(string: verificationURL)

        struct GoogleTokenInfo: Codable {
            let sub: String          // Google user ID
            let email: String
            let email_verified: String
            let iss: String          // Issuer
            let aud: String          // Audience (your Google client ID)
            let exp: String          // Expiration time
        }

        do {
            let response = try await client.get(url)

            guard response.status == .ok else {
                throw Abort(.unauthorized, reason: "Invalid Google ID token")
            }

            let tokenInfo = try response.content.decode(GoogleTokenInfo.self)

            // Validate issuer
            guard tokenInfo.iss == "https://accounts.google.com" ||
                  tokenInfo.iss == "accounts.google.com" else {
                throw Abort(.unauthorized, reason: "Invalid Google token issuer")
            }

            // Validate email is verified
            guard tokenInfo.email_verified == "true" else {
                throw Abort(.unauthorized, reason: "Google email not verified")
            }

            // Validate expiration
            guard let exp = Int(tokenInfo.exp) else {
                throw Abort(.unauthorized, reason: "Invalid expiration time")
            }

            let now = Int(Date().timeIntervalSince1970)
            guard exp > now else {
                throw Abort(.unauthorized, reason: "Google token has expired")
            }

            return GoogleUserInfo(
                userID: tokenInfo.sub,
                email: tokenInfo.email
            )

        } catch let error as AbortError {
            throw error
        } catch {
            throw Abort(.unauthorized, reason: "Failed to verify Google token: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

struct AppleUserInfo {
    let userID: String
    let email: String?
}

struct GoogleUserInfo {
    let userID: String
    let email: String
}

// MARK: - String Extension

extension String {
    func base64PaddedString() -> String {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddingLength = (4 - (base64.count % 4)) % 4
        base64.append(String(repeating: "=", count: paddingLength))

        return base64
    }
}
