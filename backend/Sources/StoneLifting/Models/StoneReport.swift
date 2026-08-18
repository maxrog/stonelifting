import Fluent
import Vapor

/// Tracks which user reported which stone, so the same account can't
/// inflate a stone's report count past the auto-hide threshold on its own.
final class StoneReport: Model, @unchecked Sendable {
    static let schema = "stone_reports"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "stone_id")
    var stone: Stone

    @Parent(key: "user_id")
    var user: User

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil, stoneID: Stone.IDValue, userID: User.IDValue) {
        self.id = id
        self.$stone.id = stoneID
        self.$user.id = userID
    }
}
