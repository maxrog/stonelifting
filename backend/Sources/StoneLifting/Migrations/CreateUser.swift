// CreateUser.swift
import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .ignoreExisting()
            .id()
            .field("username", .string, .required)
            .field("email", .string, .required)
            .field("password_hash", .string)
            .field("apple_id", .string)
            .field("google_id", .string)
            .field("auth_provider", .string, .required, .sql(.default("apple")))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "username")
            .unique(on: "email")
            .unique(on: "apple_id")
            .unique(on: "google_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users").delete()
    }
}
