// CreateStone.swift
import Fluent

struct CreateStone: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("stones")
            .id()
            .field("name", .string, .required)
            .field("weight", .double)
            .field("estimated_weight", .double)
            .field("stone_type", .string)
            .field("description", .string)
            .field("image_url", .string)
            .field("latitude", .double)
            .field("longitude", .double)
            .field("location_name", .string)
            .field("is_public", .bool, .required)
            .field("lifting_level", .string, .required)
            .field("carry_distance", .double)
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema("stones").delete()
    }
}
