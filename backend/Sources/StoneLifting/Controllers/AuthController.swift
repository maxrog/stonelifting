import JWT
import Vapor

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
            exp: ExpirationClaim(value: Date().addingTimeInterval(90)) // 90 seconds (TESTING ONLY)
        )
        
        return try req.jwt.sign(payload)
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
