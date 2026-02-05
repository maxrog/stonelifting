import JWT
import Vapor
import Fluent

struct AuthController {

    // JWT payload structure
    struct UserPayload: JWTPayload {
        let userID: UUID
        let username: String
        let exp: ExpirationClaim

        func verify(using signer: JWTSigner) throws {
            try exp.verifyNotExpired()
        }
    }

    // Generate JWT token for user
    static func generateToken(for user: User, on req: Request) throws -> String {
        let payload = UserPayload(
            userID: try user.requireID(),
            username: user.username,
            exp: ExpirationClaim(value: Date().addingTimeInterval(3600)) // 1 hour
        )

        return try req.jwt.sign(payload)
    }

    // Generate refresh token for user
    static func generateRefreshToken(for user: User, on req: Request) async throws -> String {
        // Revoke any existing refresh tokens for this user
        try await RefreshToken.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .set(\.$isRevoked, to: true)
            .update()

        // Create new refresh token
        let refreshToken = try RefreshToken.generate(for: user)
        try await refreshToken.save(on: req.db)

        return refreshToken.token
    }

    // Refresh access token using refresh token
    static func refreshAccessToken(refreshToken: String, on req: Request) async throws -> LoginResponse {
        // Find the refresh token
        guard let token = try await RefreshToken.query(on: req.db)
            .filter(\.$token == refreshToken)
            .with(\.$user)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid refresh token")
        }

        // Check if token is revoked
        guard !token.isRevoked else {
            throw Abort(.unauthorized, reason: "Refresh token has been revoked")
        }

        // Check if token is expired
        guard token.expiresAt > Date() else {
            throw Abort(.unauthorized, reason: "Refresh token has expired")
        }

        // Generate new access token and refresh token
        let user = token.user
        let newAccessToken = try generateToken(for: user, on: req)
        let newRefreshToken = try await generateRefreshToken(for: user, on: req)

        req.logger.info("Token refreshed for user: \(user.username)")

        return LoginResponse(
            user: UserResponse(user: user),
            token: newAccessToken,
            refreshToken: newRefreshToken
        )
    }

    // JWT authenticator middleware
    struct JWTAuthenticator: AsyncJWTAuthenticator {
        typealias Payload = UserPayload

        func authenticate(jwt: UserPayload, for request: Request) async throws {
            guard let user = try await User.find(jwt.userID, on: request.db) else {
                throw Abort(.unauthorized)
            }
            request.auth.login(user)
        }
    }
}
