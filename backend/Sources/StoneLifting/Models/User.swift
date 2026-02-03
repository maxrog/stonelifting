import Fluent
import Vapor

final class User: Model, Content, @unchecked Sendable, Authenticatable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "email")
    var email: String

    @OptionalField(key: "password_hash")
    var passwordHash: String?

    @OptionalField(key: "apple_id")
    var appleId: String?

    @OptionalField(key: "google_id")
    var googleId: String?

    @Field(key: "auth_provider")
    var authProvider: AuthProvider

    @Children(for: \.$user)
    var stones: [Stone]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil,
         username: String,
         email: String,
         passwordHash: String? = nil,
         appleId: String? = nil,
         googleId: String? = nil,
         authProvider: AuthProvider = .apple) {
        self.id = id
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.appleId = appleId
        self.googleId = googleId
        self.authProvider = authProvider
    }
}

// MARK: - Supporting Types

enum AuthProvider: String, Codable {
    case apple
    case google
}
