// CreateStone.swift
import Fluent

struct CreateStone: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("stones")
            .id()
            .field("weight", .double, .required)
            .field("estimated_weight", .double)
            .field("description", .string)
            .field("image_url", .string)
            .field("latitude", .double)
            .field("longitude", .double)
            .field("location_name", .string)
            .field("is_public", .bool, .required)
            .field("difficulty_rating", .int)
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("stones").delete()
    }
}
