import Fluent

struct CreateStoneReport: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("stone_reports")
            .ignoreExisting()
            .id()
            .field("stone_id", .uuid, .required, .references("stones", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "stone_id", "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("stone_reports").delete()
    }
}
