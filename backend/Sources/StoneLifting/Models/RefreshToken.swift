import Fluent
import Vapor

final class RefreshToken: Model, Content, @unchecked Sendable {
    static let schema = "refresh_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "token")
    var token: String

    @Parent(key: "user_id")
    var user: User

    @Field(key: "expires_at")
    var expiresAt: Date

    @Field(key: "is_revoked")
    var isRevoked: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil,
         token: String,
         userID: User.IDValue,
         expiresAt: Date) {
        self.id = id
        self.token = token
        self.$user.id = userID
        self.expiresAt = expiresAt
        self.isRevoked = false
    }

    // Generate a new refresh token
    static func generate(for user: User) throws -> RefreshToken {
        let token = [UInt8].random(count: 32).base64
        let expiresAt = Date().addingTimeInterval(60 * 60 * 24 * 270) // 9 months
        return try RefreshToken(
            token: token,
            userID: user.requireID(),
            expiresAt: expiresAt
        )
    }
}
