// CreateStone.swift
import Fluent

struct CreateStone: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("stones")
            .ignoreExisting()
            .id()
            .field("name", .string, .required)
            .field("weight", .double)
            .field("estimated_weight", .double)
            .field("stone_type", .string)
            .field("description", .string)
            .field("image_url", .string)
            .field("latitude", .double)
            .field("longitude", .double)
            .field("is_public", .bool, .required)
            .field("lifting_level", .string, .required)
            .field("report_count", .int, .required, .sql(.default(0)))
            .field("is_hidden", .bool, .required, .sql(.default(false)))
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("stones").delete()
    }
}
